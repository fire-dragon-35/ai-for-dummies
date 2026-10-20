bats_require_minimum_version 1.5.0

setup() {
  load helpers
  setup_metrics_repo
}

visible_bars() {
  node -e '
const dom = require("fs").readFileSync(0, "utf8")
const at = dom.indexOf(`data-figure="${process.argv[1]}"`)
const figure = dom.slice(dom.lastIndexOf("<figure", at), dom.indexOf("</figure>", at))
const bars = [...figure.matchAll(/<div class="slot"([^>]*)><div class="bar[ "]([^>]*)>/g)].map((m) => ({ hidden: /\bhidden\b/.test(m[1]), series: m[2].match(/data-series="([^"]*)"/)[1], value: Number(m[2].match(/data-value="([^"]*)"/)[1]), height: Number(m[2].match(/height: *([\d.]+)%/)[1]) }))
const axis = [...figure.matchAll(/<div class="y"([^>]*)>([\s\S]*?)<\/div>/g)].find((m) => !/\bhidden\b/.test(m[1]))
const labels = [...axis[2].matchAll(/<span[^>]*>([^<]*)<\/span>/g)].map((m) => m[1])
const top = Number(axis[1].match(/data-top="([^"]*)"/)[1])
console.log(JSON.stringify({ visible: [...new Set(bars.filter((b) => !b.hidden).map((b) => b.series))], rescaled: bars.filter((b) => !b.hidden).every((b) => Math.abs(b.height - (b.value / top) * 100) < 0.05), labels }))' "$1"
}

@test "R86: every chart has one legend row, with buttons only for charts of two or more series" {
  chart_data
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const figures = html.split("<figure").slice(1).map((f) => f.slice(0, f.indexOf("</figure>")))
const buttons = (name) => { const f = figures.find((x) => x.includes(`data-figure="${name}"`)); return (f.match(/<button/g) ?? []).length }
console.log(figures.length === 4 && figures.every((f) => (f.match(/class="legend"/g) ?? []).length === 1) && ["cost", "prompts"].every((n) => buttons(n) === 0) && ["tokens", "time"].every((n) => buttons(n) >= 2))' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}

@test "R86: the bars of a day do not overlap" {
  require_browser
  chart_data
  groups="$(measure '[...document.querySelectorAll(".group")].map((group) => [...group.querySelectorAll(".bar")].map((bar) => { const r = bar.getBoundingClientRect(); return [r.left, r.right, r.width] }))')"
  run node -e '
const groups = JSON.parse(process.argv[1])
const side = groups.filter((bars) => bars.length > 1)
console.log(side.length > 0 && side.every((bars) => bars.every((b) => b[2] > 0) && bars.every((b, i) => i === 0 || b[0] >= bars[i - 1][1] - 0.5)))' "$groups"
  [ "$output" = true ]
}

@test "R87: every legend button starts pressed and every bar visible" {
  chart_data
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const buttons = [...html.matchAll(/<button[^>]*class="key"[^>]*>/g)].map((m) => m[0])
const bars = [...html.matchAll(/<div class="slot"([^>]*)>/g)].map((m) => m[1])
console.log(buttons.length > 0 && buttons.every((b) => /aria-pressed="true"/.test(b)) && bars.length > 0 && bars.every((b) => !/hidden/.test(b)))' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}

@test "R88: clicking a legend button hides its series and rescales the chart, clicking again restores it" {
  require_browser
  chart_data
  full="$(clicked_dom tokens | visible_bars tokens)"
  hidden="$(clicked_dom tokens cache_read | visible_bars tokens)"
  restored="$(clicked_dom tokens cache_read cache_read | visible_bars tokens)"
  [ "$(node -e 'const [f, h] = process.argv.slice(1).map(JSON.parse); console.log(f.visible.join() === "cache_read,output,input_write" && h.visible.join() === "output,input_write" && h.rescaled && f.rescaled && h.labels.join() !== f.labels.join())' "$full" "$hidden")" = true ]
  [ "$restored" = "$full" ]
}

@test "R89: the last visible series of a chart cannot be hidden" {
  require_browser
  chart_data
  result="$(clicked_dom tokens cache_read output input_write | visible_bars tokens)"
  [ "$(node -e 'const r = JSON.parse(process.argv[1]); console.log(r.visible.join() === "input_write" && r.rescaled)' "$result")" = true ]
}

@test "R90: a bar shows its tooltip text when the pointer is over it" {
  chart_data
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const css = [...html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map((m) => m[1]).join("\n")
const tips = [...html.matchAll(/<div class="bar[ "][^>]*data-tip="([^"]+)"/g)]
console.log(tips.length > 0 && /:hover[^{]*::after\s*\{[^}]*content:\s*attr\(data-tip\)/.test(css))' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}

@test "R91: the estimated true cost column has a drop down on token counts, rates and calculation, no chart has one" {
  chart_data
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const figures = html.split("<figure").slice(1).map((f) => f.slice(0, f.indexOf("</figure>")))
const table = (html.match(/<table[^>]*data-table="usage"[^>]*>[\s\S]*?<\/table>/) ?? [""])[0]
const header = [...table.matchAll(/<th>([\s\S]*?)<\/th>/g)].map((m) => m[1]).find((cell) => cell.replace(/<ul>[\s\S]*?<\/ul>/g, "").replace(/<[^>]*>/g, "").trim() === "estimated true cost") ?? ""
const note = (header.match(/<details[\s\S]*?<\/details>/) ?? [""])[0]
const text = note.replace(/<[^>]*>/g, " ").toLowerCase()
const link = (note.match(/<a [^>]*href="([^"]+)"/) ?? [])[1] ?? ""
const summary = (note.match(/<summary[^>]*>([\s\S]*?)<\/summary>/) ?? [])
console.log(summary[0] !== undefined && !/title=/.test(header) && summary[1] === "estimated" && /aria-label="how is cost estimated"/.test(summary[0]) && /^https:\/\/.*litellm/i.test(link) && ["input", "output", "cache read", "cache write", "rate"].every((word) => text.includes(word)) && figures.length === 4 && figures.every((f) => !/<details/.test(f)))' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}

@test "R69: the table shows the minimum energy per day and a total" {
  with_models
  adapter claude "$(START=2026-10-10T08:00:00.000Z output_of claude-haiku-4-5-20251001=1000000
    START=2026-10-11T08:00:00.000Z output_of claude-opus-4-6=1000000)"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  table="$(day_table "$BATS_TEST_TMPDIR/d.html")"
  [ "$(printf '%s\n' "$table" | sed -n '2,3p' | cut -f8 | paste -sd, -)" = "59.4 Wh,3.4 kWh" ]
  [ "$(printf '%s\n' "$table" | tail -n 1 | cut -f8)" = "3.5 kWh" ]
}

@test "R106: writes costs with one decimal and energies in Wh with one decimal" {
  chart_data
  table="$(day_table "$BATS_TEST_TMPDIR/d.html")"
  [ "$(printf '%s\n' "$table" | sed -n 2p | cut -f7,8)" = "$(printf '$1.0\t0.0 Wh')" ]
  [ "$(printf '%s\n' "$table" | tail -n 1 | cut -f7)" = '$4.0' ]
}

@test "R97: without model data the energy cells show a dash" {
  adapter claude "$(output_of claude-haiku-4-5-20251001=1000000)"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  [ "$(day_table "$BATS_TEST_TMPDIR/d.html" | tail -n +2 | cut -f8 | sort -u)" = "-" ]
}

@test "R96: the estimated energy column has a drop down saying the minimum estimate is used" {
  chart_data
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const table = (html.match(/<table[^>]*data-table="usage"[^>]*>[\s\S]*?<\/table>/) ?? [""])[0]
const header = [...table.matchAll(/<th>([\s\S]*?)<\/th>/g)].map((m) => m[1]).find((cell) => cell.replace(/<ul>[\s\S]*?<\/ul>/g, "").replace(/<[^>]*>/g, "").trim() === "estimated energy") ?? ""
const note = (header.match(/<details[\s\S]*?<\/details>/) ?? [""])[0]
const text = note.replace(/<[^>]*>/g, " ").toLowerCase()
const link = (note.match(/<a [^>]*href="([^"]+)"/) ?? [])[1] ?? ""
const summary = (note.match(/<summary[^>]*>([\s\S]*?)<\/summary>/) ?? [])
console.log(summary[0] !== undefined && !/title=/.test(header) && summary[1] === "estimated" && /aria-label="how is energy estimated"/.test(summary[0]) && /^https:\/\/.*ecologits/i.test(link) && ["output tokens", "parameters", "minimum"].every((word) => text.includes(word)))' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}
