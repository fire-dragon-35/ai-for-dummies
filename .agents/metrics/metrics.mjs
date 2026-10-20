import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { render } from './dashboard.mjs'
import { commonGitDirectory, duration, formatCost, formatEnergy, headCommit, loadAll, resolveRepository, summarize } from './summary.mjs'

const args = process.argv.slice(2)
const html = args.indexOf('--html')
const file = html >= 0 && args[html + 1] && !args[html + 1].startsWith('--') ? args[html + 1] : null
const target = args.find((arg, index) => arg !== '--html' && !(file && index === html + 1)) ?? '.'
const repo = resolveRepository(target)
const summary = summarize(await loadAll(repo))

if (html >= 0) {
  const output = resolve(file ?? join(commonGitDirectory(repo), 'ai-for-dummies', 'dashboard.html'))
  mkdirSync(dirname(output), { recursive: true })
  writeFileSync(output, render(summary, { path: repo, commit: headCommit(repo), generated: new Date() }))
  console.log(output)
  process.exit(0)
}

const row = (label, value) => `${label.padEnd(15)} ${value}`
const top = (label, items) =>
  items.length ? [row(label, items.slice(0, 5).map(({ name, count }) => `${name} ${count}`).join(', '))] : []

const lines = []
if (summary.prompts) {
  const { tokens } = summary
  lines.push(
    row('prompts', `${summary.prompts} (${summary.agents.map(({ name, count }) => `${name} ${count}`).join(', ')})`),
    row('wall', duration(summary.wallMs)),
    row('active', duration(summary.activeMs)),
    row('tokens', `input ${tokens.input}, output ${tokens.output}, cache read ${tokens.cacheRead}, cache write ${tokens.cacheWrite}`),
    row('subagents', String(summary.subagents)),
    row('cost', summary.cost === null ? 'unavailable (no price data)' : `${formatCost(summary.cost)} (API list price)`),
    ...(summary.unpriced.length ? [row('unpriced', summary.unpriced.join(', '))] : []),
    row('energy', summary.energy === null ? 'unavailable (no model data)' : `about ${formatEnergy(summary.energy)} (minimum estimate)`),
    ...(summary.unmodelled.length ? [row('unmodelled', summary.unmodelled.join(', '))] : []),
    ...top('tools', summary.tools),
    ...top('mcp servers', summary.mcpServers),
    ...top('commands', summary.commands),
  )
}
for (const check of summary.checks) lines.push(row(check.name, `${check.pass} pass, ${check.fail} fail`))
if (summary.tests) {
  lines.push(
    row('tests', `${summary.tests.pass} pass, ${summary.tests.fail} fail, ${summary.tests.skip} skip`),
    ...top('failing', summary.failing),
  )
}
console.log(lines.length ? lines.join('\n') : 'no metrics yet')
