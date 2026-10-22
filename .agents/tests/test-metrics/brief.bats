bats_require_minimum_version 1.5.0

setup() {
  load helpers
  setup_metrics_repo
}

visible() {
  printf '%s' "$1" | node -e 'console.log([...require("fs").readFileSync(0, "utf8")].length)'
}

cells() {
  line "$1" | sed -E "s/^$1 +//" | awk '{ print $1 }'
}

nth() {
  printf '%s' "$1" | node -e 'console.log([...require("fs").readFileSync(0, "utf8")][Number(process.argv[1])])' "$2"
}

@test "R117: prints prompts and active time first, and no other usage figures" {
  two_agents
  check_result shellcheck pass
  run --separate-stderr report --brief
  [ "$status" -eq 0 ]
  [[ "$(sed -n 1p <<< "$output")" =~ ^usage\  ]]
  [[ "$(line usage)" =~ ^usage\ +3\ prompts.*30\.0\ s.*since\ 2026-10-16$ ]]
  [[ "$(line usage)" != *'$'* && "$(line usage)" != *Wh* && "$(line usage)" != *input* ]]
  [ -z "$(line tools)$(line prompts)$(line wall)$(line subagents)" ]
}

@test "R117: names the earliest UTC day of the usage records" {
  adapter claude "$(START=2026-10-14T23:30:00.000Z record claude 1000 1000 '{}' '{}' '[]' "$zero" "$zero" 0 '{}'
    START=2026-10-13T23:30:00.000Z record claude 1000 1000 '{}' '{}' '[]' "$zero" "$zero" 0 '{}')"
  TZ=Pacific/Kiritimati run report --brief
  [[ "$(line usage)" =~ since\ 2026-10-13$ ]]
}

@test "R118: prints every check with its mark and the detail of failed checks" {
  check_result shellcheck pass
  check_result "line limit" pass
  verdict check "line limit" fail "long.txt (401 lines)" .agents/hooks/qa.sh
  run report --brief
  [[ "$(line checks)" == *"✓ shellcheck"* && "$(line checks)" == *"✗ line limit"* ]]
  printf '%s\n' "$output" | grep -q 'line limit.*long.txt (401 lines)'
  [ "$(printf '%s\n' "$output" | grep -c 'shellcheck')" -eq 1 ]
}

@test "R119: prints the latest run of the tests as a bar with counts" {
  for n in 1 2 3 4 5 6 7 8; do verdict test "R$n: ok" pass 1; done
  verdict test "R9: bad" fail 1
  verdict test "R10: later" skip 1
  run report --brief
  [[ "$(line tests)" == *"8 pass"* && "$(line tests)" == *"1 fail"* && "$(line tests)" == *"1 skip"* ]]
  [ "$(visible "$(cells tests)")" -eq 20 ]
  [[ "$(cells tests)" == *█* && "$(cells tests)" == *▓* && "$(cells tests)" == *░* ]]
  printf '%s\n' "$output" | grep -q 'R9: bad'
  verdict test "R9: bad" pass 2
  run report --brief
  [[ "$(line tests)" == *"1 pass"* && "$(line tests)" != *fail* && "$(line tests)" != *skip* ]]
  [[ "$(cells tests)" != *▓* ]]
}

@test "R119: names the first three failing tests and counts the rest" {
  for n in 1 2 3 4 5; do verdict test "R$n: broken" fail 1; done
  run report --brief
  [ "$(printf '%s\n' "$output" | grep -c 'broken')" -eq 3 ]
  printf '%s\n' "$output" | grep -q 'and 2 more'
}

@test "R126: ends the checks and tests lines with the time of their latest run" {
  check_result shellcheck pass
  verdict test "R1: ok" pass 1
  run report --brief
  [[ ! "$(line checks)" =~ [0-9]\ (s|min|h)$ && ! "$(line tests)" =~ [0-9]\ (s|min|h)$ ]]
  verdict duration checks 9
  verdict duration checks 3
  verdict duration tests 90
  run report --brief
  [[ "$(line checks)" =~ shellcheck.*\ 3\.0\ s$ ]]
  [[ "$(line tests)" =~ 1\ pass.*\ 1\.5\ min$ ]]
}

@test "R121: prints how many backlog items there are" {
  check_result shellcheck pass
  printf '%s\n' '- first' '' '- second' > "$repo/.agents/backlog.md"
  run report --brief
  [[ "$(line backlog)" =~ ^backlog\ +2\ items$ ]]
  rm "$repo/.agents/backlog.md"
  run report --brief
  [ -z "$(line backlog)" ]
}

@test "R122: prints no metrics yet without records" {
  components
  run --separate-stderr report --brief
  [ "$status" -eq 0 ]
  [ "$output" = "no metrics yet" ]
}

@test "R123: shortens long lines to 100 visible characters" {
  check_result shellcheck pass
  verdict check "line limit" fail "$(printf 'x%.0s' $(seq 300))" .agents/hooks/qa.sh
  verdict test "R1: $(printf 'y%.0s' $(seq 300))" fail 1
  FORCE_COLOR=1 run report --brief
  while IFS= read -r text; do
    plain="$(printf '%s' "$text" | sed 's/\x1b\[[0-9;]*m//g')"
    [ "$(visible "$plain")" -le 100 ]
  done <<< "$output"
  [[ "$output" == *…* ]]
}

@test "R124: prints a block per day and the total for tokens, cost and energy" {
  usage_data
  run report --brief
  tokens="$(cells tokens)"
  [ "$(visible "$tokens")" -eq 3 ]
  [ "$(nth "$tokens" 0)" = █ ]
  [ "$(nth "$tokens" 1)" = ▁ ]
  [[ "$(nth "$tokens" 2)" =~ [▂▃▄▅▆▇] ]]
  [[ "$(line tokens)" =~ \ 9\.0M\ +in\ 44\.4%\ ·\ out\ \<1%\ ·\ cache\ read\ 55\.5%\ ·\ cache\ write\ \<1%$ ]]
  cost="$(cells cost)"
  [ "$(visible "$cost")" -eq 3 ]
  [ "$(nth "$cost" 2)" = █ ]
  [ "$(nth "$cost" 1)" = ▁ ]
  [[ "$(line cost)" =~ \ \$4\.0$ ]]
  [ "$(visible "$(cells energy)")" -eq 3 ]
  [ "$(nth "$(cells energy)" 1)" = ▁ ]
  [[ "$(line energy)" =~ \ [0-9]+\.[0-9]\ ?k?Wh$ ]]
  [[ "$output" != *max* && "$output" != */day* ]]
}

@test "R124: writes 0% for a token type without tokens" {
  adapter claude "$(record claude 0 null '{}' '{}' '[]' '{"input":1,"output":3,"cache_read":0,"cache_write":0}' "$zero" 0 '{}')"
  run report --brief
  [[ "$(line tokens)" =~ in\ 25\.0%\ ·\ out\ 75\.0%\ ·\ cache\ read\ 0%\ ·\ cache\ write\ 0%$ ]]
}

@test "R124: prints no cost or energy line without price or model data" {
  adapter claude "$(record claude 0 null '{}' '{}' '[]' "$million" "$zero" 0 '{}')"
  run report --brief
  [ -n "$(line tokens)" ]
  [ -z "$(line cost)$(line energy)" ]
}

@test "R58: covers at most the last 30 days, from the first day with usage" {
  adapter claude "$(START=2026-08-01T08:00:00.000Z record claude 0 null '{}' '{}' '[]' "$million" "$zero" 0 '{}'
    START=2026-10-12T08:00:00.000Z record claude 0 null '{}' '{}' '[]' "$million" "$zero" 0 '{}')"
  run report --brief
  [ "$(visible "$(cells tokens)")" -eq 30 ]
  adapter claude "$(START=2026-10-10T08:00:00.000Z record claude 0 null '{}' '{}' '[]' "$million" "$zero" 0 '{}'
    START=2026-10-14T08:00:00.000Z record claude 0 null '{}' '{}' '[]' "$million" "$zero" 0 '{}')"
  run report --brief
  [ "$(visible "$(cells tokens)")" -eq 5 ]
}

@test "R72: writes token totals as whole numbers below a thousand and with k below a million" {
  adapter claude "$(record claude 0 null '{}' '{}' '[]' '{"input":999,"output":0,"cache_read":0,"cache_write":0}' "$zero" 0 '{}')"
  run report --brief
  [[ "$(line tokens)" =~ \ 999\  ]]
  adapter claude "$(record claude 0 null '{}' '{}' '[]' '{"input":1500,"output":0,"cache_read":0,"cache_write":0}' "$zero" 0 '{}')"
  run report --brief
  [[ "$(line tokens)" =~ \ 1\.5k\  ]]
}

@test "R106: writes the cost total as dollars with one decimal" {
  with_prices
  adapter claude "$(record claude 0 null '{}' '{}' '[]' "$million" "$zero" 0 "{\"claude-a\":$million}")"
  run report --brief
  [[ "$(line cost)" =~ \ \$4\.6$ ]]
}
