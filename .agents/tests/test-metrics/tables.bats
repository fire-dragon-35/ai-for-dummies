bats_require_minimum_version 1.5.0

setup() {
  load helpers
  setup_metrics_repo
}

row_boxes() {
  node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const table = (html.match(new RegExp(`<table[^>]*data-table="${process.argv[2]}"[^>]*>[\\s\\S]*?</table>`)) ?? [""])[0]
const row = [...table.matchAll(/<tr[^>]*>([\s\S]*?)<\/tr>/g)].map((m) => m[1]).find((cells) => ((cells.match(/<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/) ?? [])[1] ?? "").replace(/<[^>]*>/g, "").trim().endsWith(process.argv[3])) ?? ""
const cells = [...row.matchAll(/<td[^>]*>([\s\S]*?)<\/td>/g)].map((m) => m[1])
if (process.argv[4] === "text") console.log(cells.map((cell) => cell.replace(/<[^>]*>/g, "").trim()).filter(Boolean).join(" "))
else for (const box of row.matchAll(/<(\w+)\b([^>]*\bdata-tip="([^"]*)"[^>]*)>([\s\S]*?)<\/\1>/g)) console.log([box[3], (box[2].match(/aria-label="([^"]*)"/) ?? [])[1] ?? "", (box[4].match(/<svg[\s\S]*?<\/svg>/) ?? [""])[0]].join("\t"))' "$1" "$2" "$3" "$4"
}

@test "R52: the checks table marks passed runs with a check icon and failed runs with a different cross icon" {
  check_result alpha pass
  check_result alpha pass
  check_result alpha fail
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  boxes="$(row_boxes "$BATS_TEST_TMPDIR/d.html" checks alpha)"
  [ "$(printf '%s\n' "$boxes" | cut -f2 | paste -sd, -)" = "pass,pass,fail" ]
  pass="$(printf '%s\n' "$boxes" | sed -n 1p | cut -f3)"
  fail="$(printf '%s\n' "$boxes" | sed -n 3p | cut -f3)"
  [ -n "$pass" ] && [ -n "$fail" ] && [ "$pass" != "$fail" ]
  [ "$(printf '%s\n' "$boxes" | sed -n 2p | cut -f3)" = "$pass" ]
}

@test "R79: the checks table has a row per check in ascending order with its last 10 runs and the day of the last fail" {
  check_result zeta pass
  check_result alpha fail
  check_result alpha fail
  for result in pass fail pass pass pass pass pass pass pass fail; do check_result alpha "$result"; done
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  today="$(date -u +%Y-%m-%d)"
  [ "$(row_boxes "$BATS_TEST_TMPDIR/d.html" checks alpha | cut -f1 | paste -sd, -)" = "$(printf "%s\n" pass fail pass pass pass pass pass pass pass fail | sed "s/^/$today /" | paste -sd, -)" ]
  [ "$(row_boxes "$BATS_TEST_TMPDIR/d.html" checks zeta | cut -f1)" = "$today pass" ]
  [ "$(row_boxes "$BATS_TEST_TMPDIR/d.html" checks alpha text)" = "alpha .agents/hooks/pre-commit $today" ]
  [ "$(row_boxes "$BATS_TEST_TMPDIR/d.html" checks zeta text)" = "zeta .agents/hooks/pre-commit -" ]
  t="$(text "$BATS_TEST_TMPDIR/d.html")"
  [[ "$t" =~ alpha.*zeta ]]
}

@test "R102: the checks table shows the sources of a check in ascending order" {
  check_result alpha pass .agents/hooks/pre-push
  check_result alpha pass .agents/hooks/pre-commit
  check_result alpha fail .agents/hooks/pre-push
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  t="$(text "$BATS_TEST_TMPDIR/d.html")"
  [[ "$t" =~ alpha.*\.agents/hooks/pre-commit.*\.agents/hooks/pre-push ]]
  [ "$(grep -o '\.agents/hooks/pre-push' <<< "$t" | wc -l)" -eq 1 ]
}

@test "R103: the dashboard lists no check without a source or with a source that does not exist" {
  verdict check nosource pass
  verdict check gone pass "" .agents/hooks/removed
  check_result alive pass
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  t="$(text "$BATS_TEST_TMPDIR/d.html")"
  [[ "$t" == *alive* && "$t" != *nosource* && "$t" != *gone* ]]
}

@test "R103: the report lists no check without a source or with a source that does not exist" {
  verdict check nosource pass
  verdict check gone pass "" .agents/hooks/removed
  check_result alive pass
  run report
  [[ "$output" == *alive* && "$output" != *nosource* && "$output" != *gone* ]]
}

@test "R80: the coverage table has a row per component with a box per requirement and the number of tests" {
  mkdir -p "$repo/.agents/tests/test-beta" "$repo/.agents/tests/test-alpha"
  printf '# Alpha\n- R1: a\n- R2: b\n- R3: c\n' > "$repo/.agents/tests/test-alpha/requirements.md"
  printf '@test "R1: first" {\n  true\n}\n@test "R1: again" {\n  true\n}\n' > "$repo/.agents/tests/test-alpha/a.bats"
  printf '# Beta\n- R1: a\n' > "$repo/.agents/tests/test-beta/requirements.md"
  printf '@test "R1: first" {\n  true\n}\n' > "$repo/.agents/tests/test-beta/b.bats"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  alpha="$(row_boxes "$BATS_TEST_TMPDIR/d.html" coverage alpha)"
  [ "$(printf '%s\n' "$alpha" | cut -f1,2 | tr '\t' ' ' | paste -sd, -)" = "R1 tested,R2 untested,R3 untested" ]
  [ -n "$(printf '%s\n' "$alpha" | sed -n 1p | cut -f3)" ]
  [ -z "$(printf '%s\n' "$alpha" | sed -n 2p | cut -f3)" ]
  [ "$(row_boxes "$BATS_TEST_TMPDIR/d.html" coverage beta | cut -f1,2 | tr '\t' ' ')" = "R1 tested" ]
  [[ "$(row_boxes "$BATS_TEST_TMPDIR/d.html" coverage alpha text)" =~ ^(test-)?alpha\ 2$ ]]
  [[ "$(row_boxes "$BATS_TEST_TMPDIR/d.html" coverage beta text)" =~ ^(test-)?beta\ 1$ ]]
  t="$(text "$BATS_TEST_TMPDIR/d.html")"
  [[ "$t" =~ alpha.*beta ]]
}

@test "R109: the checks and coverage sections show how long their latest run took" {
  check_result alpha pass
  mkdir -p "$repo/.agents/tests/test-alpha"
  printf '# Alpha\n- R1: a\n' > "$repo/.agents/tests/test-alpha/requirements.md"
  verdict duration checks 7
  verdict duration tests 5
  verdict duration checks 3
  verdict duration tests 84
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const end = (name) => html.indexOf("</table>", html.search(new RegExp(`<table[^>]*data-table="${name}"`)))
const runs = [...html.matchAll(/last run\s+([^<]*?)\s*</g)].map((m) => [m.index, m[1]])
const at = (time) => (runs.find((r) => r[1] === time) ?? [-1])[0]
console.log(runs.length === 2 && at("1.4 min") >= 0 && at("1.4 min") < end("coverage") && at("3.0 s") > end("coverage") && at("3.0 s") < end("checks"))' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}

@test "R109: without duration records no last run is shown" {
  check_result alpha pass
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  [[ "$(text "$BATS_TEST_TMPDIR/d.html")" != *"last run"* ]]
}

@test "R110: the coverage section comes before the checks section" {
  check_result alpha pass
  mkdir -p "$repo/.agents/tests/test-alpha"
  printf '# Alpha\n- R1: a\n' > "$repo/.agents/tests/test-alpha/requirements.md"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const coverage = html.search(/<table[^>]*data-table="coverage"/)
const checks = html.search(/<table[^>]*data-table="checks"/)
console.log(coverage >= 0 && checks > coverage)' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}

@test "R81: the scout section shows each section with its last checked date and its items, linked to their URLs in a new tab" {
  mkdir -p "$repo/.agents"
  printf '## latest-news\nlast checked: 2026-10-13\n- 2026-10-12 some <b>item</b> | consider | the reason | https://example.com/item\n\n## agent-skills\nlast checked: 2026-10-01\n' > "$repo/.agents/scout.md"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  t="$(text "$BATS_TEST_TMPDIR/d.html")"
  for want in latest-news 2026-10-13 agent-skills 2026-10-01 2026-10-12 'some <b>item</b>' consider 'the reason'; do
    [[ "$t" == *"$want"* ]] || { echo "missing: $want"; return 1; }
  done
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const link = html.match(/<a\b[^>]*href="https:\/\/example\.com\/item"[^>]*>/)?.[0] ?? ""
console.log(/target="_blank"/.test(link))' "$BATS_TEST_TMPDIR/d.html"
  [ "$output" = true ]
}

@test "R81: shows no scout section without scout.md" {
  adapter claude "$(record claude 0 null '{}' '{}' '[]' "$zero" "$zero" 0 '{}')"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  run ! grep -qiE 'last checked' "$BATS_TEST_TMPDIR/d.html"
}

