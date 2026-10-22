import { execFileSync } from 'node:child_process'
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { compact, duration, loadAll, summarize } from '../../metrics/summary.mjs'

const [dir, task, ...names] = process.argv.slice(2)
const setupFiles = /^(\.agents\/(hooks|metrics|skills|repository-context)\/|\.claude\/|node_modules\/)|(^|\/)(reviewed|package-lock\.json)$/
const testFiles = /(^|\/)(test|tests|__tests__)\/|\.(test|spec)\./

const written = (repo) =>
  execFileSync('git', ['ls-files', '-z', '--others', '--exclude-standard'], { cwd: repo, encoding: 'utf8' })
    .split('\0')
    .filter((file) => file && !setupFiles.test(file))
const lineCount = (repo, files) => files.reduce((total, file) => total + (readFileSync(join(repo, file), 'utf8').match(/\n/g) ?? []).length, 0)
const codeFiles = (repo) => written(repo).filter((file) => /\.(c|m)?js$/.test(file) && !file.startsWith('.agents/') && !testFiles.test(file))
const lastJson = (text) => {
  const start = text.indexOf('{')
  const end = text.lastIndexOf('}')
  try {
    return start < 0 ? null : JSON.parse(text.slice(start, end + 1))
  } catch {
    return null
  }
}
const read = (file) => (existsSync(file) ? readFileSync(file, 'utf8') : '')

const acceptance = (name) => {
  const result = lastJson(read(join(dir, `${name}.acceptance`)).trim().split('\n').at(-1) ?? '')
  return result?.total ? result : { passed: 0, total: 1, failed: ['no result'] }
}

const reviewKey = new Map(read(join(dir, 'review', 'key')).split('\n').filter(Boolean).map((line) => line.split(' ').reverse()))
const review = (name) => {
  const answer = lastJson(read(join(dir, 'review', `${reviewKey.get(name)}.json`)))
  const scores = lastJson(String(answer?.result ?? '')) ?? {}
  return Object.entries(scores).filter(([, entry]) => typeof entry?.score === 'number')
}

const problems = (output) => JSON.parse(output).reduce((total, file) => total + file.errorCount + file.warningCount, 0)
const lint = (repo, files) => {
  try {
    return problems(execFileSync('npx', ['--yes', 'eslint@10.13.0', '--no-config-lookup', '-c', join(task, 'eslint.config.mjs'), '--format', 'json', ...files], { cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 1 << 26 }))
  } catch (error) {
    return problems(error.stdout)
  }
}
const duplication = (repo, files) => {
  const output = mkdtempSync(join(tmpdir(), 'jscpd-'))
  execFileSync('npx', ['--yes', 'jscpd@4.3.0', '--silent', '--reporters', 'json', '--output', output, ...files], { cwd: repo, stdio: 'ignore' })
  return lastJson(read(join(output, 'jscpd-report.json')))?.statistics.total.percentage ?? 0
}

const money = (value) => `$${value.toFixed(2)}`
const percent = (value) => `${value.toFixed(1)}%`
const decimal = (value) => value.toFixed(1)
const count = (value) => (Number.isInteger(value) ? String(value) : value.toFixed(1))
const figures = [
  { label: 'cost', format: money, value: (run) => run.summary.cost },
  { label: 'wall', format: duration, value: (run) => run.summary.wallMs },
  { label: 'output', format: compact, value: (run) => run.summary.tokens.output },
  { label: 'cache read', format: compact, value: (run) => run.summary.tokens.cacheRead },
  { label: 'cache write', format: compact, value: (run) => run.summary.tokens.cacheWrite },
  { label: 'subagents', format: count, value: (run) => run.summary.subagents },
  { label: 'lines', format: count, value: (run) => lineCount(run.repo, written(run.repo)) },
  ...(existsSync(join(task, 'acceptance.mjs')) ? [{ label: 'acceptance', format: percent, value: (run) => (run.acceptance.passed / run.acceptance.total) * 100 }] : []),
  ...(existsSync(join(task, 'review.md')) ? [{ label: 'review', format: decimal, value: (run) => (run.review.length ? run.review.reduce((sum, [, entry]) => sum + entry.score, 0) / run.review.length : null) }] : []),
  ...(existsSync(join(task, 'eslint.config.mjs'))
    ? [
        { label: 'lint/kloc', format: decimal, value: (run) => (run.code.length ? (lint(run.repo, run.code) / Math.max(1, lineCount(run.repo, run.code))) * 1000 : 0) },
        { label: 'duplication', format: percent, value: (run) => (run.code.length ? duplication(run.repo, run.code) : 0) },
      ]
    : []),
]

const runs = []
for (const name of names) {
  const repo = join(dir, name)
  const run = { name, repo, side: name.replace(/-\d+$/, ''), summary: summarize(await loadAll(repo)), code: codeFiles(repo), acceptance: acceptance(name), review: review(name) }
  runs.push({ ...run, values: figures.map((figure) => figure.value(run)) })
}

if (existsSync(join(task, 'acceptance.mjs'))) writeFileSync(join(dir, 'acceptance.md'), runs.map((run) => `## ${run.name}\n${run.acceptance.failed.map((name) => `- ${name}`).join('\n')}\n`).join('\n'))
if (existsSync(join(task, 'review.md'))) writeFileSync(join(dir, 'review.md'), runs.map((run) => `## ${run.name}\n${run.review.map(([criterion, entry]) => `- ${criterion} ${entry.score}: ${entry.note ?? ''}`).join('\n')}\n`).join('\n'))

const shown = (figure, value) => (value === null ? '-' : figure.format(value))
const spread = (figure, values) => {
  if (values.includes(null)) return '-'
  const average = values.reduce((sum, value) => sum + value, 0) / values.length
  return `${figure.format(average)} (${figure.format(Math.min(...values))}–${figure.format(Math.max(...values))})`
}
const rows = [
  ['run', ...figures.map((figure) => figure.label)],
  ...runs.map((run) => [run.name, ...figures.map((figure, index) => shown(figure, run.values[index]))]),
  ...[...new Set(runs.map((run) => run.side))].map((side) => {
    const own = runs.filter((run) => run.side === side)
    return [side, ...figures.map((figure, index) => spread(figure, own.map((run) => run.values[index])))]
  }),
]
const widths = rows[0].map((_, column) => Math.max(...rows.map((row) => row[column].length)) + 2)
for (const row of rows) console.log(row.map((cell, column) => (column === row.length - 1 ? cell : cell.padEnd(widths[column]))).join(''))
