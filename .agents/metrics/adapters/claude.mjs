#!/usr/bin/env node
import { existsSync, readdirSync, readFileSync, realpathSync, statSync } from 'node:fs'
import { homedir } from 'node:os'
import { basename, join } from 'node:path'

const target = process.argv[2] ?? '.'
let repo
try {
  repo = realpathSync(target)
  if (!statSync(repo).isDirectory()) throw new Error()
} catch {
  console.error(`${target} is not a directory`)
  process.exit(1)
}
const projects = join(process.env.CLAUDE_CONFIG_DIR ?? join(homedir(), '.claude'), 'projects')
if (!existsSync(projects)) process.exit(0)

const zero = () => ({ input: 0, output: 0, cache_read: 0, cache_write: 0 })

const entriesOf = (file) =>
  readFileSync(file, 'utf8')
    .split('\n')
    .map((line) => {
      try {
        return JSON.parse(line)
      } catch {
        return null
      }
    })
    .filter((entry) => entry !== null && typeof entry === 'object' && !Array.isArray(entry))

const distinctMessages = (entries) => {
  const first = new Map()
  for (const entry of entries) {
    const id = entry.message?.id
    if (entry.type === 'assistant' && id != null && !first.has(id)) first.set(id, entry.message)
  }
  return [...first.values()]
}

const addUsage = (total, usage) => ({
  input: total.input + (usage.input_tokens ?? 0),
  output: total.output + (usage.output_tokens ?? 0),
  cache_read: total.cache_read + (usage.cache_read_input_tokens ?? 0),
  cache_write: total.cache_write + (usage.cache_creation_input_tokens ?? 0),
})

const tokensOf = (entries) => distinctMessages(entries).reduce((total, message) => addUsage(total, message.usage ?? {}), zero())

const modelsOf = (entries) => {
  const models = {}
  for (const message of distinctMessages(entries)) {
    const id = message.model ?? 'unknown'
    models[id] = addUsage(models[id] ?? zero(), message.usage ?? {})
  }
  return models
}

const sumTokens = (list) => {
  const total = zero()
  for (const tokens of list) for (const key of Object.keys(total)) total[key] += tokens[key]
  return total
}

const mergeModels = (list) => {
  const merged = {}
  for (const models of list) {
    for (const [id, tokens] of Object.entries(models)) merged[id] = sumTokens([merged[id] ?? zero(), tokens])
  }
  const listed = {}
  for (const id of Object.keys(merged).sort()) {
    if (Object.values(merged[id]).some((count) => count > 0)) listed[id] = merged[id]
  }
  return listed
}

const counted = (names) => {
  const counts = {}
  for (const name of [...names].sort()) counts[name] = (counts[name] ?? 0) + 1
  return counts
}

const isHuman = (entry) =>
  entry.type === 'user' &&
  typeof entry.message?.content === 'string' &&
  (entry.origin?.kind === 'human' || (entry.entrypoint === 'sdk-cli' && !entry.origin && !entry.isMeta))

const toolCalls = (span) => {
  const calls = new Map()
  for (const entry of span) {
    if (entry.type !== 'assistant' || !Array.isArray(entry.message?.content)) continue
    for (const block of entry.message.content) {
      if (block && block.type === 'tool_use' && block.name && block.id && !calls.has(block.id)) {
        calls.set(block.id, block.name)
      }
    }
  }
  return calls
}

const sessionFiles = (folder) =>
  readdirSync(folder)
    .filter((name) => name.endsWith('.jsonl') && statSync(join(folder, name)).isFile())
    .sort()

const folderCwd = (folder) => {
  for (const name of sessionFiles(folder)) {
    const found = entriesOf(join(folder, name)).find((entry) => entry.cwd)
    if (found) return found.cwd
  }
  return undefined
}

const subagentSummaries = (session) => {
  const directory = join(session.slice(0, -'.jsonl'.length), 'subagents')
  if (!existsSync(directory)) return []
  const summaries = []
  for (const name of readdirSync(directory).sort()) {
    if (!name.startsWith('agent-') || !name.endsWith('.jsonl')) continue
    const file = join(directory, name)
    const meta = file.slice(0, -'.jsonl'.length) + '.meta.json'
    if (!existsSync(meta)) continue
    try {
      const entries = entriesOf(file)
      summaries.push({ tool: JSON.parse(readFileSync(meta, 'utf8')).toolUseId, tokens: tokensOf(entries), models: modelsOf(entries) })
    } catch {
      continue
    }
  }
  return summaries
}

const recordsOf = (session) => {
  const entries = entriesOf(session)
  const subagents = subagentSummaries(session)
  const starts = entries.flatMap((entry, index) => (isHuman(entry) ? [index] : []))
  return starts.map((start, k) => {
    const span = entries.slice(start, starts[k + 1] ?? entries.length)
    const prompt = span[0]
    const calls = toolCalls(span)
    const lastReply = span.filter((entry) => entry.type === 'assistant').at(-1)
    const durations = span.filter((entry) => entry.type === 'system' && entry.subtype === 'turn_duration')
    const mine = subagents.filter((subagent) => calls.has(subagent.tool))
    const names = [...calls.values()]
    return {
      agent: 'claude',
      session: basename(session, '.jsonl'),
      prompt: prompt.promptId ?? null,
      start: prompt.timestamp ?? null,
      wall_ms: lastReply ? Date.parse(lastReply.timestamp) - Date.parse(prompt.timestamp) : null,
      active_ms: durations.length ? durations.reduce((sum, entry) => sum + entry.durationMs, 0) : null,
      tokens: tokensOf(span),
      subagent_tokens: sumTokens(mine.map((subagent) => subagent.tokens)),
      subagents: mine.length,
      tools: counted(names),
      mcp_servers: counted(names.filter((name) => name.startsWith('mcp__')).map((name) => name.split('__')[1])),
      commands: [...prompt.message.content.matchAll(/<command-name>([^<]*)<\/command-name>/g)].map((match) => match[1]),
      models: mergeModels([modelsOf(span), ...mine.map((subagent) => subagent.models)]),
    }
  })
}

const inRepository = (cwd) => cwd === repo || (cwd !== undefined && cwd.startsWith(repo + '/'))

const records = []
for (const name of readdirSync(projects).sort()) {
  const folder = join(projects, name)
  if (!statSync(folder).isDirectory() || !inRepository(folderCwd(folder))) continue
  for (const file of sessionFiles(folder)) records.push(...recordsOf(join(folder, file)))
}
records.sort((a, b) => (a.start < b.start ? -1 : a.start > b.start ? 1 : 0))
for (const record of records) console.log(JSON.stringify(record))
