bats_require_minimum_version 1.5.0

setup() {
  benchmark="$BATS_TEST_DIRNAME/../../skills/benchmark/run.sh"
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/claude"
  export TMPDIR="$BATS_TEST_TMPDIR"
  export AI_FOR_DUMMIES_PRICES_URL="file://$BATS_TEST_TMPDIR/no-prices.json"
  export AI_FOR_DUMMIES_MODELS_URL="file://$BATS_TEST_TMPDIR/no-models.json"
  export MARKERS="$BATS_TEST_TMPDIR/markers"
  mkdir -p "$MARKERS"
  fake="$BATS_TEST_TMPDIR/fake-claude"
  cat > "$fake" <<'FAKE'
#!/bin/sh
[ "$1" = -p ] || exit 9
prompt=$2
dir=$(pwd -P)
if [ ! -d .git ]; then
  for setup in AGENTS.md CLAUDE.md .agents .claude node_modules; do [ ! -e "$setup" ] || exit 8; done
  pwd -P >> "$MARKERS/reviewed"
  score=21 other=43
  [ "$(wc -l < app.txt)" -eq 5 ] && score=61 other=83
  printf '{"type":"result","result":"Scores:\\n{\\"structure\\":{\\"score\\":%s,\\"note\\":\\"note %s\\"},\\"security\\":{\\"score\\":%s,\\"note\\":\\"fine\\"}}"}\n' "$other" "$other" "$score"
  exit 0
fi
side=without lines=3 first=33 later=13
[ -e AGENTS.md ] && side=with lines=5 first=55 later=15
output=$later
mkdir "$MARKERS/$side" 2>/dev/null && output=$first
folder="$CLAUDE_CONFIG_DIR/projects/$(printf '%s' "$dir" | tr -c 'a-zA-Z0-9\n' -)"
mkdir -p "$folder"
node -e '
const [dir, prompt, output] = process.argv.slice(1)
const entry = (type, time, extra) => JSON.stringify({ type, timestamp: time, cwd: dir, entrypoint: "sdk-cli", ...extra })
console.log(entry("user", "2026-10-20T10:00:00.000Z", { promptId: "p", message: { role: "user", content: prompt } }))
console.log(entry("assistant", "2026-10-20T10:00:30.000Z", { message: { id: "m", model: "claude-x", usage: { input_tokens: 1, output_tokens: Number(output), cache_read_input_tokens: 7, cache_creation_input_tokens: 2 }, content: [] } }))
' "$dir" "$prompt" "$output" > "$folder/s.jsonl"
seq "$lines" > app.txt
mkdir -p node_modules && seq 50 > node_modules/dep.js
[ -n "$FAKE_CODE" ] || exit 0
mkdir -p test && printf 'const unused = 1\nif (a == 1) b()\n' > test/app.test.js
if [ "$side" = with ]; then
  printf 'export const add = (a, b) => a + b\n' > app.js
else
  block='export function total%s(items) {\n  let sum = 0\n  let count = 0\n  for (const item of items) {\n    if (item.quantity == 0) continue\n    sum += item.price * item.quantity\n    count += item.quantity\n  }\n  console.log("total", sum, "count", count)\n  return { sum, count }\n}\n'
  printf "$block$block" A B > app.js
fi
FAKE
  chmod +x "$fake"
}

bench() {
  sh "$benchmark" "$@"
}

row() {
  printf '%s\n' "$output" | grep -E "^$1( |$)"
}

runs_dir() {
  for path in $(printf '%s\n' "$output" | grep -oE '/[^ ]+'); do
    [ -d "$path/with-1" ] && { printf '%s\n' "$path"; return 0; }
  done
  return 1
}

has() {
  [[ "$1" =~ (^|[^0-9.])$2(\.0+)?([^0-9.]|$) ]]
}

@test "R1: makes n runs per side, each a committed repository, and runs the agent command in each" {
  run --separate-stderr bench --runs 2 --prompt "make a thing" --claude "$fake"
  [ "$status" -eq 0 ]
  dir=$(runs_dir)
  for run in with-1 with-2 without-1 without-2; do
    [ "$(git -C "$dir/$run" rev-list --count HEAD)" -eq 1 ]
    [ -e "$dir/$run/app.txt" ]
    grep -rqF '"make a thing"' "$CLAUDE_CONFIG_DIR/projects/$(cd "$dir/$run" && pwd -P | tr -c 'a-zA-Z0-9\n' -)"
  done
  [ -e "$dir/with-1/AGENTS.md" ]
  [ -e "$dir/with-2/.agents/hooks/qa.sh" ]
  [ ! -e "$dir/without-1/AGENTS.md" ]
  [ ! -e "$dir/without-2/.agents" ]
  [ ! -e "$dir/with-3" ]
}

@test "R2: makes 3 runs per side with a default prompt and the agent command claude" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cp "$fake" "$BATS_TEST_TMPDIR/bin/claude"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run --separate-stderr bench
  [ "$status" -eq 0 ]
  for run in with-1 with-2 with-3 without-1 without-2 without-3; do [ -n "$(row "$run")" ]; done
  [ -z "$(row with-4)" ]
  [ "$(find "$CLAUDE_CONFIG_DIR/projects" -name s.jsonl | wc -l)" -eq 6 ]
}

@test "R3: prints each run's output tokens, cache tokens, wall time and lines written" {
  run --separate-stderr bench --runs 1 --claude "$fake"
  [ "$status" -eq 0 ]
  with=$(row with-1)
  without=$(row without-1)
  has "$with" 55
  has "$with" 7
  has "$with" 2
  [[ "$with" =~ 30\.0\ ?s ]]
  has "$with" 5
  has "$without" 33
  has "$without" 3
}

@test "R3: prints the cost when price data is available" {
  printf '{"claude-x":{"litellm_provider":"anthropic","input_cost_per_token":0,"output_cost_per_token":1,"cache_read_input_token_cost":0,"cache_creation_input_token_cost":0}}' > "$BATS_TEST_TMPDIR/prices.json"
  AI_FOR_DUMMIES_PRICES_URL="file://$BATS_TEST_TMPDIR/prices.json" run --separate-stderr bench --runs 1 --claude "$fake"
  [ "$status" -eq 0 ]
  [[ "$(row with-1)" =~ \$55(\.0+)?([^0-9.]|$) ]]
  [[ "$(row without-1)" =~ \$33(\.0+)?([^0-9.]|$) ]]
}

@test "R4: prints the average, lowest and highest per side" {
  run --separate-stderr bench --runs 2 --claude "$fake"
  [ "$status" -eq 0 ]
  with=$(row with)
  without=$(row without)
  has "$with" 35
  has "$with" 15
  has "$with" 55
  has "$without" 23
  has "$without" 13
  has "$without" 33
}

@test "R5: prints the directory that holds the runs" {
  run --separate-stderr bench --runs 1 --claude "$fake"
  [ "$status" -eq 0 ]
  dir=$(runs_dir)
  [ -d "$dir/without-1" ]
}

@test "R6: rejects unknown options and bad run counts without running the agent" {
  for args in "--bogus" "--runs 0" "--runs x" "--runs 1.5" "--runs -1"; do
    run --separate-stderr bench $args --claude "$fake"
    [ "$status" -eq 2 ] || { echo "$args"; return 1; }
    [[ "${stderr,,}" == *usage* ]]
  done
  [ ! -d "$CLAUDE_CONFIG_DIR/projects" ]
}

@test "R7: gives every run the prompt of the task" {
  run --separate-stderr bench --task "$BATS_TEST_DIRNAME/fixtures/task" --runs 1 --claude "$fake"
  [ "$status" -eq 0 ]
  [ "$(grep -rlF 'Build the thing from the task.' "$CLAUDE_CONFIG_DIR/projects" | wc -l)" -eq 2 ]
}

@test "R2: uses the prompt of the todo task without --task" {
  run --separate-stderr bench --runs 1 --claude "$fake"
  [ "$status" -eq 0 ]
  prompt=$(head -n 1 "$BATS_TEST_DIRNAME/../../skills/benchmark/tasks/todo/prompt.md")
  [ "$(grep -rlF "$prompt" "$CLAUDE_CONFIG_DIR/projects" | wc -l)" -eq 2 ]
}

@test "R8: rejects a missing task or a task without a prompt" {
  mkdir -p "$BATS_TEST_TMPDIR/empty"
  for task in no-such-task "$BATS_TEST_TMPDIR/empty"; do
    run --separate-stderr bench --task "$task" --runs 1 --claude "$fake"
    [ "$status" -eq 2 ] || { echo "$task"; return 1; }
    [ -n "$stderr" ]
  done
  [ ! -d "$CLAUDE_CONFIG_DIR/projects" ]
}

@test "R8: accepts a task without a prompt when --prompt is given" {
  mkdir -p "$BATS_TEST_TMPDIR/empty"
  run --separate-stderr bench --task "$BATS_TEST_TMPDIR/empty" --prompt "make a thing" --runs 1 --claude "$fake"
  [ "$status" -eq 0 ]
  [ -n "$(row with-1)" ]
}

@test "R9: shows the share of passed acceptance checks" {
  run --separate-stderr bench --task "$BATS_TEST_DIRNAME/fixtures/quality" --runs 1 --claude "$fake"
  [ "$status" -eq 0 ]
  [[ "$(row with-1)" =~ (^|[^0-9.])75(\.0+)?\ ?% ]]
  [[ "$(row without-1)" =~ (^|[^0-9.])25(\.0+)?\ ?% ]]
  [[ "$(row with)" =~ (^|[^0-9.])75(\.0+)?\ ?% ]]
  [[ "$(row without)" =~ (^|[^0-9.])25(\.0+)?\ ?% ]]
}

@test "R13: writes the failed acceptance checks of every run" {
  run --separate-stderr bench --task "$BATS_TEST_DIRNAME/fixtures/quality" --runs 1 --claude "$fake"
  [ "$status" -eq 0 ]
  dir=$(runs_dir)
  grep -q 'missing title' "$dir/acceptance.md"
  grep -q 'edge case' "$dir/acceptance.md"
  grep -q 'with-1' "$dir/acceptance.md"
  grep -q 'without-1' "$dir/acceptance.md"
}

@test "R9: counts an acceptance script without a result as 0%" {
  task="$BATS_TEST_TMPDIR/silent"
  mkdir -p "$task"
  cp "$BATS_TEST_DIRNAME/fixtures/task/prompt.md" "$task/"
  printf 'console.log("crashed")\nprocess.exit(1)\n' > "$task/acceptance.mjs"
  run --separate-stderr bench --task "$task" --runs 1 --claude "$fake"
  [ "$status" -eq 0 ]
  [[ "$(row with-1)" =~ (^|[^0-9.])0(\.0+)?\ ?% ]]
}

@test "R10: reviews each run blind, without the setup files, and shows the average score" {
  run --separate-stderr bench --task "$BATS_TEST_DIRNAME/fixtures/quality" --runs 1 --claude "$fake"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$MARKERS/reviewed")" -eq 2 ]
  has "$(row with-1)" 72
  has "$(row without-1)" 32
  has "$(row with)" 72
  run ! grep -E 'with' "$MARKERS/reviewed"
}

@test "R14: writes the scores and notes of every review" {
  run --separate-stderr bench --task "$BATS_TEST_DIRNAME/fixtures/quality" --runs 1 --claude "$fake"
  [ "$status" -eq 0 ]
  dir=$(runs_dir)
  grep -q 'note 83' "$dir/review.md"
  grep -q 'note 43' "$dir/review.md"
}

@test "R11: shows lint problems per 1000 lines and duplication of the code files, without tests" {
  FAKE_CODE=1 run --separate-stderr bench --task "$BATS_TEST_DIRNAME/fixtures/quality" --runs 1 --claude "$fake"
  [ "$status" -eq 0 ]
  with=$(row with-1)
  without=$(row without-1)
  [[ "$with" =~ (^|[^0-9.])0(\.0+)?\ ?% ]]
  [[ "$without" =~ (^|[^0-9.])45\.5\ ?% ]]
  has "$without" 90.9
  has "$(row without)" 90.9
}

needs_browser() {
  command -v google-chrome > /dev/null || command -v chromium > /dev/null || skip "no browser"
}

webapp() {
  cp -r "$BATS_TEST_DIRNAME/fixtures/app" "$BATS_TEST_TMPDIR/app"
  node "$BATS_TEST_DIRNAME/../../skills/benchmark/tasks/webapp/acceptance.mjs" "$BATS_TEST_TMPDIR/app" | tail -n 1
}

@test "R12: the webapp acceptance script passes every check for a correct app" {
  needs_browser
  result=$(webapp)
  [ "$(printf '%s' "$result" | node -e 'const r = JSON.parse(require("fs").readFileSync(0, "utf8")); console.log(r.total > 0 && r.passed === r.total && r.failed.length === 0)')" = true ]
}

@test "R12: the webapp acceptance script passes every check when the temporary directory has a long path" {
  needs_browser
  long="$BATS_TEST_TMPDIR/a-temporary-directory-with-a-rather-long-name-like-the-ones-agents-get/and-one-more-level"
  mkdir -p "$long"
  result=$(TMPDIR="$long" webapp)
  [ "$(printf '%s' "$result" | node -e 'const r = JSON.parse(require("fs").readFileSync(0, "utf8")); console.log(r.total > 0 && r.passed === r.total && r.failed.length === 0)')" = true ]
}

@test "R12: the webapp acceptance script fails validation checks for an app without validation" {
  needs_browser
  result=$(BROKEN=1 webapp)
  [ "$(printf '%s' "$result" | node -e 'const r = JSON.parse(require("fs").readFileSync(0, "utf8")); console.log(r.passed < r.total && r.failed.length > 0)')" = true ]
}
