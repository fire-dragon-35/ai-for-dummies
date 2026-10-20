bats_require_minimum_version 1.5.0

setup() {
  load helpers
  setup_metrics_repo
}

@test "R17: writes the dashboard and prints its path" {
  two_agents
  run --separate-stderr report --html
  [ "$status" -eq 0 ]
  [ -s "$repo/.git/ai-for-dummies/dashboard.html" ]
  [[ "$output" == *dashboard.html ]]
  mkdir -p "$BATS_TEST_TMPDIR/out" && echo old > "$BATS_TEST_TMPDIR/out/d.html"
  run --separate-stderr report "$repo" --html "$BATS_TEST_TMPDIR/out/d.html"
  [ "$status" -eq 0 ]
  run ! grep -qx old "$BATS_TEST_TMPDIR/out/d.html"
  run --separate-stderr report --html "$BATS_TEST_TMPDIR/new/deep/d.html"
  [ -s "$BATS_TEST_TMPDIR/new/deep/d.html" ]
}

@test "R18: the dashboard loads nothing from the network" {
  two_agents
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const urls = [...html.matchAll(/(?:\bsrc\s*=|<link\b[^>]*\bhref\s*=|url\(|@import)\s*["\x27]?((?:https?:)?\/\/[^"\x27)\s>]+)/gi)].map((m) => m[1])
console.log(urls.length === 0)' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}

@test "R19: the dashboard shows rankings and the most failing tests" {
  two_agents
  verdict test "R2: b" fail
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  t="$(text "$BATS_TEST_TMPDIR/d.html")"
  for want in Bash chrome /scout 'R2: b'; do
    [[ "$t" == *"$want"* ]] || { echo "missing: $want"; return 1; }
  done
}

@test "R21: shows names as text" {
  adapter claude "$(record claude 0 null '{"<b id=x>bold</b>":1}' '{}' '["</script><u>cmd</u>"]' "$zero" "$zero" 0 '{}')"
  check_result '<s>check</s>' pass
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  for raw in '<b id=x>' '<u>cmd</u>' '<s>check</s>'; do run ! grep -qF "$raw" "$BATS_TEST_TMPDIR/d.html"; done
  [[ "$(text "$BATS_TEST_TMPDIR/d.html")" == *'<b id=x>bold</b>'* ]]
}

@test "R22: the dashboard says no metrics yet without records" {
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  [[ "$(text "$BATS_TEST_TMPDIR/d.html")" == *"no metrics yet"* ]]
}

@test "R51: the dashboard carries every design token with its value" {
  two_agents
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  tokens="$(grep -oE '^ *--[a-z0-9-]+: [^;]+' "$source_root/.agents/metrics/tokens.css" | sed -E 's/^ +//')"
  [ "$(printf '%s\n' "$tokens" | wc -l)" -eq "$(grep -cE '^ *--[a-z0-9-]+:' "$source_root/.agents/metrics/tokens.css")" ]
  [ "$(printf '%s\n' "$tokens" | wc -l)" -ge 15 ]
  printf '%s\n' "$tokens" | while IFS= read -r pair; do
    grep -qF -- "$pair" "$BATS_TEST_TMPDIR/d.html" || { echo "missing: $pair"; exit 1; }
  done
}

@test "R53: switches off transitions for readers who prefer reduced motion" {
  two_agents
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const block = html.match(/@media[^{]*prefers-reduced-motion[^{]*\{[\s\S]*?\n\}/)?.[0] ?? ""
console.log(/transition:\s*none/.test(block))' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}

navbar_ok() {
  node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const nav = html.match(/<(header|nav)[\s\S]*?<\/(header|nav)>/)
const body = html.indexOf("<body")
console.log(Boolean(nav) && nav.index > body && nav[0].includes("AI for dummies 😵‍💫") && html.slice(body).replace(/^<body[^>]*>\s*/, "").startsWith(nav[0]))' "$1"
}

navbar_text() {
  node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
console.log((html.match(/<(header|nav)[\s\S]*?<\/(header|nav)>/)?.[0] ?? "").replace(/<[^>]*>/g, " "))' "$1"
}

@test "R54: starts with a navbar named AI for dummies, also without records" {
  report --html "$BATS_TEST_TMPDIR/empty.html" > /dev/null
  [ "$(navbar_ok "$BATS_TEST_TMPDIR/empty.html")" = true ]
  two_agents
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  [ "$(navbar_ok "$BATS_TEST_TMPDIR/d.html")" = true ]
}

@test "R55: shows the short hash of HEAD, or no commits yet" {
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  [[ "$(navbar_text "$BATS_TEST_TMPDIR/d.html")" == *"no commits yet"* ]]
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m first
  first="$(git rev-parse --short HEAD)"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  [[ "$(navbar_text "$BATS_TEST_TMPDIR/d.html")" == *"$first"* ]]
  [[ "$(navbar_text "$BATS_TEST_TMPDIR/d.html")" != *"$(git rev-parse HEAD)"* ]]
  [[ "$(navbar_text "$BATS_TEST_TMPDIR/d.html")" != *"no commits yet"* ]]
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m second
  second="$(git rev-parse --short HEAD)"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  [[ "$(navbar_text "$BATS_TEST_TMPDIR/d.html")" == *"$second"* ]]
  [[ "$(navbar_text "$BATS_TEST_TMPDIR/d.html")" != *"$first"* ]]
}

@test "R56: shows when the dashboard was generated" {
  before="$(date -u +%s)"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  run node -e '
const match = process.argv[1].match(/(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}) UTC/)
const stamp = match ? Date.parse(`${match[1]}T${match[2]}:00Z`) / 1000 : 0
const before = Number(process.argv[2])
console.log(Boolean(match) && stamp >= before - 60 && stamp <= before + 180)' "$(navbar_text "$BATS_TEST_TMPDIR/d.html")" "$before"
  [ "$output" = true ]
}

series_in_order="cache_read output input_write cost active wall prompts"

values() {
  bars "$1" "$BATS_TEST_TMPDIR/d.html" | cut -f2 | node -e 'console.log(require("fs").readFileSync(0, "utf8").trim().split("\n").map((v) => Math.round(Number(v) * 100) / 100).join(","))'
}

@test "R57: the usage section comes first with tokens, cost, time and prompts charts" {
  chart_data
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const usage = html.indexOf("data-chart=\"usage\"")
const first = html.indexOf("<section", html.indexOf("</header>"))
const figures = [...html.matchAll(/<figure[^>]*data-figure="([^"]*)"[\s\S]*?<figcaption>([^<]*)<\/figcaption>/g)].map((m) => [m[1], m[2]])
const usageFigures = figures.slice(0, 4)
console.log(usage > first && usage < html.indexOf("</section>", first) && usageFigures.map((f) => f[0]).join() === "tokens,cost,time,prompts" && usageFigures.every((f) => f[1].includes(f[0])) && usageFigures[1][1].startsWith("estimated true cost"))' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}

@test "R58: covers the days from the first to the latest record" {
  chart_data
  for series in $series_in_order; do
    [ "$(bars "$series" "$BATS_TEST_TMPDIR/d.html" | cut -f1 | paste -sd, -)" = "2026-10-10,2026-10-11,2026-10-12" ] || { echo "$series"; return 1; }
  done
}

@test "R58: shows at most the last 30 days" {
  records=""
  for i in $(seq 0 34); do
    day="$(date -u -d "2026-09-26 + $i days" +%Y-%m-%d)"
    records="$records$(chart_days "${day}T08:00:00.000Z" "p$i" '{"input":1,"output":0,"cache_read":0,"cache_write":0}' "$zero" '{}')
"
  done
  adapter claude "$records"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  days="$(bars prompts "$BATS_TEST_TMPDIR/d.html" | cut -f1)"
  [ "$(printf '%s\n' "$days" | wc -l)" -eq 30 ]
  [ "$(printf '%s\n' "$days" | head -n 1)" = 2026-10-01 ]
  [ "$(printf '%s\n' "$days" | tail -n 1)" = 2026-10-30 ]
}

@test "R59: every series has a bar per day with that day's value, zero for gaps" {
  chart_data
  [ "$(values cache_read)" = "5000000,0,0" ]
  [ "$(values output)" = "2000,0,1600" ]
  [ "$(values input_write)" = "1000300,0,3000000" ]
  [ "$(values cost)" = "1,0,3" ]
  [ "$(values active)" = "60000,0,1800000" ]
  [ "$(values wall)" = "120000,0,4200000" ]
  [ "$(values prompts)" = "1,0,2" ]
}

@test "R59: a day runs from 00:00:00 to 23:59:59 UTC and sums all its records" {
  adapter claude "$(chart_days 2026-10-10T23:59:59.000Z a '{"input":0,"output":1,"cache_read":0,"cache_write":0}' "$zero" '{}'
    chart_days 2026-10-11T00:00:00.000Z b '{"input":0,"output":10,"cache_read":0,"cache_write":0}' "$zero" '{}'
    chart_days 2026-10-11T23:59:59.000Z c '{"input":0,"output":100,"cache_read":0,"cache_write":0}' "$zero" '{}')"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  [ "$(bars output "$BATS_TEST_TMPDIR/d.html" | cut -f1,2 | tr '\t' ' ' | paste -sd, -)" = "2026-10-10 1,2026-10-11 110" ]
}

@test "R60: one scale per chart, the highest day above 40 %" {
  chart_data
  for chart in "tokens cache_read output input_write" "cost cost" "time active wall" "prompts prompts"; do
    set -- $chart
    top="$(ticks "$BATS_TEST_TMPDIR/d.html" "$1" | sort -g | tail -n 1)"
    rows="$(for series in "${@:2}"; do bars "$series" "$BATS_TEST_TMPDIR/d.html"; done)"
    run node -e '
const rows = require("fs").readFileSync(0, "utf8").trim().split("\n").map((line) => line.split("\t"))
const days = [...new Set(rows.map((r) => r[0]))]
const top = Number(process.argv[2])
const heights = days.map((day) => Math.max(0, ...rows.filter((r) => r[0] === day).map((r) => Number(r[2]))))
const proportional = top > 0 && rows.every((r) => Math.abs(Number(r[2]) - (Number(r[1]) / top) * 100) < 0.05)
console.log(proportional && heights[1] === 0 && Math.max(...heights) >= 40 && Math.max(...heights) <= 100)' "$1" "$top" <<< "$rows"
    [ "$output" = true ] || { echo "$1"; return 1; }
  done
}

@test "R62: without prices the cost chart has no bar and says unavailable" {
  adapter claude "$(chart_days 2026-10-10T08:00:00.000Z a '{"input":1000000,"output":0,"cache_read":0,"cache_write":0}' "$zero" '{"claude-a":{"input":1000000,"output":0,"cache_read":0,"cache_write":0}}')"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  [ -z "$(bars cost "$BATS_TEST_TMPDIR/d.html")" ]
  [ -n "$(bars prompts "$BATS_TEST_TMPDIR/d.html")" ]
  figure "$BATS_TEST_TMPDIR/d.html" cost | grep -qE '<figcaption>[^<]*unavailable'
  [ "$(day_table "$BATS_TEST_TMPDIR/d.html" | tail -n +2 | cut -f7 | sort -u)" = "-" ]
}

@test "R63: the energy column is headed estimated energy" {
  chart_data
  [ "$(day_table "$BATS_TEST_TMPDIR/d.html" | head -n 1 | cut -f8)" = "estimated energy" ]
}

@test "R64: every chart has an image role and a label naming title and window" {
  chart_data
  for name in tokens cost time prompts; do
    tag="$(figure "$BATS_TEST_TMPDIR/d.html" "$name" | head -n 1 | grep -oE '^<figure[^>]*>')"
    [[ "$tag" == *'role="img"'* ]] || { echo "$name"; return 1; }
    [[ "$tag" =~ aria-label=\"[^\"]*$name[^\"]*2026-10-10[^\"]*2026-10-12[^\"]*\" ]] || { echo "$name"; return 1; }
  done
}

@test "R65: shows no usage chart and no usage table without usage records" {
  check_result shellcheck pass
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  [ -s "$BATS_TEST_TMPDIR/d.html" ]
  run ! grep -qE 'data-chart="usage"|data-table="usage"' "$BATS_TEST_TMPDIR/d.html"
}

@test "R67: has no page title heading and names the repository only in the navbar" {
  chart_data
  run ! grep -qi '<h1' "$BATS_TEST_TMPDIR/d.html"
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const nav = html.match(/<(header|nav)[\s\S]*?<\/(header|nav)>/)?.[0] ?? ""
console.log(nav.includes("my repo") && !html.replace(nav, "").includes("my repo"))' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}

@test "R84: the navbar shows the absolute path of the repository" {
  chart_data
  [[ "$(navbar_text "$BATS_TEST_TMPDIR/d.html")" == *"$(cd "$repo" && pwd -P)"* ]]
}

@test "R85: bars are colored only with design tokens" {
  chart_data
  run node -e '
const fs = require("fs")
const html = fs.readFileSync(process.argv[1], "utf8")
const defined = new Set([...fs.readFileSync(process.argv[2], "utf8").matchAll(/(--[a-z0-9-]+)\s*:/g)].map((m) => m[1]))
const css = [...html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map((m) => m[1]).join("\n")
const bars = [...html.matchAll(/<div class="bar[ "][^>]*>/g)].map((m) => m[0])
const classes = new Set(bars.flatMap((bar) => bar.match(/class="([^"]*)"/)[1].split(/\s+/).filter(Boolean)))
const inline = bars.some((bar) => /(background|color|fill)\s*:/.test(bar.match(/style="([^"]*)"/)?.[1] ?? ""))
const colors = [...classes].flatMap((c) => [...css.matchAll(new RegExp(`\\.${c}\\b[^{]*\\{([^}]*)\\}`, "g"))].flatMap((rule) => [...rule[1].matchAll(/(?:background(?:-color)?|fill)\s*:\s*([^;]+)/g)].map((d) => d[1].trim())))
console.log(bars.length > 0 && !inline && colors.length > 0 && colors.every((v) => defined.has(v.match(/^var\((--[a-z0-9-]+)\)$/)?.[1])))' "$BATS_TEST_TMPDIR/d.html" "$source_root/.agents/metrics/tokens.css"
  [ "$output" = true ]
}

@test "R68: every bar shows its day, series and formatted value as a tooltip" {
  chart_data
  [ "$(bars output "$BATS_TEST_TMPDIR/d.html" | cut -f6 | paste -sd'|' -)" = "2026-10-10 output tokens: 2.0k|2026-10-11 output tokens: 0|2026-10-12 output tokens: 1.6k" ]
  [ "$(bars cost "$BATS_TEST_TMPDIR/d.html" | cut -f6 | tail -n 1)" = '2026-10-12 estimated true cost: $3.0' ]
  [ "$(bars wall "$BATS_TEST_TMPDIR/d.html" | cut -f6 | tail -n 1)" = '2026-10-12 wall time: 1.2 h' ]
}

@test "R69: the table holds the tooltip values per day and a total row" {
  chart_data
  table="$(day_table "$BATS_TEST_TMPDIR/d.html")"
  [ "$(printf '%s\n' "$table" | head -n 1 | tr 'A-Z' 'a-z')" = "$(printf 'day\tprompts\tinput tokens\toutput tokens\tcache read tokens\tcache write tokens\testimated true cost\testimated energy\tactive time\twall time')" ]
  for pair in prompts:2 output:4 cache_read:5 cost:7 active:9 wall:10; do
    series="${pair%%:*}"
    column="${pair##*:}"
    expected="$(bars "$series" "$BATS_TEST_TMPDIR/d.html" | cut -f6 | sed -E 's/^[^:]*: //' | paste -sd, -)"
    [ "$(printf '%s\n' "$table" | sed -n '2,4p' | cut -f"$column" | paste -sd, -)" = "$expected" ] || { echo "$series"; return 1; }
  done
  [ "$(printf '%s\n' "$table" | sed -n '2,4p' | cut -f3,6,8 | tr '\t' ' ' | paste -sd, -)" = "1.0M 300 0.0 Wh,0 0 0.0 Wh,3.0M 0 0.0 Wh" ]
  [ "$(printf '%s\n' "$table" | tail -n 1)" = "$(printf 'total\t3\t4.0M\t3.6k\t5.0M\t300\t$4.0\t0.0 Wh\t31.0 min\t1.2 h')" ]
  [ "$(printf '%s\n' "$table" | wc -l)" -eq 5 ]
}

@test "R70: the table comes right after the usage section" {
  check_result shellcheck pass
  chart_data
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const end = html.indexOf("</section>", html.indexOf("data-chart=\"usage\""))
const table = html.search(/<table[^>]*data-table="usage"/)
console.log(table > end && !/<(h2|section|table)\b/.test(html.slice(end + 10, table)))' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}

@test "R71: every chart labels each day, with the month only where it starts" {
  records=""
  for day in 2026-10-30 2026-11-02; do
    records="$records$(chart_days "${day}T08:00:00.000Z" "p$day" '{"input":1,"output":0,"cache_read":0,"cache_write":0}' "$zero" '{}')
"
  done
  adapter claude "$records"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  for name in tokens cost time prompts; do
    run node -e '
const chart = require("fs").readFileSync(0, "utf8")
const x = (chart.match(/<div class="x">([\s\S]*?)<\/div>/) ?? [])[1] ?? ""
const labels = [...x.matchAll(/<span>([^<]*)<\/span>/g)].map((m) => m[1])
console.log(labels.join() === "Oct 30,31,Nov 1,2" && !/2026-/.test(chart.replace(/<[^>]*>/g, " ")))' <<< "$(figure "$BATS_TEST_TMPDIR/d.html" "$name")"
    [ "$output" = true ] || { echo "$name"; return 1; }
  done
}

@test "R82: every chart has a linear y axis in equal steps up to a top tick at least its highest value" {
  chart_data
  for name in tokens cost time prompts; do
    run node -e '
const chart = require("fs").readFileSync(0, "utf8")
const ticks = process.argv[1].split("\n").map(Number)
const values = [...chart.matchAll(/data-value="([^"]*)"/g)].map((m) => Number(m[1]))
const steps = ticks.slice(1).map((tick, i) => tick - ticks[i])
const equal = steps.every((step) => step > 0 && Math.abs(step - steps[0]) < steps[0] * 0.001)
console.log(ticks.every(Number.isFinite) && ticks[0] === 0 && steps.length >= 1 && steps.length <= 5 && equal && ticks.at(-1) >= Math.max(...values))' "$(ticks "$BATS_TEST_TMPDIR/d.html" "$name")" <<< "$(figure "$BATS_TEST_TMPDIR/d.html" "$name")"
    [ "$output" = true ] || { echo "$name"; return 1; }
  done
}

@test "R83: charts with two or more series have a legend whose swatch colors every bar of its series" {
  chart_data
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const figure = (name) => { const at = html.indexOf(`data-figure="${name}"`); return html.slice(html.lastIndexOf("<figure", at), html.indexOf("</figure>", at)) }
const legend = (name) => [...((figure(name).match(/<div class="legend">([\s\S]*?)<\/div>/) ?? [])[1] ?? "").matchAll(/<button[^>]*>([\s\S]*?)<\/button>/g)].map((item) => [item[1].match(/class="sw ([^"]+)"/)[1], item[1].replace(/<[^>]*>/g, "").trim()])
const colors = (series) => new Set([...html.matchAll(new RegExp(`class="bar ([^"]+)"[^>]*data-series="${series}"`, "g"))].map((m) => m[1]))
const tokens = legend("tokens")
const time = legend("time")
const match = (items, series) => items.length === series.length && series.every((s, i) => colors(s).size === 1 && colors(s).has(items[i][0]))
console.log(match(tokens, ["cache_read", "output", "input_write"]) && match(time, ["active", "wall"]) && legend("cost").length === 0 && legend("prompts").length === 0 && tokens.map((t) => t[1]).join("|") === "cache read tokens|output tokens|input + cache write tokens")' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}

@test "R72: writes counts with k and M" {
  chart_data
  table="$(day_table "$BATS_TEST_TMPDIR/d.html")"
  [ "$(printf '%s\n' "$table" | sed -n 2p | cut -f2-6)" = "$(printf '1\t1.0M\t2.0k\t5.0M\t300')" ]
}

@test "R73: writes times in minutes below an hour and in hours from an hour" {
  chart_data
  table="$(day_table "$BATS_TEST_TMPDIR/d.html")"
  [ "$(printf '%s\n' "$table" | sed -n 2p | cut -f9,10)" = "$(printf '1.0 min\t2.0 min')" ]
  [ "$(printf '%s\n' "$table" | sed -n 4p | cut -f9,10)" = "$(printf '30.0 min\t1.2 h')" ]
}

@test "R74: shows no separate totals, subagents, models or slowest prompts" {
  chart_data
  node -e 'process.stdout.write(require("fs").readFileSync(process.argv[1], "utf8").replace(/<details[\s\S]*?<\/details>/g, ""))' "$BATS_TEST_TMPDIR/d.html" > "$BATS_TEST_TMPDIR/without-note.html"
  t="$(text "$BATS_TEST_TMPDIR/without-note.html" | tr 'A-Z' 'a-z')"
  [[ "$t" != *subagent* && "$t" != *slowest* && "$t" != *claude-a* ]]
}
