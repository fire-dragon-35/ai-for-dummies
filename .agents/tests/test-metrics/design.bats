bats_require_minimum_version 1.5.0

setup() {
  load helpers
  setup_metrics_repo
}

@test "R104: all table cells have the same font size and padding" {
  require_browser
  chart_data
  check_result alpha pass
  mkdir -p "$repo/.agents/tests/test-alpha"
  printf '# Alpha\n- R1: a\n' > "$repo/.agents/tests/test-alpha/requirements.md"
  adapter codex "$(record codex 0 null '{"Bash":1}' '{}' '[]' "$zero" "$zero" 0 '{}')"
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  cells="$(measure '[...new Set([...document.querySelectorAll("td, th")].map((c) => { const s = getComputedStyle(c); return [c.closest("table").dataset.table, s.fontSize, s.padding].join(" ") }))]')"
  run node -e '
const cells = JSON.parse(process.argv[1])
const tables = new Set(cells.map((c) => c.split(" ")[0]))
console.log(tables.size >= 3 && new Set(cells.map((c) => c.split(" ").slice(1).join(" "))).size === 1)' "$cells"
  [ "$output" = true ]
}

@test "R105: the dashboard ends with a footer naming AI for dummies and linking the repository in a new tab" {
  for records in no yes; do
    [ "$records" = no ] || two_agents
    report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
    run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const footer = html.match(/<footer[\s\S]*?<\/footer>/)?.[0] ?? ""
const link = footer.match(/<a\b[^>]*href="https:\/\/github\.com\/fire-dragon-35\/ai-for-dummies"[^>]*>/)?.[0] ?? ""
const rest = html.slice(html.indexOf(footer) + footer.length).replace(/<script>[\s\S]*?<\/script>/g, "").replace(/<\/(body|html)>/g, "").trim()
console.log(footer.includes("AI for dummies 😵‍💫") && /target="_blank"/.test(link) && rest === "")' "$BATS_TEST_TMPDIR/d.html"
    [ "$output" = true ] || { echo "$records"; return 1; }
  done
}

@test "R105: the footer is centered on the page" {
  require_browser
  two_agents
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  run node -e '
const [left, right, page] = JSON.parse(process.argv[1])
console.log(left > 20 && right > 20 && Math.abs((left + (page - right)) / 2 - page / 2) < 4)' "$(measure '(() => { const range = document.createRange(); range.selectNodeContents(document.querySelector("footer")); const r = range.getBoundingClientRect(); return [r.left, document.documentElement.clientWidth - r.right, document.documentElement.clientWidth] })()')"
  [ "$output" = true ]
}

@test "R107: all text uses the system font and the dashboard defines no web fonts" {
  require_browser
  two_agents
  report --html "$BATS_TEST_TMPDIR/d.html" > /dev/null
  run node -e '
const html = require("fs").readFileSync(process.argv[1], "utf8")
const stacks = JSON.parse(process.argv[2])
console.log(stacks.length > 0 && stacks.every((stack) => /^\s*(system-ui|-apple-system|BlinkMacSystemFont)\b/i.test(stack)) && !/@font-face/i.test(html))' "$BATS_TEST_TMPDIR/d.html" "$(measure '[...new Set([...document.body.querySelectorAll("*")].filter((e) => [...e.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim())).map((e) => getComputedStyle(e).fontFamily))]')"
  [ "$output" = true ]
}
