import { execFileSync, spawnSync } from 'node:child_process'
import { existsSync, readdirSync, readFileSync, realpathSync, statSync } from 'node:fs'
import { basename, dirname, extname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { loadModels, modelFor, outputEnergy } from './energy.mjs'
import { loadPrices, ratesFor } from './prices.mjs'
import { loadRepository } from './repository.mjs'

const parseLines = (text) => text.split('\n').filter(Boolean).map((line) => JSON.parse(line))

export const resolveRepository = (target) => {
  let repo = null
  try {
    repo = realpathSync(target)
  } catch {
    repo = null
  }
  if (repo && statSync(repo).isDirectory()) return repo
  console.error(`${target} is not a directory`)
  process.exit(1)
}

export const commonGitDirectory = (repo) =>
  execFileSync('git', ['rev-parse', '--path-format=absolute', '--git-common-dir'], {
    cwd: repo,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
  }).trim()

export const headCommit = (repo) => {
  try {
    return execFileSync('git', ['rev-parse', '--short', 'HEAD'], { cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim()
  } catch {
    return null
  }
}

export const load = (repo) => {
  const adapters = join(dirname(fileURLToPath(import.meta.url)), 'adapters')
  const usage = []
  if (existsSync(adapters)) {
    for (const name of readdirSync(adapters).sort()) {
      const file = join(adapters, name)
      if (!statSync(file).isFile() || !(statSync(file).mode & 0o111)) continue
      const result = spawnSync(file, [repo], { encoding: 'utf8' })
      if (result.status === 0) usage.push(...parseLines(result.stdout))
      else console.error(`${basename(name, extname(name))}: ${(result.stderr || result.error?.message || '').trim()}`)
    }
  }
  let verdicts = []
  try {
    const log = join(commonGitDirectory(repo), 'ai-for-dummies', 'metrics.jsonl')
    if (existsSync(log)) verdicts = parseLines(readFileSync(log, 'utf8')).filter((verdict) => verdict.kind !== 'check' || (verdict.source && existsSync(join(repo, verdict.source))))
  } catch {
    verdicts = []
  }
  return { usage, verdicts }
}

const tokenTypes = ['input', 'output', 'cache_read', 'cache_write']

export const loadAll = async (repo) => {
  const loaded = load(repo)
  let prices = null
  try {
    prices = await loadPrices(join(commonGitDirectory(repo), 'ai-for-dummies', 'prices.json'))
  } catch {
    prices = null
  }
  let models = null
  try {
    models = await loadModels(join(commonGitDirectory(repo), 'ai-for-dummies', 'ecologits.json'))
  } catch {
    models = null
  }
  return { ...loaded, prices, models, repository: loadRepository(repo) }
}

const sum = (values) => values.reduce((total, value) => total + (value ?? 0), 0)
const byName = (a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0)
const ranked = (pairs) => {
  const counts = new Map()
  for (const [name, count] of pairs) counts.set(name, (counts.get(name) ?? 0) + count)
  return [...counts].map(([name, count]) => ({ name, count })).sort((a, b) => b.count - a.count || byName(a, b))
}
const resultCount = (list, result) => list.filter((verdict) => verdict.result === result).length

const costs = (usage, prices) => {
  const perDay = new Map()
  let total = 0
  const unpriced = new Set()
  for (const record of usage) {
    const day = String(record.start).slice(0, 10)
    for (const [id, tokens] of Object.entries(record.models ?? {})) {
      const rates = prices ? ratesFor(prices, id) : null
      const priced = rates && tokenTypes.every((type) => tokens[type] === 0 || typeof rates[type] === 'number')
      if (priced) {
        const cost = tokenTypes.reduce((amount, type) => amount + tokens[type] * (rates[type] ?? 0), 0)
        total += cost
        perDay.set(day, (perDay.get(day) ?? 0) + cost)
      } else if (prices) {
        unpriced.add(id)
      }
    }
  }
  return {
    total: prices ? total : null,
    unpriced: [...unpriced].sort(),
    perDay,
  }
}

const energies = (usage, models) => {
  const perDay = new Map()
  let total = 0
  const unmodelled = new Set()
  for (const record of usage) {
    const day = String(record.start).slice(0, 10)
    for (const [id, tokens] of Object.entries(record.models ?? {})) {
      const model = models ? modelFor(models, id) : null
      if (model) {
        const energy = outputEnergy(model, tokens.output)
        total += energy
        perDay.set(day, (perDay.get(day) ?? 0) + energy)
      } else if (models && tokens.output > 0) {
        unmodelled.add(id)
      }
    }
  }
  return { total: models ? total : null, unmodelled: [...unmodelled].sort(), perDay }
}

export const compact = (value) => {
  if (value < 1e3) return String(Math.round(value))
  if (value < 1e6) return `${(value / 1e3).toFixed(1)}k`
  if (value < 1e9) return `${(value / 1e6).toFixed(1)}M`
  return `${(value / 1e9).toFixed(1)}B`
}
export const formatCost = (amount) => `$${amount.toFixed(1)}`
export const duration = (ms) => (ms < 60000 ? `${(ms / 1000).toFixed(1)} s` : ms < 3600000 ? `${(ms / 60000).toFixed(1)} min` : `${(ms / 3600000).toFixed(1)} h`)
export const formatEnergy = (wh) => (wh < 1000 ? `${wh.toFixed(1)} Wh` : `${(wh / 1000).toFixed(1)} kWh`)

export const summarize = ({ usage, verdicts, prices = null, models = null, repository = { coverage: [], scout: null } }) => {
  const tokens = (key) => sum(usage.map((record) => record.tokens[key] + record.subagent_tokens[key]))
  const checks = verdicts.filter((verdict) => verdict.kind === 'check')
  const tests = verdicts.filter((verdict) => verdict.kind === 'test')
  const days = new Map()
  for (const record of usage) {
    const day = String(record.start).slice(0, 10)
    const entry = days.get(day) ?? { day, prompts: 0, input: 0, output: 0, cache_read: 0, cache_write: 0, active: 0, wall: 0 }
    entry.prompts += 1
    for (const type of tokenTypes) entry[type] += record.tokens[type] + record.subagent_tokens[type]
    entry.active += record.active_ms ?? 0
    entry.wall += record.wall_ms ?? 0
    days.set(day, entry)
  }
  const costing = costs(usage, prices)
  const energy = energies(usage, models)
  for (const entry of days.values()) entry.energy = energy.perDay.get(entry.day) ?? (models ? 0 : null)
  for (const entry of days.values()) entry.cost = costing.perDay.get(entry.day) ?? (prices ? 0 : null)
  return {
    cost: costing.total,
    unpriced: costing.unpriced,
    energy: energy.total,
    unmodelled: energy.unmodelled,
    prompts: usage.length,
    agents: ranked(usage.map((record) => [record.agent, 1])).sort(byName),
    wallMs: sum(usage.map((record) => record.wall_ms)),
    activeMs: sum(usage.map((record) => record.active_ms)),
    tokens: {
      input: tokens('input'),
      output: tokens('output'),
      cacheRead: tokens('cache_read'),
      cacheWrite: tokens('cache_write'),
    },
    subagents: sum(usage.map((record) => record.subagents)),
    tools: ranked(usage.flatMap((record) => Object.entries(record.tools))),
    mcpServers: ranked(usage.flatMap((record) => Object.entries(record.mcp_servers))),
    commands: ranked(usage.flatMap((record) => record.commands.map((name) => [name, 1]))),
    days: [...days.values()].sort((a, b) => (a.day < b.day ? -1 : 1)),
    checks: [...new Set(checks.map((check) => check.name))].sort().map((name) => {
      const own = checks.filter((check) => check.name === name)
      const fails = own.filter((check) => check.result === 'fail').map((check) => String(check.time).slice(0, 10)).sort()
      const sources = [...new Set(own.map((check) => check.source).filter(Boolean))].sort()
      const runs = own.slice(-10).map((check) => ({ day: String(check.time).slice(0, 10), result: check.result }))
      return { name, sources, runs, pass: resultCount(own, 'pass'), fail: resultCount(own, 'fail'), lastFail: fails.at(-1) ?? null }
    }),
    tests: tests.length
      ? {
          pass: resultCount(tests, 'pass'),
          fail: resultCount(tests, 'fail'),
          skip: resultCount(tests, 'skip'),
        }
      : null,
    durations: Object.fromEntries(verdicts.filter((verdict) => verdict.kind === 'duration').map((verdict) => [verdict.name, Number(verdict.result) * 1000])),
    coverage: repository.coverage,
    scout: repository.scout,
    failing: ranked(tests.filter((test) => test.result === 'fail').map((test) => [test.name, 1])),
  }
}
