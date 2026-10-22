import { createServer } from 'node:http'
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { randomUUID } from 'node:crypto'

const file = process.env.DATA_FILE
const strict = !process.env.BROKEN
const data = existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : { lists: [], items: [] }
const save = () => writeFileSync(file, JSON.stringify(data))
const page = readFileSync(new URL('./index.html', import.meta.url), 'utf8')

const send = (response, status, body) => {
  response.writeHead(status, { 'content-type': 'application/json' })
  response.end(body === undefined ? '' : JSON.stringify(body))
}
const fail = (response, status, error) => send(response, status, { error })
const validName = (name) => !strict || (typeof name === 'string' && name.trim() !== '')
const validQuantity = (quantity) => !strict || (Number.isInteger(quantity) && quantity > 0)
const validDone = (done) => !strict || typeof done === 'boolean'

const readBody = async (request) => {
  let text = ''
  for await (const chunk of request) text += chunk
  return JSON.parse(text || 'null')
}

const routes = [
  ['GET', /^\/api\/lists$/, (response) => send(response, 200, data.lists)],
  ['POST', /^\/api\/lists$/, (response, body) => {
    if (!validName(body?.name)) return fail(response, 400, 'name required')
    const list = { id: randomUUID(), name: body.name }
    data.lists.push(list)
    save()
    send(response, 201, list)
  }],
  ['DELETE', /^\/api\/lists\/([^/]+)$/, (response, body, id) => {
    if (!data.lists.some((list) => list.id === id)) return fail(response, 404, 'no such list')
    data.lists = data.lists.filter((list) => list.id !== id)
    data.items = data.items.filter((item) => item.listId !== id)
    save()
    send(response, 204)
  }],
  ['GET', /^\/api\/lists\/([^/]+)\/items$/, (response, body, id) => {
    if (!data.lists.some((list) => list.id === id)) return fail(response, 404, 'no such list')
    send(response, 200, data.items.filter((item) => item.listId === id).map(({ listId, ...item }) => item))
  }],
  ['POST', /^\/api\/lists\/([^/]+)\/items$/, (response, body, id) => {
    if (!data.lists.some((list) => list.id === id)) return fail(response, 404, 'no such list')
    const quantity = body?.quantity ?? 1
    if (!validName(body?.name) || !validQuantity(quantity)) return fail(response, 400, 'invalid item')
    const item = { id: randomUUID(), listId: id, name: body.name, quantity, done: false }
    data.items.push(item)
    save()
    const { listId, ...shown } = item
    send(response, 201, shown)
  }],
  ['PATCH', /^\/api\/items\/([^/]+)$/, (response, body, id) => {
    const item = data.items.find((entry) => entry.id === id)
    if (!item) return fail(response, 404, 'no such item')
    if (!body || ('name' in body && !validName(body.name)) || ('quantity' in body && !validQuantity(body.quantity)) || ('done' in body && !validDone(body.done))) return fail(response, 400, 'invalid item')
    for (const key of ['name', 'quantity', 'done']) if (key in body) item[key] = body[key]
    save()
    const { listId, ...shown } = item
    send(response, 200, shown)
  }],
  ['DELETE', /^\/api\/items\/([^/]+)$/, (response, body, id) => {
    if (!data.items.some((item) => item.id === id)) return fail(response, 404, 'no such item')
    data.items = data.items.filter((item) => item.id !== id)
    save()
    send(response, 204)
  }],
]

createServer(async (request, response) => {
  if (request.method === 'GET' && request.url === '/') {
    response.writeHead(200, { 'content-type': 'text/html' })
    return response.end(page)
  }
  const route = routes.find(([method, path]) => method === request.method && path.test(request.url))
  if (!route) return fail(response, 404, 'not found')
  let body = null
  try {
    body = await readBody(request)
  } catch {
    return fail(response, 400, 'invalid JSON')
  }
  route[2](response, body, request.url.match(route[1])[1])
}).listen(process.env.PORT)
