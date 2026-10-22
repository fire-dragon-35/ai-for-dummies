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
      const numbers = (file, pattern) => [...(read(file) ?? '').matchAll(pattern)].map((match) => Number(match[1]))
      const listed = (read(join(directory, 'tests')) ?? '').split('\n').filter((line) => line.trim())
      const names = [
        ...readdirSync(directory).filter((name) => name.endsWith('.bats')).flatMap((name) => numbers(join(directory, name), /^@test "R(\d+):/gm)),
        ...listed.flatMap((line) => numbers(join(repo, line.trim()), /["'`]R(\d+):/g)),
      ]
      return { component: entry.name, requirements: requirements.map((number) => ({ number, tested: names.includes(number) })) }
    })
    .sort((a, b) => (a.component < b.component ? -1 : 1))
}

const backlog = (repo) => (read(join(repo, '.agents', 'backlog.md')) ?? '').split('\n').filter((line) => line.trim()).length

export const loadRepository = (repo) => ({ coverage: coverage(repo), backlog: backlog(repo) })
