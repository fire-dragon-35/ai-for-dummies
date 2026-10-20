import { readFileSync } from 'node:fs'
import { chartCss, timeSection, usageCharts, usageColumns } from './chart.mjs'
import { esc } from './html.mjs'
import { duration } from './summary.mjs'
import { toggleScript } from './toggles.mjs'

const tokens = readFileSync(new URL('./tokens.css', import.meta.url), 'utf8')

const css = `
* { box-sizing: border-box; }
body { margin: 0; background: var(--paper); color: var(--text); font-family: var(--font); line-height: 1.55; }
main { max-width: 1040px; margin: 0 auto; padding: 24px 16px 48px; }
main > h2:first-child { margin-top: 0; }
.nav { position: sticky; top: 0; z-index: 10; background: var(--surface); border-bottom: 1px solid var(--line); }
.nav-inner { max-width: 1040px; margin: 0 auto; padding: 12px 16px; display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 8px 24px; }
.brand { font-size: 1.25rem; font-weight: 800; color: var(--ink); }
.nav-meta { display: flex; flex-wrap: wrap; align-items: center; gap: 8px 16px; color: var(--muted); font-size: .875rem; }
.nav-meta code { padding: 2px 10px; border-radius: var(--radius-pill); background: var(--surface-soft); color: var(--ink); font-weight: 700; font-family: var(--mono); }
h2 { margin: 44px 0 14px; font-size: 1.375rem; font-weight: 800; line-height: 1.2; color: var(--ink); }
.muted { color: var(--muted); font-size: .875rem; }
.last-run { margin: -6px 0 10px; }
.card { background: var(--surface); border-radius: var(--radius-card); padding: 20px; box-shadow: var(--shadow); }
.panel { background: var(--surface); border-radius: var(--radius-card); padding: 8px 20px; box-shadow: var(--shadow); overflow-x: auto; }
table { width: 100%; border-collapse: collapse; font-size: .875rem; font-variant-numeric: tabular-nums; }
th, td { padding: 6px 12px 6px 0; text-align: left; border-bottom: 1px solid var(--line); }
tr:last-child td { border-bottom: 0; }
td:first-child { white-space: nowrap; }
th { color: var(--muted); font-size: .875rem; font-weight: 700; }
td.meter-cell { width: 40%; min-width: 96px; }
.meter { height: 12px; border-radius: var(--radius-pill); background: var(--surface-soft); }
.meter span { display: block; height: 100%; border-radius: var(--radius-pill); background: var(--data-1); transition: width 600ms ease-out; }
.boxes { display: flex; flex-wrap: wrap; gap: 4px; }
.box { position: relative; display: inline-grid; place-items: center; width: 18px; height: 18px; border-radius: 5px; transition: transform 150ms ease-out; }
.box:hover { transform: scale(1.2); }
.box svg { width: 12px; height: 12px; fill: none; stroke: var(--surface); stroke-width: 2.2; stroke-linecap: round; stroke-linejoin: round; }
.box.tested, .box.pass { background: var(--success); }
.box.fail { background: var(--danger); }
.box.untested { border: 1.5px dashed var(--muted); }
h3 { margin: 16px 0 8px; font-size: .9375rem; font-weight: 700; color: var(--ink); }
h3:first-child { margin-top: 0; }
.scout { margin: 0; padding-left: 18px; }
.scout li { margin: 4px 0; }
.scout a { color: var(--ink); font-weight: 700; }
a:focus-visible, summary:focus-visible, button:focus-visible { outline: 2px solid var(--ink); outline-offset: 2px; }
.verdict { padding: 0 8px; border-radius: var(--radius-pill); background: var(--surface-soft); color: var(--ink); font-size: .75rem; font-weight: 700; }
footer { max-width: 1040px; margin: 0 auto; padding: 16px 16px 32px; border-top: 1px solid var(--line); color: var(--muted); font-size: .875rem; text-align: center; }
footer a { color: var(--ink); font-weight: 700; }
.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 24px; }
.no { color: var(--danger); font-weight: 800; }
@media (prefers-reduced-motion: reduce) {
  * { transition: none !important; animation: none !important; }
  .box:hover { transform: none; }
}
`

const percent = (value, max) => (max > 0 ? (value / max) * 100 : 0)
const meter = (value, max) => `<div class="meter"><span style="width:${percent(value, max).toFixed(2)}%"></span></div>`

const table = (head, rows, name = '') =>
  `<div class="panel"><table${name ? ` data-table="${name}"` : ''}><tr>${head.map((title) => `<th>${esc(title)}</th>`).join('')}</tr>${rows
    .map((cells) => `<tr>${cells.join('')}</tr>`)
    .join('')}</table></div>`

const ranking = (title, items) => {
  const shown = items.slice(0, 10)
  const max = Math.max(...shown.map((item) => item.count))
  return shown.length
    ? `<div><h2>${esc(title)}</h2>${table([], shown.map((item) => [`<td>${esc(item.name)}</td>`, `<td>${esc(item.count)}</td>`, `<td class="meter-cell">${meter(item.count, max)}</td>`]))}</div>`
    : ''
}

const icons = {
  check: '<svg viewBox="0 0 12 12" aria-hidden="true"><path d="M2.5 6.5l2.3 2.3 4.7-5"/></svg>',
  cross: '<svg viewBox="0 0 12 12" aria-hidden="true"><path d="M3.5 3.5l5 5M8.5 3.5l-5 5"/></svg>',
}
const runIcons = { pass: icons.check, fail: icons.cross }
const box = (tip, label, icon = '') => `<span class="box ${label}" role="img" aria-label="${label}" data-tip="${esc(tip)}">${icon}</span>`
const lastRun = (ms) => (ms === undefined ? '' : `<p class="muted last-run">last run ${esc(duration(ms))}</p>`)
const boxes = (items) => `<td><div class="boxes">${items.join('')}</div></td>`

const checks = (summary) =>
  summary.checks.length
    ? `<h2>checks</h2>${lastRun(summary.durations.checks)}${table(
        ['check', 'source', 'last 10 runs', 'last fail'],
        summary.checks.map((check) => [
          `<td>${esc(check.name)}</td>`,
          `<td>${check.sources.map(esc).join(', ')}</td>`,
          boxes(check.runs.map((run) => box(`${run.day} ${run.result}`, run.result, runIcons[run.result]))),
          `<td>${esc(check.lastFail ?? '-')}</td>`,
        ]),
        'checks',
      )}`
    : ''

const coverage = (summary) =>
  summary.coverage.length
    ? `<h2>test coverage</h2>${lastRun(summary.durations.tests)}${table(
        ['component', 'requirements', 'tests'],
        summary.coverage.map((row) => [
          `<td>${esc(row.component)}</td>`,
          boxes(row.requirements.map((requirement) => (requirement.tested ? box(`R${requirement.number}`, 'tested', icons.check) : box(`R${requirement.number}`, 'untested')))),
          `<td>${row.tests}</td>`,
        ]),
        'coverage',
      )}`
    : ''

const failing = (summary) => {
  const shown = summary.failing.slice(0, 10)
  const max = Math.max(...shown.map((item) => item.count))
  return shown.length ? `<h2>most failing tests</h2>${table([], shown.map((item) => [`<td>${esc(item.name)}</td>`, `<td><span class="no">✗</span> ${item.count}</td>`, `<td class="meter-cell">${meter(item.count, max)}</td>`]))}` : ''
}

const scout = (summary) =>
  summary.scout
    ? `<h2>scout</h2><section class="card" data-section="scout">${summary.scout
        .map(
          (section) => `<h3>${esc(section.name)} <span class="muted">last checked ${esc(section.checked ?? '-')}</span></h3>${
            section.items.length
              ? `<ul class="scout">${section.items.map((item) => `<li><span class="muted">${esc(item.date)}</span> <a href="${esc(item.link)}" target="_blank" rel="noopener">${esc(item.name)}</a> <span class="verdict">${esc(item.verdict)}</span> ${esc(item.reason)}</li>`).join('')}</ul>`
              : '<p class="muted">nothing new</p>'
          }`,
        )
        .join('')}</section>`
    : ''

const sections = (summary) =>
  [
    summary.days.length ? timeSection('usage', usageCharts(summary), usageColumns(summary), summary.days) : '',
    coverage(summary),
    checks(summary),
    failing(summary),
    scout(summary),
    [summary.tools, summary.mcpServers, summary.commands].some((items) => items.length)
      ? `<div class="grid">${ranking('tools', summary.tools)}${ranking('MCP servers', summary.mcpServers)}${ranking('commands', summary.commands)}</div>`
      : '',
  ].filter(Boolean)

export const render = (summary, { path, commit, generated }) => {
  const parts = sections(summary)
  const body = parts.length ? parts.join('\n') : '<p class="muted">no metrics yet</p>'
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AI for dummies</title>
<style>${tokens}${css}${chartCss}</style>
</head>
<body>
<header class="nav">
<div class="nav-inner">
<span class="brand">AI for dummies 😵‍💫</span>
<span class="nav-meta">
<span class="path">${esc(path)}</span>
<span>${commit ? `commit <code>${esc(commit)}</code>` : 'no commits yet'}</span>
<span>generated ${esc(generated.toISOString().slice(0, 16).replace('T', ' '))} UTC</span>
</span>
</div>
</header>
<main>
${body}
</main>
<footer>AI for dummies 😵‍💫 · <a href="https://github.com/fire-dragon-35/ai-for-dummies" target="_blank" rel="noopener">github.com/fire-dragon-35/ai-for-dummies</a></footer>
<script>${toggleScript}</script>
</body>
</html>
`
}
