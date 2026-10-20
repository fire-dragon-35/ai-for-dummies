import { readFileSync } from 'node:fs'

const [expression, file] = process.argv.slice(2)
const evaluate = new Function('x', `return (${expression})`)
for (const line of readFileSync(file ?? 0, 'utf8').split('\n')) {
  if (!line) continue
  const value = evaluate(JSON.parse(line))
  if (value === undefined) continue
  console.log(typeof value === 'string' ? value : JSON.stringify(value))
}
