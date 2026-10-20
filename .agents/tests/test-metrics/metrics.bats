bats_require_minimum_version 1.5.0

setup() {
  load helpers
  setup_metrics_repo
}

line() {
  printf '%s\n' "$output" | grep -E "^$1( |$)"
}

cost() {
  line cost | sed -E 's/^cost +\$([0-9]+\.[0-9]).*$/\1/'
}

models() {
  adapter claude "$(record claude 1000 null '{}' '{}' '[]' "$zero" "$zero" 0 "$1")"
}

@test "R1: prints prompts, times, tokens and subagents" {
  two_agents
  run --separate-stderr report
  [ "$status" -eq 0 ]
  [[ "$(line prompts)" =~ ^prompts\ +3\ \(.*claude\ 2.*\)$ ]]
  [[ "$(line prompts)" == *"codex 1"* ]]
  [[ "$(line wall)" =~ ^wall\ +1\.5\ min$ ]]
  [[ "$(line active)" =~ ^active\ +30\.0\ s$ ]]
  [[ "$(line tokens)" =~ ^tokens\ +input\ 11,\ output\ 22,\ cache\ read\ 33,\ cache\ write\ 44$ ]]
  [[ "$(line subagents)" =~ ^subagents\ +3$ ]]
}

@test "R2: prints the five most used tools, servers and commands" {
  two_agents
  run report
  [[ "$(line tools)" =~ ^tools\ +Bash\ 5,\ Read\ 3,\ Edit\ 1,\ Glob\ 1,\ Grep\ 1$ ]]
  [[ "$(line 'mcp servers')" =~ ^mcp\ servers\ +chrome\ 2$ ]]
  [[ "$(line commands)" =~ ^commands\ +/scout\ 2,\ /context\ 1$ ]]
  adapter claude "$(record claude 0 null '{}' '{}' '[]' "$zero" "$zero" 0 '{}')"
  rm "$repo/.agents/metrics/adapters/codex"
  run report
  [ -z "$(line tools)$(line 'mcp servers')$(line commands)" ]
}

@test "R3: prints checks, test totals and the most failing tests" {
  check_result shellcheck pass
  check_result shellcheck fail
  check_result "line limit" pass
  verdict test "R1: a" pass
  verdict test "R2: b" fail
  verdict test "R2: b" fail
  verdict test "R3: c" fail
  verdict test "R4: d" skip
  run report
  [[ "$(line shellcheck)" =~ ^shellcheck\ +1\ pass,\ 1\ fail$ ]]
  [[ "$(line 'line limit')" =~ ^line\ limit\ +1\ pass,\ 0\ fail$ ]]
  [[ "$(line tests)" =~ ^tests\ +1\ pass,\ 3\ fail,\ 1\ skip$ ]]
  [[ "$(line failing)" =~ ^failing\ +R2:\ b\ 2,\ R3:\ c\ 1$ ]]
}

@test "R4: prints no metrics yet without records" {
  run --separate-stderr report
  [ "$status" -eq 0 ]
  [ "$output" = "no metrics yet" ]
}

@test "R5: names a failing adapter and reports the rest" {
  two_agents
  printf '%s\n' '#!/bin/sh' 'echo "adapter broke" >&2' 'exit 3' > "$repo/.agents/metrics/adapters/broken"
  chmod +x "$repo/.agents/metrics/adapters/broken"
  run --separate-stderr report
  [ "$status" -eq 0 ]
  [[ "$stderr" == *broken*"adapter broke"* ]]
  [[ "$(line prompts)" =~ ^prompts\ +3 ]]
}

@test "R6: uses a relative or absolute repository argument" {
  printf '%s\n' '#!/bin/sh' 'cd "$1" && pwd -P > "$(dirname "$0")/../seen"' > "$repo/.agents/metrics/adapters/probe"
  chmod +x "$repo/.agents/metrics/adapters/probe"
  check_result shellcheck pass
  cd "$BATS_TEST_TMPDIR" || return 1
  run report "my repo"
  [ "$(cat "$repo/.agents/metrics/seen")" = "$(cd "$repo" && pwd -P)" ]
  [ -n "$(line shellcheck)" ]
  rm "$repo/.agents/metrics/seen"
  run report "$repo"
  [ "$(cat "$repo/.agents/metrics/seen")" = "$(cd "$repo" && pwd -P)" ]
  [ -n "$(line shellcheck)" ]
}

@test "R7: prints no text of the records" {
  adapter claude "$(record claude 0 null '{}' '{}' '[]' "$zero" "$zero" 0 '{}' | sed 's/}$/,"text":"SECRET"}/; s/"prompt":"p"/"prompt":"SECRET2"/')"
  run report
  [ "$status" -eq 0 ]
  [[ "$output" != *SECRET* ]]
}

@test "R73: writes times below a minute in seconds" {
  adapter claude "$(record claude 45000 60000 '{}' '{}' '[]' "$zero" "$zero" 0 '{}')"
  run report
  [[ "$(line wall)" =~ ^wall\ +45\.0\ s$ ]]
  [[ "$(line active)" =~ ^active\ +1\.0\ min$ ]]
}

@test "R8: prices every token type of every model" {
  with_prices
  adapter claude "$(record claude 0 null '{}' '{}' '[]' "$zero" "$zero" 0 "{\"claude-a\":$million}"
    record claude 0 null '{}' '{}' '[]' "$zero" "$zero" 0 "{\"claude-a\":$million,\"claude-b\":$million}")"
  run report
  [ "$(cost)" = "18.4" ]
}

@test "R9: matches a dated model id and ignores other providers" {
  with_prices
  models '{"claude-a-20250101":{"input":1000000,"output":0,"cache_read":0,"cache_write":0},"anthropic.claude-z":{"input":1000000,"output":0,"cache_read":0,"cache_write":0}}'
  run report
  [ "$(cost)" = "1.0" ]
  [[ "$(line unpriced)" == *anthropic.claude-z* ]]
}

@test "R10: lists unpriced models and leaves them out of the cost" {
  with_prices
  models "{\"claude-a\":$million,\"zeta\":$million,\"claude-c\":{\"input\":1000000,\"output\":0,\"cache_read\":1,\"cache_write\":0}}"
  run report
  [ "$(cost)" = "4.6" ]
  [[ "$(line unpriced)" =~ ^unpriced\ +claude-c,\ zeta$ ]]
}

@test "R11: says unavailable without price data" {
  models "{\"claude-a\":$million}"
  run --separate-stderr report
  [ "$status" -eq 0 ]
  [[ "$(line cost)" == *unavailable* ]]
  [[ "$(line cost)" != *'$'* ]]
}

@test "R12: stores the prices, keeps a cache younger than 7 days and refreshes an older one" {
  with_prices
  models "{\"claude-a\":$million}"
  run report
  [ -s "$cache" ]
  sed -i 's/"input_cost_per_token": 1e-6/"input_cost_per_token": 5e-6/' "$BATS_TEST_TMPDIR/prices.json"
  age_cache 6
  run report
  [ "$(cost)" = "4.6" ]
  age_cache 7
  run report
  [ "$(cost)" = "8.6" ]
}

@test "R13: keeps an old cache when the fetch fails or has no anthropic entry" {
  with_prices
  models "{\"claude-a\":$million}"
  run report
  age_cache 30
  printf '%s\n' '{"x": {"litellm_provider": "bedrock"}}' > "$BATS_TEST_TMPDIR/prices.json"
  run --separate-stderr report
  [ "$(cost)" = "4.6" ]
  prices_file "$BATS_TEST_TMPDIR/prices.json"
  sed -i 's/"input_cost_per_token": 1e-6/"input_cost_per_token": 5e-6/' "$BATS_TEST_TMPDIR/prices.json"
  run --separate-stderr report
  [ "$(cost)" = "4.6" ]
}

@test "R13: does not fetch again within an hour of a failure" {
  models "{\"claude-a\":$million}"
  run --separate-stderr report
  [[ "$(line cost)" == *unavailable* ]]
  with_prices
  run --separate-stderr report
  [[ "$(line cost)" == *unavailable* ]]
}

@test "R14: prints the minimum energy in Wh and kWh" {
  with_models
  adapter claude "$(output_of claude-haiku-4-5-20251001=1000000)"
  run report
  [[ "$(line energy)" =~ ^energy\ +about\ 59\.4\ Wh\ \(minimum\ estimate\)$ ]]
  adapter claude "$(output_of claude-opus-4-6=1000000)"
  run report
  [[ "$(line energy)" =~ ^energy\ +about\ 3\.4\ kWh\ \(minimum\ estimate\)$ ]]
}

@test "R92: the energy sums the output tokens of every model and counts no other token" {
  with_models
  adapter claude "$(output_of claude-haiku-4-5-20251001=1000000 claude-opus-4-6=1000000
    record claude 0 null '{}' '{}' '[]' "$million" "$million" 0 '{"claude-haiku-4-5-20251001":{"input":1000000,"output":0,"cache_read":1000000,"cache_write":1000000}}')"
  run report
  [[ "$(line energy)" =~ about\ 3\.5\ kWh ]]
  adapter claude "$(record claude 0 null '{}' '{}' '[]' "$zero" "$zero" 0 '{"claude-opus-4-6":{"input":1000000,"output":0,"cache_read":1000000,"cache_write":1000000}}')"
  run report
  [[ "$(line energy)" =~ about\ 0\.0\ Wh ]]
}

@test "R93: finds a model by its id, by an alias or without a trailing date" {
  with_models
  for id in claude-haiku-4-5-20251001 claude-haiku-4-5; do
    adapter claude "$(output_of "$id=1000000")"
    run report
    [[ "$(line energy)" =~ about\ 59\.4\ Wh ]] || { echo "$id"; return 1; }
  done
  adapter claude "$(output_of claude-opus-4-6-20260101=1000000)"
  run report
  [[ "$(line energy)" =~ about\ 3\.4\ kWh ]]
}

@test "R94: lists models without an entry as unmodelled and leaves them out of the energy" {
  with_models
  adapter claude "$(output_of claude-haiku-4-5-20251001=1000000 claude-zzz=1000000 gpt-x=1000000)"
  run report
  [[ "$(line energy)" =~ about\ 59\.4\ Wh ]]
  [[ "$(line unmodelled)" =~ ^unmodelled\ +claude-zzz,\ gpt-x$ ]]
}

@test "R95: reads the model data from its source and stores it" {
  with_models
  adapter claude "$(output_of claude-haiku-4-5-20251001=1000000)"
  run report
  [[ "$(line energy)" =~ about\ 59\.4\ Wh ]]
  [ -s "$models_cache" ]
}

@test "R98: reuses a young store, refreshes an older one and keeps it when the fetch fails" {
  with_models
  adapter claude "$(output_of claude-haiku-4-5-20251001=1000000)"
  run report
  sed -i 's/"min": 10, "max": 35/"min": 100, "max": 350/' "$BATS_TEST_TMPDIR/models.json"
  age_cache 6 "$models_cache"
  run report
  [[ "$(line energy)" =~ about\ 59\.4\ Wh ]]
  age_cache 7 "$models_cache"
  run report
  [[ "$(line energy)" =~ about ]]
  [[ ! "$(line energy)" =~ about\ 59\.4\ Wh ]]
  export AI_FOR_DUMMIES_MODELS_URL="file://$BATS_TEST_TMPDIR/gone.json"
  age_cache 30 "$models_cache"
  run report
  [[ "$(line energy)" =~ about ]]
  [[ "$(line energy)" != *unavailable* ]]
}

@test "R97: says unavailable without model data" {
  adapter claude "$(output_of claude-haiku-4-5-20251001=1000000)"
  run report
  [[ "$(line energy)" =~ ^energy\ +unavailable ]]
}

@test "R29: the skill names the report and the dashboard command" {
  skill="$source_root/.agents/skills/metrics/SKILL.md"
  grep -qF 'node .agents/metrics/metrics.mjs' "$skill"
  grep -qF 'node .agents/metrics/metrics.mjs --html' "$skill"
}
