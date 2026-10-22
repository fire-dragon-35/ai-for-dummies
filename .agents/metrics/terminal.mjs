const colors = { dim: 2, red: 31, green: 32, yellow: 33, blue: 34, magenta: 35, cyan: 36 }
const levels = '▁▂▃▄▅▆▇█'

const colored = () => !process.env.NO_COLOR && (process.stdout.isTTY || Boolean(process.env.FORCE_COLOR))

export const paint = (text, color) => (colored() ? `\x1b[${colors[color]}m${text}\x1b[0m` : text)

export const mark = (ok) => paint(ok ? '✓' : '✗', ok ? 'green' : 'red')

export const sparkline = (values) => {
  const top = Math.max(...values)
  return values.map((value) => levels[value <= 0 ? 0 : Math.max(1, Math.ceil((value / top) * 7))]).join('')
}

export const bar = (parts, width) => {
  const total = parts.reduce((sum, part) => sum + part.value, 0)
  if (!total) return ''
  const cells = parts.map((part) => (part.value ? Math.max(1, Math.round((width * part.value) / total)) : 0))
  cells[cells.indexOf(Math.max(...cells))] += width - cells.reduce((sum, count) => sum + count, 0)
  return parts.map((part, index) => (cells[index] ? paint(part.glyph.repeat(cells[index]), part.color) : '')).join('')
}
