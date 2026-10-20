bats_require_minimum_version 1.5.0

setup_file() {
  mkdir -p "$BATS_FILE_TMPDIR/my repo.v1/sub"
  prepared_repo="$(cd "$BATS_FILE_TMPDIR/my repo.v1" && pwd -P)"
  cp -r "$BATS_TEST_DIRNAME/fixtures/projects" "$BATS_FILE_TMPDIR/projects"
  find "$BATS_FILE_TMPDIR/projects" -type f -exec sed -i "s|__REPO__|$prepared_repo|g" {} +
}

setup() {
  adapter="$BATS_TEST_DIRNAME/../../metrics/adapters/claude.mjs"
  repo="$(cd "$BATS_FILE_TMPDIR/my repo.v1" && pwd -P)"
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/claude"
  mkdir -p "$CLAUDE_CONFIG_DIR"
  cp -r "$BATS_FILE_TMPDIR/projects" "$CLAUDE_CONFIG_DIR/projects"
  human_prompts=p3,p1,p2,p4
  cd "$repo" || return 1
}

q() {
  node "$BATS_TEST_DIRNAME/query.mjs" "$@"
}

adapt() {
  "$adapter" "$@"
}

record() {
  printf '%s\n' "$output" | q "x.prompt === \"$1\" ? x : undefined"
}

field() {
  record "$1" | q "$2"
}

prompts() {
  printf '%s\n' "$output" | q 'x.prompt' | paste -sd, -
}

sums() {
  field "$1" "[x.$2.input, x.$2.output, x.$2.cache_read, x.$2.cache_write].join(' ')"
}

@test "R30: prints one JSON line per human prompt and exits with status 0" {
  run --separate-stderr adapt
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l)" -eq "$(printf '%s\n' "$human_prompts" | tr ',' '\n' | wc -l)" ]
  printf '%s\n' "$output" | q 'x' > /dev/null
}

@test "R31: every record has exactly the documented fields" {
  run adapt
  [ "$(field p1 'Object.keys(x).sort()')" = '["active_ms","agent","commands","mcp_servers","models","prompt","session","start","subagent_tokens","subagents","tokens","tools","wall_ms"]' ]
  [ "$(field p4 'Object.keys(x).sort()')" = "$(field p1 'Object.keys(x).sort()')" ]
}

@test "R31: agent, session and start come from the entries" {
  run adapt
  [ "$(field p1 '[x.agent, x.session, x.start]')" = '["claude","s1","2026-10-16T10:00:00.000Z"]' ]
  [ "$(field p3 'x.session')" = s2 ]
}

@test "R32: sums distinct messages and ignores entries before the first prompt" {
  run adapt
  [ "$(sums p1 tokens)" = "36 360 3600 80" ]
}

@test "R32: counts a message without usage as zero" {
  run adapt
  [ "$(sums p2 tokens)" = "3 30 300 15" ]
}

@test "R33: wall_ms runs to the last assistant entry of the prompt" {
  run adapt
  [ "$(field p1 'x.wall_ms')" = "35000" ]
  [ "$(field p2 'x.wall_ms')" = "12250" ]
}

@test "R34: active_ms sums the turn durations of the prompt" {
  run adapt
  [ "$(field p1 'x.active_ms')" = "19000" ]
  [ "$(field p3 'x.active_ms')" = "4000" ]
}

@test "R34: active_ms is null without a turn duration" {
  run adapt
  [ "$(field p2 'x.active_ms')" = "null" ]
}

@test "R35: counts tool calls by name" {
  run adapt
  [ "$(field p1 'Object.entries(x.tools).sort()')" = '[["Agent",1],["Bash",1],["mcp__chrome__navigate",1]]' ]
  [ "$(field p2 'Object.keys(x.tools).length')" = 0 ]
}

@test "R36: counts MCP tool calls by server" {
  run adapt
  [ "$(field p1 'x.mcp_servers')" = '{"chrome":1}' ]
  [ "$(field p2 'Object.keys(x.mcp_servers).length')" = 0 ]
}

@test "R37: lists the commands of the human prompt" {
  run adapt
  [ "$(field p2 'x.commands')" = '["/scout"]' ]
  [ "$(field p1 'x.commands')" = '[]' ]
}

@test "R38: attributes subagents to the prompt that launched them" {
  run adapt
  [ "$(field p1 'x.subagents')" = "1" ]
  [ "$(sums p1 subagent_tokens)" = "8 71 701 36" ]
}

@test "R38: a prompt without subagents has zero subagent tokens" {
  run adapt
  [ "$(field p2 'x.subagents')" = "0" ]
  [ "$(sums p2 subagent_tokens)" = "0 0 0 0" ]
}

@test "R39: peer messages and local commands start no prompt" {
  run adapt
  [ "$status" -eq 0 ]
  [[ ",$(prompts)," != *,px,* ]]
  [[ ",$(prompts)," != *,p8,* ]]
  [ "$(prompts)" = "$human_prompts" ]
}

@test "R39: replies after a peer message belong to the running prompt" {
  run adapt
  [ "$(field p1 'x.tokens.input')" = "36" ]
  [ "$(field p1 'x.wall_ms')" = "35000" ]
}

@test "R40: orders records by start across session files" {
  run adapt
  [ "$(prompts)" = "$human_prompts" ]
}

@test "R41: prints none of the text of the sessions" {
  run adapt
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [[ "$output" != *SECRET* ]]
  [[ "$output" != *"prompt from"* ]]
  [[ "$output" != *reply* ]]
}

@test "R42: reads sessions from subdirectories and skips other directories" {
  run adapt
  [ -n "$(record p4)" ]
  [ -z "$(record p5)" ]
  [ -z "$(record p6)" ]
}

@test "R43: reads ~/.claude when CLAUDE_CONFIG_DIR is not set" {
  mkdir -p "$BATS_TEST_TMPDIR/home/.claude"
  mv "$CLAUDE_CONFIG_DIR/projects" "$BATS_TEST_TMPDIR/home/.claude/projects"
  run env -u CLAUDE_CONFIG_DIR HOME="$BATS_TEST_TMPDIR/home" "$adapter"
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "$human_prompts" ]
}

@test "R44: prints nothing without a projects directory" {
  run --separate-stderr env CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/empty" "$adapter"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "R44: prints nothing when no project folder matches" {
  mkdir -p "$BATS_TEST_TMPDIR/other repo"
  run --separate-stderr adapt "$BATS_TEST_TMPDIR/other repo"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "R45: prints no record for a session without a human prompt" {
  run adapt
  [ "$status" -eq 0 ]
  [ -n "$(record p1)" ]
  [ -z "$(printf '%s\n' "$output" | q 'x.session === "s3" ? x : undefined')" ]
}

@test "R46: ignores a line that is not valid JSON" {
  sed '3i\
{this is not json' "$CLAUDE_CONFIG_DIR/projects/proj-a/s1.jsonl" > "$BATS_TEST_TMPDIR/s1.jsonl"
  mv "$BATS_TEST_TMPDIR/s1.jsonl" "$CLAUDE_CONFIG_DIR/projects/proj-a/s1.jsonl"
  run adapt
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "$human_prompts" ]
  [ "$(field p1 'x.tokens.output')" = "360" ]
}

@test "R46: copes with a truncated last line" {
  run adapt
  [ "$status" -eq 0 ]
  [ "$(field p2 'x.tokens.output')" = "30" ]
  [ "$(field p2 'x.wall_ms')" = "12250" ]
}

@test "R47: uses an absolute repository argument" {
  cd "$BATS_TEST_TMPDIR" || return 1
  run adapt "$repo"
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "$human_prompts" ]
}

@test "R47: uses a relative repository argument" {
  cd "$(dirname "$repo")" || return 1
  run adapt "my repo.v1"
  [ "$status" -eq 0 ]
  [ "$(prompts)" = "$human_prompts" ]
}

@test "R48: sums tokens per model over the prompt and its subagents" {
  run adapt
  [ "$(field p1 'x.models["claude-a"]')" = '{"input":37,"output":370,"cache_read":3700,"cache_write":85}' ]
  [ "$(field p1 'x.models["claude-b"]')" = '{"input":7,"output":61,"cache_read":601,"cache_write":31}' ]
  [ "$(field p1 'Object.keys(x.models).sort().join(",")')" = "claude-a,claude-b" ]
}

@test "R48: the model sums add up to the tokens and the subagent tokens" {
  run adapt
  [ "$(field p1 'Object.values(x.models).reduce((n, m) => n + m.input + m.output + m.cache_read + m.cache_write, 0)')" = "$(field p1 'Object.values(x.tokens).concat(Object.values(x.subagent_tokens)).reduce((n, v) => n + v, 0)')" ]
}

@test "R49: counts a message without a model under unknown" {
  run adapt
  [ "$(field p2 'x.models.unknown.output')" = "30" ]
}

@test "R50: lists no model whose sums are all zero" {
  run adapt
  [ "$(field p2 'Object.keys(x.models).join(",")')" = "unknown" ]
}
