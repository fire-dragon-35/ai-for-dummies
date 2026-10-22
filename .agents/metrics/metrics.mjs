import { brief } from './brief.mjs'
import { mark } from './terminal.mjs'
import { duration, formatCost, formatEnergy, loadAll, resolveRepository, summarize } from './summary.mjs'

const args = process.argv.slice(2)
const repo = resolveRepository(args.find((arg) => !arg.startsWith('--')) ?? '.')
const summary = summarize(await loadAll(repo))

if (args.includes('--brief')) {
  console.log(brief(summary))
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
for (const check of summary.checks) lines.push(row(check.name, `${mark(check.latest.result === 'pass')} ${check.latest.detail}`.trim()))
if (summary.tests) {
  const { latest } = summary.tests
  lines.push(
    row('tests', `${mark(latest.fail === 0)} ${latest.pass} pass, ${latest.fail} fail, ${latest.skip} skip`),
    ...(latest.failing.length ? [row('failing', latest.failing.slice(0, 5).join(', '))] : []),
  )
}
const { coverage, backlog } = summary
if (lines.length && coverage.length) lines.push(row('coverage', coverage.map(({ component, requirements }) => `${component} ${requirements.filter((requirement) => requirement.tested).length}/${requirements.length}`).join(', ')))
if (lines.length && backlog) lines.push(row('backlog', `${backlog} ${backlog === 1 ? 'item' : 'items'}`))
console.log(lines.length ? lines.join('\n') : 'no metrics yet')
