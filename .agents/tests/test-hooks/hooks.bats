bats_require_minimum_version 1.5.0

setup() {
  source_root="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  repo="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$repo/.agents/hooks" "$repo/.agents/metrics"
  cp "$source_root/.agents/hooks/"* "$repo/.agents/hooks/"
  cp "$source_root/.agents/metrics/"*.mjs "$source_root/.agents/metrics/log.sh" "$repo/.agents/metrics/"
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/claude"
  export AI_FOR_DUMMIES_PRICES_URL="file://$BATS_TEST_TMPDIR/no-prices.json"
  export AI_FOR_DUMMIES_MODELS_URL="file://$BATS_TEST_TMPDIR/no-models.json"
  cd "$repo" || return 1
  git init -q
  git add -A
  commit init
}

commit() {
  git -c user.name=t -c user.email=t@t commit -qm "$1" --no-verify
}

write() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" > "$1"
}

check() {
  printf '%s\n' "$stderr" | grep -q "^ *$1 \+$2"
}

marks() {
  printf '%s\n' "$stderr" | grep -nE '^ *[.Fs]+ *$'
}

qa() {
  sh .agents/hooks/qa.sh
}

fingerprint() {
  sh .agents/hooks/fingerprint.sh "$@"
}

component() {
  mkdir -p ".agents/tests/$1/fixtures"
  echo "R1" > ".agents/tests/$1/requirements.md"
  echo "input" > ".agents/tests/$1/fixtures/input.txt"
}

review() {
  fingerprint ".agents/tests/$1" > ".agents/tests/$1/reviewed"
}

suite() {
  mkdir -p ".agents/tests/$1"
  printf '%s\n' "$2" > ".agents/tests/$1/t.bats"
  review "$1"
}

wait_for() {
  for _ in $(seq 100); do
    "$@" && return 0
    sleep 0.1
  done
  return 1
}

@test "R1: marks every check passed for clean files" {
  write run.sh "$(printf '%s\n' '#!/bin/sh' '# shellcheck disable=SC2034' 'echo "ok"')"
  write app.mjs "$(printf '%s\n' '#!/usr/bin/env node' "const url = 'https://example.test'" 'console.log(url)')"
  run --separate-stderr qa
  [ "$status" -eq 0 ]
  for name in "reviewed tests" "no comments" "line limit" shellcheck; do check '✓' "$name"; done
}

@test "R2: names comment lines in shell and module files" {
  write a.sh "$(printf '%s\n' '#!/bin/sh' '  # explain' 'echo "ok"')"
  write .agents/hooks/extra "$(printf '%s\n' '#!/bin/sh' '# explain')"
  write b.mjs "$(printf '%s\n' 'const a = 1' '// explain')"
  write c.mjs "$(printf '%s\n' '/*' ' explain */')"
  write notes.md "# heading"
  run --separate-stderr qa
  [ "$status" -ne 0 ]
  check '✗' 'no comments'
  for f in a.sh .agents/hooks/extra b.mjs c.mjs; do [[ "$stderr" == *"$f"* ]]; done
  [[ "$stderr" != *notes.md* ]]
}

@test "R2: does not check third-party skills" {
  write .agents/skills/vendor/run.sh "$(printf '%s\n' '#!/bin/sh' '# vendor' 'echo "ok"')"
  run --separate-stderr qa
  [ "$status" -eq 0 ]
}

@test "R3: names a file over 400 lines" {
  write long.txt "$(seq 401)"
  write short.txt "$(seq 400)"
  run --separate-stderr qa
  [ "$status" -ne 0 ]
  check '✗' 'line limit'
  [[ "$stderr" == *long.txt* ]]
  [[ "$stderr" != *short.txt* ]]
}

@test "R4: reports shellcheck findings" {
  write bad.sh "$(printf '%s\n' '#!/bin/sh' 'echo $undefined_var' 'cd /tmp')"
  run --separate-stderr qa
  [ "$status" -ne 0 ]
  check '✗' shellcheck
  [[ "$stderr" == *bad.sh* ]]
}

@test "R5: judges the working tree content, staged or not" {
  write app.mjs "const a = 1"
  git add app.mjs
  printf '%s\n' '// unstaged comment' >> app.mjs
  run --separate-stderr qa
  [ "$status" -ne 0 ]
  check '✗' 'no comments'
  write app.mjs "const a = 1"
  run --separate-stderr qa
  [ "$status" -eq 0 ]
}

@test "R6: changes no file and no staged file" {
  write notes.md "text"
  git add notes.md
  echo "unstaged" > other.md
  before="$(git status --porcelain; git diff --cached | cksum; find . -path ./.git -prune -o -type f -print | sort | xargs cksum)"
  run --separate-stderr qa
  [ "$status" -eq 0 ]
  [ "$(git status --porcelain; git diff --cached | cksum; find . -path ./.git -prune -o -type f -print | sort | xargs cksum)" = "$before" ]
}

@test "R8: prints no escape sequences without a terminal" {
  write bad.mjs "// comment"
  suite alpha '@test "R1: fails" { false; }'
  run --separate-stderr qa
  [[ "$stderr" == *'✗'* ]]
  [[ "$stderr" != *$'\033'* ]]
}

@test "R9: the fingerprint follows content, additions, removals and renames" {
  component alpha
  first="$(fingerprint .agents/tests/alpha)"
  [ "$(printf '%s\n' "$first" | wc -l)" -eq 1 ]
  echo "extra" > .agents/tests/alpha/fixtures/extra.txt
  [ "$(fingerprint .agents/tests/alpha)" != "$first" ]
  rm .agents/tests/alpha/fixtures/extra.txt
  [ "$(fingerprint .agents/tests/alpha)" = "$first" ]
  echo "changed" > .agents/tests/alpha/fixtures/input.txt
  changed="$(fingerprint .agents/tests/alpha)"
  [ "$changed" != "$first" ]
  mv .agents/tests/alpha/requirements.md .agents/tests/alpha/renamed.md
  [ "$(fingerprint .agents/tests/alpha)" != "$changed" ]
  echo "anything" > .agents/tests/alpha/reviewed
  mv .agents/tests/alpha/renamed.md .agents/tests/alpha/requirements.md
  [ "$(fingerprint .agents/tests/alpha)" = "$changed" ]
}

@test "R9: the fingerprint follows the files listed in the tests file" {
  component alpha
  write test/app.test.js "test('R1: a', () => {})"
  printf '%s\n' test/app.test.js > .agents/tests/alpha/tests
  listed="$(fingerprint .agents/tests/alpha)"
  write test/app.test.js "test('R1: b', () => {})"
  changed="$(fingerprint .agents/tests/alpha)"
  [ "$changed" != "$listed" ]
  write test/other.test.js "test('R1: b', () => {})"
  [ "$(fingerprint .agents/tests/alpha)" = "$changed" ]
  printf '%s\n' test/app.test.js test/other.test.js > .agents/tests/alpha/tests
  both="$(fingerprint .agents/tests/alpha)"
  [ "$both" != "$changed" ]
  rm test/other.test.js
  [ "$(fingerprint .agents/tests/alpha)" != "$both" ]
}

@test "R24: marks the project's passing test command passed" {
  write .agents/test-command 'sh test/run.sh'
  write test/run.sh "$(printf '%s\n' '#!/bin/sh' 'echo "all good"')"
  run --separate-stderr qa
  [ "$status" -eq 0 ]
  check '✓' 'project tests'
}

@test "R26: marks the project's failing test command failed with the end of its output" {
  write .agents/test-command 'sh test/run.sh'
  write test/run.sh "$(printf '%s\n' '#!/bin/sh' 'seq 50' 'echo "R2: broken"' 'exit 1')"
  run --separate-stderr qa
  [ "$status" -ne 0 ]
  check '✗' 'project tests'
  [[ "$stderr" == *"R2: broken"* ]]
}

@test "R25: prints no project tests check without a test command" {
  run --separate-stderr qa
  [ "$status" -eq 0 ]
  [[ "$stderr" != *"project tests"* ]]
}

@test "R10: accepts a reviewed component and names an unreviewed change" {
  component alpha
  review alpha
  run --separate-stderr qa
  [ "$status" -eq 0 ]
  check '✓' 'reviewed tests'
  echo "weaker" > .agents/tests/alpha/requirements.md
  run --separate-stderr qa
  [ "$status" -ne 0 ]
  check '✗' 'reviewed tests'
  [[ "$stderr" == *.agents/tests/alpha* ]]
}

@test "R13: fails when a test of any component fails" {
  suite pass '@test "R1: passes" { true; }'
  suite zfail '@test "R1: fails" { false; }'
  run --separate-stderr qa
  [ "$status" -ne 0 ]
  check '✓' shellcheck
}

@test "R16: prints a progress mark per test and no passed test name" {
  suite alpha "$(printf '%s\n' '@test "R1: passes" { true; }' '@test "R2: skipped" { skip; }')"
  suite beta '@test "R1: fails" { false; }'
  run --separate-stderr qa
  [ "$(marks | cut -d: -f2- | tr -d ' \n' | fold -w1 | LC_ALL=C sort | tr -d '\n')" = ".Fs" ]
  [[ "$stderr" != *"R1: passes"* ]]
}

@test "R17: prints the name and output of a failed test" {
  suite alpha '@test "R1: passes" { true; }'
  suite beta '@test "R1: fails" { echo "visible output"; false; }'
  run --separate-stderr qa
  [[ "$stderr" == *"R1: fails"* ]]
  [[ "$stderr" == *"visible output"* ]]
  last_mark="$(marks | tail -n 1 | cut -d: -f1)"
  name="$(printf '%s\n' "$stderr" | grep -n 'R1: fails' | tail -n 1 | cut -d: -f1)"
  [ "$name" -gt "$last_mark" ]
}

@test "R18: prints a summary line for the tests that is no check line" {
  suite alpha "$(printf '%s\n' '@test "R1: passes" { true; }' '@test "R2: skipped" { skip; }')"
  run --separate-stderr qa
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"1 pass, 0 fail, 1 skip"* ]]
  suite beta '@test "R1: fails" { false; }'
  run --separate-stderr qa
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"1 pass, 1 fail, 1 skip"* ]]
  run ! grep -Eq '[✓✗] +tests' <<< "$stderr"
}

@test "R15: runs tests of different components concurrently" {
  command -v parallel > /dev/null || skip "GNU parallel is not installed"
  [ "$(getconf _NPROCESSORS_ONLN)" -gt 1 ] || skip "one processor is online"
  meet='touch "$BATS_TEST_DIRNAME/arrived"; for i in $(seq 100); do [ -e "$BATS_TEST_DIRNAME/../$1/arrived" ] && return 0; sleep 0.1; done; return 1'
  suite alpha "$(printf '%s\n' "meet() { $meet; }" '@test "R1: meets beta" { meet beta; }')"
  suite beta "$(printf '%s\n' "meet() { $meet; }" '@test "R1: meets alpha" { meet alpha; }')"
  run --separate-stderr qa
  [ "$status" -eq 0 ]
}

@test "R22: a second run waits for the active run and the active run repeats" {
  suite counted "$(printf '%s\n' '@test "R1: counts" {' '  echo run >> "$BATS_TEST_DIRNAME/runs"' '  for i in $(seq 100); do [ -e "$BATS_TEST_DIRNAME/go" ] && return 0; sleep 0.1; done' '  return 1' '}')"
  sh .agents/hooks/qa.sh > /dev/null 2>&1 &
  active=$!
  runs() { [ "$(cat .agents/tests/counted/runs 2> /dev/null | wc -l)" -ge "$1" ]; }
  wait_for runs 1
  run --separate-stderr qa
  [ "$status" -eq 0 ]
  touch .agents/tests/counted/go
  wait "$active" || true
  [ "$(wc -l < .agents/tests/counted/runs)" -eq 2 ]
}

@test "R23: ignores the git environment of the hook that started it" {
  other="$BATS_TEST_TMPDIR/other"
  git init -q "$other"
  suite gitty "$(printf '%s\n' '@test "R1: commits in its own repository" {' '  cd "$BATS_TEST_TMPDIR" && git init -q own && cd own' '  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m own' '}')"
  GIT_DIR="$other/.git" GIT_INDEX_FILE="$other/.git/index" run --separate-stderr qa
  [ "$status" -eq 0 ]
  for name in "reviewed tests" "no comments" "line limit" shellcheck; do check '✓' "$name"; done
  [ -z "$(git -C "$other" log --oneline 2> /dev/null)" ]
}

@test "R19: the post-commit hook returns at once and exits with status 0 while the QA run is going" {
  suite slow '@test "R1: waits" { for i in $(seq 100); do [ -e "$BATS_TEST_DIRNAME/go" ] && return 0; sleep 0.1; done; return 1; }'
  write bad.mjs "// comment"
  run --separate-stderr sh .agents/hooks/post-commit
  [ "$status" -eq 0 ]
  [ ! -e .agents/tests/slow/go ]
  touch .agents/tests/slow/go
  logged() { grep -q '"name":"R1: waits"' .git/ai-for-dummies/metrics.jsonl 2> /dev/null; }
  wait_for logged
}

@test "R20: the post-commit hook starts a QA run that logs its results" {
  suite alpha '@test "R1: passes" { true; }'
  run --separate-stderr sh .agents/hooks/post-commit
  [ "$status" -eq 0 ]
  logged() { grep -q '"name":"R1: passes"' .git/ai-for-dummies/metrics.jsonl 2> /dev/null; }
  wait_for logged
}

@test "R21: the post-commit hook prints the brief report of the earlier QA run" {
  suite alpha '@test "R1: passes" { true; }'
  run --separate-stderr qa
  brief="$(node .agents/metrics/metrics.mjs . --brief)"
  run sh .agents/hooks/post-commit
  [ "$status" -eq 0 ]
  [[ "$brief" == *shellcheck* ]]
  [[ "$brief" == *"1 pass"* ]]
  [[ "$output" == *"$brief"* ]]
  logged_twice() { [ "$(grep -c '"name":"R1: passes"' .git/ai-for-dummies/metrics.jsonl 2> /dev/null)" -ge 2 ]; }
  wait_for logged_twice
}
