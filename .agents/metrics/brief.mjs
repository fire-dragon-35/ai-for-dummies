import { bar, mark, paint, sparkline } from './terminal.mjs'
import { compact, duration, formatCost, formatEnergy, windowOf } from './summary.mjs'

const limit = 100
const width = 10
const indent = ' '.repeat(width)

const shorten = (text, room) => ([...text].length > room ? `${[...text].slice(0, room - 1).join('')}…` : text)
const row = (label, value) => `${paint(label.padEnd(width), 'dim')}${value}`
const note = (text, color) => `${indent}${paint(shorten(text, limit - indent.length), color)}`

const dot = () => paint(' · ', 'dim')

const trend = (label, days, value, total) => row(label, `${paint(sparkline(days.map(value)), 'cyan')}  ${total}`)

const share = (value, total) => {
  const percent = total ? (value / total) * 100 : 0
  return percent === 0 ? '0%' : percent < 1 ? '<1%' : `${percent.toFixed(1)}%`
}

const usage = (summary) => {
  const days = windowOf(summary.days)
  const { input, output, cacheRead, cacheWrite } = summary.tokens
  const total = input + output + cacheRead + cacheWrite
  const shares = [
    ['in', input, 'blue'],
    ['out', output, 'magenta'],
    ['cache read', cacheRead, 'cyan'],
    ['cache write', cacheWrite, 'yellow'],
  ].map(([name, value, color]) => paint(`${name} ${share(value, total)}`, color))
  const lines = [
    row('usage', `${summary.prompts} prompts${dot()}${duration(summary.activeMs)} active${dot()}since ${summary.days[0].day}`),
    trend('tokens', days, (day) => (day.input ?? 0) + (day.output ?? 0) + (day.cache_read ?? 0) + (day.cache_write ?? 0), `${compact(total)}  ${shares.join(dot())}`),
  ]
  if (summary.cost !== null) lines.push(trend('cost', days, (day) => day.cost ?? 0, formatCost(summary.cost)))
  if (summary.energy !== null) lines.push(trend('energy', days, (day) => day.energy ?? 0, formatEnergy(summary.energy)))
  return lines
}

const took = (summary, name) => (name in summary.durations ? `${dot()}${duration(summary.durations[name])}` : '')

export const brief = (summary) => {
  const lines = []
  if (summary.prompts) lines.push(...usage(summary))
  if (summary.checks.length) {
    lines.push(row('checks', `${summary.checks.map((check) => `${mark(check.latest.result === 'pass')} ${check.name}`).join('  ')}${took(summary, 'checks')}`))
    for (const check of summary.checks.filter((entry) => entry.latest.result !== 'pass')) lines.push(note(`${check.name}: ${check.latest.detail}`, 'red'))
  }
  if (summary.tests) {
    const { pass, fail, skip, failing } = summary.tests.latest
    const parts = [
      { value: pass, glyph: '█', color: 'green' },
      { value: fail, glyph: '▓', color: 'red' },
      { value: skip, glyph: '░', color: 'yellow' },
    ]
    const counts = [`${pass} pass`, ...(fail ? [paint(`${fail} fail`, 'red')] : []), ...(skip ? [paint(`${skip} skip`, 'yellow')] : [])]
    lines.push(row('tests', `${bar(parts, 20)} ${counts.join('  ')}${took(summary, 'tests')}`))
    for (const name of failing.slice(0, 3)) lines.push(note(`✗ ${name}`, 'red'))
    if (failing.length > 3) lines.push(note(`and ${failing.length - 3} more`, 'dim'))
  }
  if (lines.length && summary.backlog) lines.push(row('backlog', `${summary.backlog} ${summary.backlog === 1 ? 'item' : 'items'}`))
  return lines.length ? lines.join('\n') : 'no metrics yet'
}
