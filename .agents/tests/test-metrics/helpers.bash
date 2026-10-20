setup_metrics_repo() {
  source_root="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  repo="$BATS_TEST_TMPDIR/my repo"
  mkdir -p "$repo/.agents/metrics/adapters"
  cp "$source_root/.agents/metrics/"*.mjs "$source_root/.agents/metrics/tokens.css" "$source_root/.agents/metrics/log.sh" "$repo/.agents/metrics/"
  export AI_FOR_DUMMIES_PRICES_URL="file://$BATS_TEST_TMPDIR/no-prices.json"
  export AI_FOR_DUMMIES_MODELS_URL="file://$BATS_TEST_TMPDIR/no-models.json"
  cd "$repo" || return 1
  git init -q
  log="$repo/.git/ai-for-dummies/metrics.jsonl"
  cache="$repo/.git/ai-for-dummies/prices.json"
  models_cache="$repo/.git/ai-for-dummies/ecologits.json"
}

q() {
  node "$BATS_TEST_DIRNAME/query.mjs" "$@"
}

adapter() {
  printf '%s\n' '#!/bin/sh' "cat <<'JSON'" "$2" 'JSON' > "$repo/.agents/metrics/adapters/$1"
  chmod +x "$repo/.agents/metrics/adapters/$1"
}

record() {
  START="${START:-2026-10-16T10:00:00.000Z}" node -e '
const [agent, wall, active, tools, servers, commands, tokens, subs, count, models] = process.argv.slice(1)
console.log(JSON.stringify({ agent, session: process.env.SESSION ?? "s", prompt: process.env.PROMPT ?? "p", start: process.env.START, wall_ms: JSON.parse(wall), active_ms: JSON.parse(active), tokens: JSON.parse(tokens), subagent_tokens: JSON.parse(subs), subagents: JSON.parse(count), tools: JSON.parse(tools), mcp_servers: JSON.parse(servers), commands: JSON.parse(commands), models: JSON.parse(models) }))' "$@"
}

zero='{"input":0,"output":0,"cache_read":0,"cache_write":0}'
million='{"input":1000000,"output":1000000,"cache_read":1000000,"cache_write":1000000}'

check_result() {
  mkdir -p "$repo/$(dirname "${3:-.agents/hooks/pre-commit}")"
  : > "$repo/${3:-.agents/hooks/pre-commit}"
  verdict check "$1" "$2" "" "${3:-.agents/hooks/pre-commit}"
}

verdict() {
  sh "$repo/.agents/metrics/log.sh" "$@"
}

prices_file() {
  cat > "$1" <<'JSON'
{
  "sample_spec": {"litellm_provider": "none"},
  "claude-a": {"litellm_provider": "anthropic", "input_cost_per_token": 1e-6, "output_cost_per_token": 2e-6, "cache_read_input_token_cost": 1e-7, "cache_creation_input_token_cost": 1.5e-6},
  "claude-b": {"litellm_provider": "anthropic", "input_cost_per_token": 2e-6, "output_cost_per_token": 4e-6, "cache_read_input_token_cost": 2e-7, "cache_creation_input_token_cost": 3e-6},
  "anthropic.claude-z": {"litellm_provider": "bedrock", "input_cost_per_token": 9e-6, "output_cost_per_token": 9e-6, "cache_read_input_token_cost": 9e-6, "cache_creation_input_token_cost": 9e-6},
  "claude-c": {"litellm_provider": "anthropic", "input_cost_per_token": 3e-6, "output_cost_per_token": 3e-6}
}
JSON
}

age_cache() {
  node -e 'const fs = require("fs"); const [file, days] = process.argv.slice(1); const c = JSON.parse(fs.readFileSync(file, "utf8")); c.fetched_at = new Date(Date.now() - days * 86400000).toISOString(); delete c.attempted_at; fs.writeFileSync(file, JSON.stringify(c))' "${2:-$cache}" "$1"
}

bars() {
  node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
for (const bar of html.matchAll(/<div class="bar[ "][^>]*>/g)) {
  const attr = (name) => (bar[0].match(new RegExp(`${name}="([^"]*)"`)) ?? [])[1] ?? ""
  if (attr("data-series") !== process.argv[2]) continue
  const height = (attr("style").match(/height: *([\d.]+)%/) ?? [])[1] ?? ""
  console.log([attr("data-day"), attr("data-value"), height, attr("data-low"), attr("data-high"), attr("data-tip")].join("\t"))
}' "$2" "$1"
}

figure() {
  node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const at = html.indexOf(`data-figure="${process.argv[2]}"`)
console.log(at < 0 ? "" : html.slice(html.lastIndexOf("<figure", at), html.indexOf("</figure>", at) + 9))' "$1" "$2"
}

ticks() {
  figure "$1" "$2" | node -e '
const y = (require("fs").readFileSync(0, "utf8").match(/<div class="y"[^>]*>([\s\S]*?)<\/div>/) ?? [])[1] ?? ""
const unit = { k: 1e3, M: 1e6, B: 1e9, s: 1e3, min: 6e4, h: 3.6e6 }
for (const m of y.matchAll(/<span[^>]*>([^<]*)<\/span>/g)) {
  const tick = m[1].replace("$", "").trim().match(/^([\d.]+) *(k|M|B|s|min|h)?$/)
  console.log(tick ? Number(tick[1]) * (unit[tick[2]] ?? 1) : NaN)
}'
}

browser() {
  command -v google-chrome || command -v chromium || command -v chromium-browser
}

require_browser() {
  browser > /dev/null || skip "no browser to run the dashboard"
}

measure() {
  local page="$BATS_TEST_TMPDIR/measure.html"
  EXPRESSION="$1" node -e '
const fs = require("fs")
const script = `<script>{ const out = document.createElement("pre"); out.id = "measure"; out.textContent = JSON.stringify(${process.env.EXPRESSION}); document.body.append(out) }</script>`
fs.writeFileSync(process.argv[2], fs.readFileSync(process.argv[1], "utf8").replace("</body>", `${script}</body>`))' "$BATS_TEST_TMPDIR/d.html" "$page"
  "$(browser)" --headless=new --disable-gpu --no-sandbox --user-data-dir="$BATS_TEST_TMPDIR/profile" --dump-dom "file://$page" 2> /dev/null | node -e '
const dom = require("fs").readFileSync(0, "utf8")
console.log(((dom.match(/<pre id="measure">([\s\S]*?)<\/pre>/) ?? [])[1] ?? "null").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&"))'
}

clicked_dom() {
  local chart="$1" page="$BATS_TEST_TMPDIR/clicked.html" series
  shift
  local clicks=""
  for series in "$@"; do
    clicks="$clicks document.querySelector('[data-figure=\"$chart\"] .key[data-series=\"$series\"]').click();"
  done
  sed "s|</body>|<script>$clicks</script></body>|" "$BATS_TEST_TMPDIR/d.html" > "$page"
  "$(browser)" --headless=new --disable-gpu --no-sandbox --user-data-dir="$BATS_TEST_TMPDIR/profile" --dump-dom "file://$page" 2>/dev/null
}

day_table() {
  node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const table = (html.match(new RegExp(`<table[^>]*data-table="${process.argv[2] || "usage"}"[^>]*>[\\s\\S]*?</table>`)) ?? [""])[0]
for (const row of table.matchAll(/<tr>([\s\S]*?)<\/tr>/g)) console.log([...row[1].matchAll(/<t[dh]>([\s\S]*?)<\/t[dh]>/g)].map((c) => c[1].replace(/<ul>[\s\S]*?<\/ul>/g, "").replace(/<[^>]*>/g, "").trim()).join("\t"))' "$1" "${2:-usage}"
}

chart_days() {
  START="$1" PROMPT="$2" record claude "${WALL:-0}" "${ACTIVE:-null}" '{}' '{}' '[]' "$3" "$4" 0 "$5"
}

chart_data() {
  with_prices
  with_models
  adapter claude "$(WALL=120000 ACTIVE=60000 chart_days 2026-10-10T08:00:00.000Z a '{"input":1000000,"output":2000,"cache_read":5000000,"cache_write":300}' "$zero" '{"claude-a":{"input":1000000,"output":0,"cache_read":0,"cache_write":0}}'
    WALL=3600000 ACTIVE=1800000 chart_days 2026-10-12T08:00:00.000Z b '{"input":2000000,"output":0,"cache_read":0,"cache_write":0}' '{"input":1000000,"output":0,"cache_read":0,"cache_write":0}' '{"claude-a":{"input":3000000,"output":0,"cache_read":0,"cache_write":0}}'
    WALL=600000 chart_days 2026-10-12T21:00:00.000Z c '{"input":0,"output":1600,"cache_read":0,"cache_write":0}' "$zero" '{}')"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
}

report() {
  node "$repo/.agents/metrics/metrics.mjs" "$@"
}

with_prices() {
  prices_file "$BATS_TEST_TMPDIR/prices.json"
  export AI_FOR_DUMMIES_PRICES_URL="file://$BATS_TEST_TMPDIR/prices.json"
}

models_file() {
  cat > "$1" <<'JSON'
{
  "aliases": [
    {"type": "alias", "provider": "anthropic", "name": "claude-haiku-4-5", "alias": "claude-haiku-4-5-20251001"}
  ],
  "models": [
    {"type": "model", "provider": "anthropic", "name": "claude-opus-4-6", "architecture": {"type": "moe", "parameters": {"total": 670, "active": {"min": 67, "max": 200}}}, "warnings": ["model-arch-not-released"], "sources": [], "deployment": {"tps": 35, "ttft": 1.95}},
    {"type": "model", "provider": "anthropic", "name": "claude-haiku-4-5-20251001", "architecture": {"type": "dense", "parameters": {"min": 10, "max": 35}}, "warnings": ["model-arch-not-released"], "sources": [], "deployment": {"tps": 79, "ttft": 0.5}},
    {"type": "model", "provider": "openai", "name": "gpt-x", "architecture": {"type": "dense", "parameters": {"min": 1, "max": 2}}, "warnings": [], "sources": [], "deployment": {"tps": 50, "ttft": 1}}
  ]
}
JSON
}

with_models() {
  models_file "$BATS_TEST_TMPDIR/models.json"
  export AI_FOR_DUMMIES_MODELS_URL="file://$BATS_TEST_TMPDIR/models.json"
}

output_of() {
  record claude 0 null '{}' '{}' '[]' "$zero" "$zero" 0 "$(node -e 'console.log(JSON.stringify(Object.fromEntries(process.argv.slice(1).map((pair) => { const [id, output] = pair.split("="); return [id, { input: 0, output: Number(output), cache_read: 0, cache_write: 0 }] }))))' "$@")"
}

two_agents() {
  adapter claude "$(record claude 60000 30000 '{"Bash":3,"Read":3,"Edit":1,"Glob":1,"Grep":1,"Zed":1}' '{"chrome":2}' '["/scout"]' '{"input":1,"output":2,"cache_read":3,"cache_write":4}' '{"input":10,"output":20,"cache_read":30,"cache_write":40}' 2 '{}'
    record claude 30000 null '{"Bash":2}' '{}' '["/scout","/context"]' "$zero" "$zero" 0 '{}')"
  adapter codex "$(record codex 0 null '{}' '{}' '[]' "$zero" "$zero" 1 '{}')"
}

text() {
  sed -E 's/<title>[^<]*<\/title>//g; s/<[^>]*>/ /g; s/&lt;/</g; s/&gt;/>/g; s/&amp;/\&/g' "$1" | tr -s ' \n\t' ' '
}

