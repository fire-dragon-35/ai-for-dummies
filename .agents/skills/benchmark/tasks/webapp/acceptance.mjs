import { execFileSync, spawn } from 'node:child_process'
import { mkdtempSync } from 'node:fs'
import { createServer } from 'node:net'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const repo = process.argv[2]
const dataFile = join(mkdtempSync(join(tmpdir(), 'acceptance-')), 'data.json')
const results = []
const xss = `<img src=x onerror="document.body.setAttribute('data-xss','1')">`

const freePort = () =>
  new Promise((resolve) => {
    const server = createServer().listen(0, () => {
      const { port } = server.address()
      server.close(() => resolve(port))
    })
  })

const port = await freePort()
const base = `http://127.0.0.1:${port}`

const start = async () => {
  const app = spawn('npm', ['start'], { cwd: repo, detached: true, stdio: 'ignore', env: { ...process.env, PORT: String(port), DATA_FILE: dataFile } })
  for (let attempt = 0; attempt < 60; attempt++) {
    try {
      await fetch(base)
      return app
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 500))
    }
  }
  return app
}
const stop = (app) => {
  try {
    process.kill(-app.pid)
  } catch {
    return
  }
}

const call = async (method, path, body, raw) => {
  const response = await fetch(base + path, {
    method,
    headers: body === undefined && raw === undefined ? {} : { 'content-type': 'application/json' },
    body: raw ?? (body === undefined ? undefined : JSON.stringify(body)),
  })
  const text = await response.text()
  let json = null
  try {
    json = JSON.parse(text)
  } catch {
    json = null
  }
  return { status: response.status, json, text, type: response.headers.get('content-type') ?? '' }
}

const check = async (name, test) => {
  let passed = false
  try {
    passed = (await test()) === true
  } catch {
    passed = false
  }
  results.push({ name, passed })
}

const isError = (answer, status) => answer.status === status && typeof answer.json?.error === 'string'
const listCount = async () => (await call('GET', '/api/lists')).json.length
const itemsOf = async (listId) => (await call('GET', `/api/lists/${listId}/items`)).json
const newList = async (name) => (await call('POST', '/api/lists', { name })).json
const newItem = async (listId, body) => (await call('POST', `/api/lists/${listId}/items`, body)).json

const browser = ['google-chrome', 'chromium', 'chromium-browser'].find((command) => {
  try {
    execFileSync('which', [command], { stdio: 'ignore' })
    return true
  } catch {
    return false
  }
})
const renderedPage = () =>
  execFileSync(browser, ['--headless=new', '--disable-gpu', '--no-sandbox', `--user-data-dir=${mkdtempSync(join(tmpdir(), 'chrome-'))}`, '--virtual-time-budget=5000', '--dump-dom', base + '/'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 60000, env: { ...process.env, TMPDIR: '/tmp' } })

try {
  execFileSync('npm', ['install', '--no-audit', '--no-fund'], { cwd: repo, stdio: 'ignore', timeout: 300000 })
} catch {
  results.push({ name: 'npm install', passed: false })
}
let app = await start()

await check('lists start empty', async () => {
  const answer = await call('GET', '/api/lists')
  return answer.status === 200 && Array.isArray(answer.json) && answer.json.length === 0
})
let groceries = null
await check('creates a list', async () => {
  const answer = await call('POST', '/api/lists', { name: 'Groceries' })
  groceries = answer.json
  return answer.status === 201 && answer.json?.name === 'Groceries' && answer.json.id !== undefined
})
await check('lists the created list', async () => (await call('GET', '/api/lists')).json.some((list) => list.id === groceries.id && list.name === 'Groceries'))
let milk = null
await check('adds an item', async () => {
  const answer = await call('POST', `/api/lists/${groceries.id}/items`, { name: 'Milk', quantity: 2 })
  milk = answer.json
  return answer.status === 201 && milk?.name === 'Milk' && milk.quantity === 2 && milk.done === false && milk.id !== undefined
})
await check('lists the added item', async () => (await itemsOf(groceries.id)).some((item) => item.id === milk.id && item.name === 'Milk' && item.quantity === 2 && item.done === false))
await check('quantity defaults to 1', async () => (await newItem(groceries.id, { name: 'Bread' }))?.quantity === 1)
await check('checks an item off and keeps its other fields', async () => {
  const answer = await call('PATCH', `/api/items/${milk.id}`, { done: true })
  return answer.status === 200 && answer.json?.done === true && answer.json.name === 'Milk' && answer.json.quantity === 2
})
await check('edits name and quantity of an item', async () => {
  const answer = await call('PATCH', `/api/items/${milk.id}`, { name: 'Oat milk', quantity: 3 })
  const stored = (await itemsOf(groceries.id)).find((item) => item.id === milk.id)
  return answer.status === 200 && stored?.name === 'Oat milk' && stored.quantity === 3 && stored.done === true
})

for (const [name, body] of [
  ['rejects an empty list name', { name: '' }],
  ['rejects a blank list name', { name: '   ' }],
  ['rejects a list without a name', {}],
  ['rejects a list name that is not text', { name: 42 }],
]) {
  await check(name, async () => {
    const before = await listCount()
    return isError(await call('POST', '/api/lists', body), 400) && (await listCount()) === before
  })
}
await check('rejects malformed JSON', async () => isError(await call('POST', '/api/lists', undefined, '{"name": '), 400))
for (const [name, body] of [
  ['rejects quantity 0', { name: 'Eggs', quantity: 0 }],
  ['rejects a negative quantity', { name: 'Eggs', quantity: -1 }],
  ['rejects a fractional quantity', { name: 'Eggs', quantity: 1.5 }],
  ['rejects a quantity given as text', { name: 'Eggs', quantity: '3' }],
  ['rejects a blank item name', { name: ' ', quantity: 1 }],
]) {
  await check(name, async () => {
    const before = (await itemsOf(groceries.id)).length
    return isError(await call('POST', `/api/lists/${groceries.id}/items`, body), 400) && (await itemsOf(groceries.id)).length === before
  })
}
for (const [name, body] of [
  ['rejects an edit to quantity 0', { quantity: 0 }],
  ['rejects an edit to an empty name', { name: '' }],
  ['rejects an edit of done that is not true or false', { done: 'yes' }],
]) {
  await check(name, async () => {
    const answer = await call('PATCH', `/api/items/${milk.id}`, body)
    const stored = (await itemsOf(groceries.id)).find((item) => item.id === milk.id)
    return isError(answer, 400) && stored?.name === 'Oat milk' && stored.quantity === 3 && stored.done === true
  })
}

for (const [name, method, path, body] of [
  ['answers 404 for items of an unknown list', 'GET', '/api/lists/unknown-id/items'],
  ['answers 404 for adding to an unknown list', 'POST', '/api/lists/unknown-id/items', { name: 'Tea' }],
  ['answers 404 for editing an unknown item', 'PATCH', '/api/items/unknown-id', { done: true }],
  ['answers 404 for deleting an unknown item', 'DELETE', '/api/items/unknown-id'],
  ['answers 404 for deleting an unknown list', 'DELETE', '/api/lists/unknown-id'],
]) {
  await check(name, async () => isError(await call(method, path, body), 404))
}

await check('stores 20 items added at the same time', async () => {
  const party = await newList('Party')
  await Promise.all(Array.from({ length: 20 }, (_, index) => call('POST', `/api/lists/${party.id}/items`, { name: `Guest ${index}` })))
  return (await itemsOf(party.id)).length === 20
})
await check('deletes an item', async () => {
  const bread = (await itemsOf(groceries.id)).find((item) => item.name === 'Bread')
  const answer = await call('DELETE', `/api/items/${bread.id}`)
  return answer.status === 204 && !(await itemsOf(groceries.id)).some((item) => item.id === bread.id)
})
await check('deleting a list deletes its items', async () => {
  const trip = await newList('Trip')
  const tent = await newItem(trip.id, { name: 'Tent' })
  const answer = await call('DELETE', `/api/lists/${trip.id}`)
  return answer.status === 204 && !(await call('GET', '/api/lists')).json.some((list) => list.id === trip.id) && (await call('PATCH', `/api/items/${tent.id}`, { done: true })).status === 404
})
await check('keeps answering after invalid input', async () => (await call('GET', '/api/lists')).status === 200)

stop(app)
app = await start()
await check('keeps lists and items after a restart', async () => (await call('GET', '/api/lists')).json.some((list) => list.id === groceries.id) && (await itemsOf(groceries.id)).some((item) => item.name === 'Oat milk'))

await check('serves the page at /', async () => {
  const answer = await call('GET', '/')
  return answer.status === 200 && answer.type.includes('text/html')
})
await newList(xss)
let page = ''
await check('a browser renders the page', async () => {
  page = renderedPage()
  return page.includes('</body>')
})
await check('the page shows the lists', async () => page.includes('Groceries') && page.includes('Party'))
await check('the page shows a list name with markup as text without running it', async () => !page.includes('data-xss="1"') && page.includes('&lt;img src=x onerror'))
stop(app)

const failed = results.filter((result) => !result.passed).map((result) => result.name)
console.log(JSON.stringify({ passed: results.length - failed.length, total: results.length, failed }))
