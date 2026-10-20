import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const week = 7 * 24 * 60 * 60 * 1000
const hour = 60 * 60 * 1000

const fetchText = async (url) => {
  if (url.startsWith('file://')) return readFileSync(fileURLToPath(url), 'utf8')
  const response = await fetch(url, { signal: AbortSignal.timeout(8000), headers: { 'user-agent': 'ai-for-dummies' } })
  if (!response.ok) throw new Error(`${url} answered ${response.status}`)
  return response.text()
}

const save = (file, data) => {
  try {
    mkdirSync(dirname(file), { recursive: true })
    writeFileSync(file, JSON.stringify(data))
    return true
  } catch {
    return false
  }
}

export const loadCached = async (file, url, parse) => {
  let cache = null
  try {
    cache = JSON.parse(readFileSync(file, 'utf8'))
  } catch {
    cache = null
  }
  const now = Date.now()
  const age = (stamp) => now - Date.parse(stamp)
  if (cache?.data && age(cache.fetched_at) < week) return cache.data
  if (age(cache?.attempted_at) < hour) return cache?.data ?? null
  const stamp = new Date(now).toISOString()
  try {
    cache = { fetched_at: stamp, data: parse(await fetchText(url)) }
  } catch {
    cache = { ...cache, attempted_at: stamp }
  }
  save(file, cache)
  return cache.data ?? null
}
