import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const read = (file) => (existsSync(file) ? readFileSync(file, 'utf8') : null)

const coverage = (repo) => {
  const tests = join(repo, '.agents', 'tests')
  if (!existsSync(tests)) return []
  return readdirSync(tests, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && existsSync(join(tests, entry.name, 'requirements.md')))
    .map((entry) => {
      const directory = join(tests, entry.name)
      const requirements = [...read(join(directory, 'requirements.md')).matchAll(/^- R(\d+):/gm)].map((match) => Number(match[1])).sort((a, b) => a - b)
      const names = readdirSync(directory)
        .filter((name) => name.endsWith('.bats'))
        .flatMap((name) => [...read(join(directory, name)).matchAll(/^@test "R(\d+):/gm)].map((match) => Number(match[1])))
      return { component: entry.name, requirements: requirements.map((number) => ({ number, tested: names.includes(number) })), tests: names.length }
    })
    .sort((a, b) => (a.component < b.component ? -1 : 1))
}

const scout = (repo) => {
  const text = read(join(repo, '.agents', 'scout.md'))
  if (text === null) return null
  const sections = []
  for (const line of text.split('\n')) {
    if (line.startsWith('## ')) sections.push({ name: line.slice(3).trim(), checked: null, items: [] })
    else if (sections.length && line.startsWith('last checked:')) sections.at(-1).checked = line.slice('last checked:'.length).trim()
    else if (sections.length && line.startsWith('- ')) {
      const [head, verdict = '', reason = '', link = ''] = line.slice(2).split(' | ').map((part) => part.trim())
      const [date, ...name] = head.split(' ')
      sections.at(-1).items.push({ date, name: name.join(' '), verdict, reason, link })
    }
  }
  return sections
}

export const loadRepository = (repo) => ({ coverage: coverage(repo), scout: scout(repo) })
