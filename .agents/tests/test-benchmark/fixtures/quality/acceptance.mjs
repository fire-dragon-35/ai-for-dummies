import { existsSync } from 'node:fs'
import { join } from 'node:path'

const repo = process.argv[2]
const passed = existsSync(join(repo, 'AGENTS.md')) ? 3 : 1
console.log('starting')
console.log(JSON.stringify({ passed, total: 4, failed: passed === 3 ? ['edge case'] : ['missing title', 'no persistence', 'edge case'] }))
