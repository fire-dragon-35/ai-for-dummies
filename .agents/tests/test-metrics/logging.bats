bats_require_minimum_version 1.5.0

setup() {
  load helpers
  setup_metrics_repo
}

with_hooks() {
  mkdir -p "$repo/.agents/hooks"
  cp "$source_root/.agents/hooks/"* "$repo/.agents/hooks/"
  mkdir -p .agents/tests/sample
  printf '%s\n' '@test "R1: passes" { true; }' '@test "R2: has a \"quote\"" { true; }' '@test "R3: skipped" { skip "later"; }' "${1:-}" > .agents/tests/sample/t.bats
  git add -A
  git -c user.name=t -c user.email=t@t commit -qm init --no-verify
}

push() {
  sh .agents/hooks/pre-push origin "$BATS_TEST_TMPDIR/remote" < /dev/null
}

result_of() {
  N="$1" q 'x.name === process.env.N ? x.kind + ":" + x.result : undefined' "$log"
}

@test "R23: appends one record whose fields equal the arguments" {
  run --separate-stderr verdict test 'say "hi" \ back' pass "$(printf 'a\tb')"
  [ "$status" -eq 0 ]
  [ -z "$output$stderr" ]
  verdict check shellcheck fail
  [ "$(wc -l < "$log")" -eq 2 ]
  [ "$(head -n 1 "$log" | q '[x.kind, x.name, x.result, x.detail]')" = "$(node -e 'console.log(JSON.stringify(["test", "say \"hi\" \\ back", "pass", "a\tb"]))')" ]
  [ "$(tail -n 1 "$log" | q 'x.detail')" = "" ]
  [ "$(tail -n 1 "$log" | q '/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(x.time)')" = true ]
}

@test "R100: adds the fifth argument as source" {
  verdict check shellcheck pass "" .agents/hooks/pre-push
  [ "$(q 'x.source' "$log")" = .agents/hooks/pre-push ]
}

@test "R24: writes to the main log from a worktree and refuses bad calls" {
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  git worktree add -q "$BATS_TEST_TMPDIR/linked"
  (cd "$BATS_TEST_TMPDIR/linked" && sh "$repo/.agents/metrics/log.sh" check shellcheck pass)
  [ "$(wc -l < "$log")" -eq 1 ]
  run --separate-stderr verdict check shellcheck
  [ "$status" -ne 0 ]
  [ "$(wc -l < "$log")" -eq 1 ]
  mkdir -p "$BATS_TEST_TMPDIR/plain" && cd "$BATS_TEST_TMPDIR/plain" || return 1
  run --separate-stderr sh "$repo/.agents/metrics/log.sh" check shellcheck pass
  [ "$status" -ne 0 ]
  [ -z "$(ls -A)" ]
}

@test "R25: the hooks log every check line" {
  with_hooks
  printf '%s\n' '#!/bin/sh' '# explain' > run.sh
  git add run.sh
  run --separate-stderr sh .agents/hooks/pre-commit
  [ "$status" -ne 0 ]
  [ "$(result_of 'no comments')" = check:fail ]
  detail="$(q 'x.name === "no comments" ? x.detail : undefined' "$log")"
  [ -n "$detail" ]
  printf '%s\n' "$stderr" | grep -F 'no comments' | grep -qF "$detail"
  [ "$(result_of shellcheck)" = check:pass ]
  [ "$(result_of 'line limit')" = check:pass ]
  [ "$(result_of 'reviewed tests')" = check:pass ]
}

@test "R101: the hooks log the path of the hook as source" {
  with_hooks
  run --separate-stderr push
  [ "$(q 'x.kind === "check" ? x.source : undefined' "$log" | sort -u)" = .agents/hooks/pre-push ]
  printf '%s\n' '#!/bin/sh' '# explain' > run.sh
  git add run.sh
  run --separate-stderr sh .agents/hooks/pre-commit
  [ "$(q 'x.name === "no comments" ? x.source : undefined' "$log")" = .agents/hooks/pre-commit ]
}

@test "R26: pre-push logs every test" {
  with_hooks '@test "R4: fails" { false; }'
  run --separate-stderr push
  [ "$status" -ne 0 ]
  [ "$(result_of 'R1: passes')" = test:pass ]
  [ "$(result_of 'R2: has a "quote"')" = test:pass ]
  [ "$(result_of 'R3: skipped')" = test:skip ]
  [ "$(result_of 'R4: fails')" = test:fail ]
  [ "$(result_of shellcheck)" = check:pass ]
}

@test "R108: the hooks log how many seconds the checks and the test suite took" {
  with_hooks '@test "R4: slow" { sleep 2; }'
  run --separate-stderr sh .agents/hooks/pre-commit
  [ "$(q 'x.kind === "duration" ? x.name : undefined' "$log")" = checks ]
  [[ "$(q 'x.kind === "duration" ? x.result : undefined' "$log")" =~ ^[0-9]{1,2}$ ]]
  run --separate-stderr push
  [ "$(q 'x.kind === "duration" && x.name === "tests" ? x.result : undefined' "$log" | wc -l)" -eq 1 ]
  [ "$(q 'x.kind === "duration" && x.name === "tests" ? /^\d+$/.test(x.result) && Number(x.result) >= 2 && Number(x.result) < 60 : undefined' "$log")" = true ]
}

@test "R27: pre-push writes the dashboard and prints its link" {
  mv "$repo" "$BATS_TEST_TMPDIR/with space"
  repo="$BATS_TEST_TMPDIR/with space"
  log="$repo/.git/ai-for-dummies/metrics.jsonl"
  cd "$repo" || return 1
  with_hooks
  run --separate-stderr push
  [ "$status" -eq 0 ]
  link="$(printf '%s\n' "$stderr" | grep -o 'file://[^ ]*dashboard.html')"
  [[ "$link" == *with%20space* ]]
  [ -s "$repo/.git/ai-for-dummies/dashboard.html" ]
  grep -q 'shellcheck' "$repo/.git/ai-for-dummies/dashboard.html"
}

@test "R27: a dashboard that cannot be written keeps the exit status" {
  with_hooks
  mkdir -p "$repo/.git/ai-for-dummies/dashboard.html"
  run --separate-stderr push
  [ "$status" -eq 0 ]
}

@test "R28: without the metrics the hooks write no log and no dashboard" {
  with_hooks
  rm -r "$repo/.agents/metrics"
  git add -A
  git -c user.name=t -c user.email=t@t commit -qm drop --no-verify
  run --separate-stderr push
  [ "$status" -eq 0 ]
  [ ! -e "$repo/.git/ai-for-dummies" ]
  [[ "$stderr" != *dashboard* ]]
}
