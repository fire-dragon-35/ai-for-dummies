import { esc } from './html.mjs'
import { modelsUrl } from './energy.mjs'
import { priceUrl } from './prices.mjs'
import { compact, duration, formatCost, formatEnergy } from './summary.mjs'

const dayMs = 24 * 60 * 60 * 1000
const minuteMs = 60 * 1000
const hourMs = 60 * minuteMs
const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const shift = (day, days) => new Date(Date.parse(`${day}T00:00:00Z`) + days * dayMs).toISOString().slice(0, 10)

const windowOf = (days) => {
  const last = days.at(-1).day
  const first = days[0].day > shift(last, -29) ? days[0].day : shift(last, -29)
  const known = new Map(days.map((entry) => [entry.day, entry]))
  const window = []
  for (let day = first; day <= last; day = shift(day, 1)) window.push(known.get(day) ?? { day })
  return window
}

const dropDown = (title, anchor, items) => (text) =>
  `<details class="note" style="--anchor:--${anchor}"><summary aria-label="${title}">${esc(text)}</summary><ul>${items.map((item) => `\n<li>${item}</li>`).join('')}\n</ul></details>`

const costNote = dropDown('how is cost estimated', 'cost', [
  '<b>Tokens:</b> input, output, cache read and cache write per model, subagents included.',
  `<b>Rates:</b> per-token price of each token type and model, from <a href="${priceUrl}" target="_blank" rel="noopener">LiteLLM's price table</a>, Anthropic models only.`,
  '<b>Cost:</b> tokens × rate, summed per UTC day.',
])

const energyNote = dropDown('how is energy estimated', 'energy', [
  '<b>Tokens:</b> only output tokens count, input and cache tokens add none.',
  "<b>Per model:</b> GPU energy from the model's active parameters, plus server energy from the generation time (time to first token + output tokens ÷ tokens per second) and the GPUs the model needs, times the data centre PUE.",
  `<b>Source:</b> the <a href="${modelsUrl}" target="_blank" rel="noopener">EcoLogits</a> method and model data. Anthropic does not publish the parameters of its models, so EcoLogits estimates them as a min and max.`,
  '<b>Minimum estimate:</b> the minimum parameters and PUE are used. It is an estimate, not a measurement.',
])

const field = (name) => (day) => day[name] ?? 0
const series = (key, label, color, value = field(key)) => ({ key, label, color, value })

export const usageColumns = (summary) => [
  { label: 'prompts', value: field('prompts'), format: compact },
  { label: 'input tokens', value: field('input'), format: compact },
  { label: 'output tokens', value: field('output'), format: compact },
  { label: 'cache read tokens', value: field('cache_read'), format: compact },
  { label: 'cache write tokens', value: field('cache_write'), format: compact },
  { label: 'estimated true cost', value: field('cost'), format: formatCost, missing: summary.cost === null, note: costNote },
  { label: 'estimated energy', value: field('energy'), format: formatEnergy, missing: summary.energy === null, note: energyNote },
  { label: 'active time', value: field('active'), format: duration },
  { label: 'wall time', value: field('wall'), format: duration },
]

export const usageCharts = (summary) => [
  {
    name: 'tokens',
    title: 'tokens',
    format: compact,
    series: [
      series('cache_read', 'cache read tokens', 'c1'),
      series('output', 'output tokens', 'c2'),
      series('input_write', 'input + cache write tokens', 'c3', (day) => (day.input ?? 0) + (day.cache_write ?? 0)),
    ],
  },
  { name: 'cost', title: summary.cost === null ? 'estimated true cost unavailable' : 'estimated true cost', format: formatCost, unit: 0.1, missing: summary.cost === null, series: [series('cost', 'estimated true cost', 'c1')] },
  { name: 'time', title: 'time', format: duration, time: true, series: [series('active', 'active time', 'c1'), series('wall', 'wall time', 'c2')] },
  { name: 'prompts', title: 'prompts', format: compact, series: [series('prompts', 'prompts', 'c1')] },
]

const niceStep = (target, unit) => {
  const scaled = target / unit
  if (scaled <= 1) return unit
  const power = 10 ** Math.floor(Math.log10(scaled))
  return [1, 2, 5, 10].find((step) => step * power >= scaled) * power * unit
}

const ticksFor = (peak, unit) => {
  const step = niceStep(peak / 4, unit)
  return Array.from({ length: Math.max(1, Math.ceil(peak / step)) + 1 }, (_, index) => index * step)
}

const subsets = (items) => items.reduce((all, item) => all.concat(all.map((subset) => [...subset, item])), [[]]).slice(1).reverse()

const dayLabel = (day, index) => (index === 0 || day.endsWith('-01') ? `${months[Number(day.slice(5, 7)) - 1]} ${Number(day.slice(8))}` : String(Number(day.slice(8))))

const figure = (chart, window) => {
  const axes = subsets(chart.series).map((items) => {
    const peak = Math.max(...window.map((day) => Math.max(...items.map((item) => item.value(day)))))
    const unit = chart.time ? (peak >= hourMs ? hourMs : minuteMs) : (chart.unit ?? 1)
    return { shown: items.map((item) => item.key).join(','), ticks: ticksFor(peak, unit) }
  })
  const top = axes[0].ticks.at(-1)
  const axis = ({ shown, ticks }, index) => {
    const attributes = `data-shown="${shown}" data-top="${ticks.at(-1)}"${index ? ' hidden' : ''}`
    const at = (tick) => `top:${(100 - (tick / ticks.at(-1)) * 100).toFixed(2)}%`
    return {
      labels: `<div class="y" ${attributes}>${ticks.map((tick) => `<span style="${at(tick)}">${esc(chart.format(tick))}</span>`).join('')}</div>`,
      lines: `<div class="lines" ${attributes}>${ticks.map((tick) => `<i style="${at(tick)}"></i>`).join('')}</div>`,
    }
  }
  const bar = (item, day) => {
    const value = item.value(day)
    return `<div class="slot"><div class="bar ${item.color}" data-series="${item.key}" data-day="${esc(day.day)}" data-value="${value}" style="height:${((value / top) * 100).toFixed(2)}%" data-tip="${esc(`${day.day} ${item.label}: ${chart.format(value)}`)}"></div></div>`
  }
  const columns = chart.missing ? [] : window.map((day) => `<div class="col"><div class="group">${chart.series.map((item) => bar(item, day)).join('')}</div></div>`)
  const keys = chart.series.length > 1 ? chart.series.map((item) => `<button type="button" class="key" aria-pressed="true" data-series="${item.key}"><i class="sw ${item.color}"></i>${esc(item.label)}</button>`).join('') : ''
  const label = `${chart.title} per day from ${window[0].day} to ${window.at(-1).day}`
  const parts = axes.map(axis)
  return `<figure class="chart" data-figure="${chart.name}" role="img" aria-label="${esc(label)}">
<figcaption>${esc(chart.title)}</figcaption><div class="legend">${keys}</div>
<div class="area">${parts.map((part) => part.labels).join('')}<div class="plot">${parts.map((part) => part.lines).join('')}${columns.join('')}</div></div>
<div class="x">${window.map((day, index) => `<span>${dayLabel(day.day, index)}</span>`).join('')}</div>
</figure>`
}

const heading = ({ label, note }) => {
  const [first, ...rest] = label.split(' ')
  return note ? `${note(first)} ${esc(rest.join(' '))}` : esc(label)
}

const table = (key, columns, window) => {
  const cell = (column, value) => `<td>${column.missing ? '-' : esc(column.format(value))}</td>`
  const rows = window.map((day) => `<tr><td>${esc(day.day)}</td>${columns.map((column) => cell(column, column.value(day))).join('')}</tr>`)
  const total = `<tr><td>total</td>${columns.map((column) => cell(column, window.reduce((sum, day) => sum + column.value(day), 0))).join('')}</tr>`
  return `<div class="panel"><table class="days" data-table="${key}"><tr><th>day</th>${columns.map((column) => `<th>${heading(column)}</th>`).join('')}</tr>${rows.join('')}${total}</table></div>`
}

export const timeSection = (key, charts, columns, days) => {
  const window = windowOf(days)
  return `<h2>${esc(key)}</h2>
<section class="card timeline" data-chart="${key}">
${charts.map((chart) => figure(chart, window)).join('\n')}
</section>
${table(key, columns, window)}`
}

export const chartCss = `
.timeline { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 28px 32px; }
.timeline + .panel { margin-top: 12px; }
.chart { display: grid; grid-row: span 4; grid-template-rows: subgrid; row-gap: 0; margin: 0; min-width: 0; }
.chart figcaption { color: var(--ink); font-size: .9375rem; font-weight: 700; }
.legend { display: flex; flex-wrap: wrap; gap: 4px 14px; margin-top: 2px; }
.key { display: inline-flex; align-items: center; gap: 6px; padding: 0; border: 0; background: none; color: var(--muted); font: inherit; font-size: .75rem; font-weight: 700; cursor: pointer; }
.key[aria-pressed="false"] { opacity: .45; text-decoration: line-through; }
.note { display: inline-block; }
.note summary { anchor-name: var(--anchor); cursor: pointer; list-style: none; text-decoration: underline dotted var(--accent) 2px; text-underline-offset: 3px; }
.note summary::-webkit-details-marker { display: none; }
.note ul { position: fixed; position-anchor: var(--anchor); z-index: 6; width: min(460px, 80vw); margin: 6px 0 0; padding: 10px 12px 10px 28px; top: anchor(bottom); left: anchor(left); position-try-fallbacks: flip-inline; list-style: disc; border: 1px solid var(--line); border-radius: 12px; background: var(--surface); box-shadow: var(--shadow); color: var(--text); font-size: .75rem; font-weight: 400; text-align: left; }
.note a { color: var(--ink); font-weight: 700; }
.sw { display: inline-block; width: 10px; height: 10px; border-radius: 3px; }
.area { display: grid; grid-template-columns: 52px 1fr; height: 160px; margin-top: 10px; }
.y { position: relative; }
.y span { position: absolute; right: 8px; transform: translateY(-50%); color: var(--muted); font-size: .7rem; font-weight: 700; white-space: nowrap; font-variant-numeric: tabular-nums; }
.plot { position: relative; display: flex; align-items: flex-end; gap: 4px; }
.lines { position: absolute; inset: 0; }
.lines i { position: absolute; left: 0; right: 0; border-top: 1px solid var(--line); }
.col { flex: 1 1 0; min-width: 0; height: 100%; }
.group { display: flex; align-items: flex-end; justify-content: center; gap: 2px; height: 100%; }
.slot { position: relative; display: flex; align-items: flex-end; flex: 1 1 0; max-width: 16px; min-width: 0; height: 100%; }
.bar { width: 100%; border-radius: 4px 4px 0 0; }
.slot:hover .bar { filter: brightness(.9); }
.slot:hover .bar::after, .box:hover::after { content: attr(data-tip); position: absolute; bottom: 100%; left: 50%; transform: translateX(-50%); z-index: 5; padding: 2px 8px; border-radius: 6px; background: var(--ink); color: var(--surface); font-size: .75rem; font-weight: 700; white-space: nowrap; pointer-events: none; }
.bar[style^="height:0.00"] { border: 0; }
.c1 { background: var(--data-1); }
.c2 { background: var(--data-2); }
.c3 { background: var(--data-3); }
[hidden] { display: none !important; }
.x { display: flex; gap: 4px; margin: 4px 0 0 52px; }
.x span { flex: 1 1 0; min-width: 0; text-align: center; color: var(--muted); font-size: .65rem; white-space: nowrap; font-variant-numeric: tabular-nums; }
.days td { white-space: nowrap; }
.days th { vertical-align: bottom; }
.days tr:last-child td { font-weight: 800; color: var(--ink); border-top: 2px solid var(--line); }
`
