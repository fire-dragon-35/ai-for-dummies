bats_require_minimum_version 1.5.0

setup() {
  source_root="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  repo="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$repo/.agents/hooks"
  cp "$source_root/.agents/hooks/"* "$repo/.agents/hooks/"
  cd "$repo" || return 1
  git init -q
  git add -A
  commit init
}

commit() {
  git -c user.name=t -c user.email=t@t commit -qm "$1" --no-verify
}

stage() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" > "$1"
  git add "$1"
}

check() {
  printf '%s\n' "$stderr" | grep -q "^ *$1 \+$2"
}

marks() {
  printf '%s\n' "$stderr" | grep -nE '^ *[.Fs]+ *$'
}

pre_commit() {
  sh .agents/hooks/pre-commit
}

pre_push() {
  sh .agents/hooks/pre-push origin "$BATS_TEST_TMPDIR/remote" < /dev/null
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
  git add -A
  commit suite
}

@test "R1: marks every check passed for clean files" {
  stage run.sh "$(printf '%s\n' '#!/bin/sh' '# shellcheck disable=SC2034' 'echo "ok"')"
  stage app.mjs "$(printf '%s\n' '#!/usr/bin/env node' "const url = 'https://example.test'" 'console.log(url)')"
  run --separate-stderr pre_commit
  [ "$status" -eq 0 ]
  for name in "reviewed tests" "no comments" "line limit" shellcheck; do check '✓' "$name"; done
}

@test "R2: rejects comment lines in shell and module files" {
  stage a.sh "$(printf '%s\n' '#!/bin/sh' '  # explain' 'echo "ok"')"
  stage .agents/hooks/extra "$(printf '%s\n' '#!/bin/sh' '# explain')"
  stage b.mjs "$(printf '%s\n' 'const a = 1' '// explain')"
  stage c.mjs "$(printf '%s\n' '/*' ' explain */')"
  stage notes.md "# heading"
  run --separate-stderr pre_commit
  [ "$status" -ne 0 ]
  check '✗' 'no comments'
  for f in a.sh .agents/hooks/extra b.mjs c.mjs; do [[ "$stderr" == *"$f"* ]]; done
  [[ "$stderr" != *notes.md* ]]
}

@test "R2: does not check third-party skills" {
  stage .agents/skills/vendor/run.sh "$(printf '%s\n' '#!/bin/sh' '# vendor' 'echo "ok"')"
  run --separate-stderr pre_commit
  [ "$status" -eq 0 ]
}

@test "R3: rejects a file over 400 lines" {
  stage long.txt "$(seq 401)"
  stage short.txt "$(seq 400)"
  run --separate-stderr pre_commit
  [ "$status" -ne 0 ]
  check '✗' 'line limit'
  [[ "$stderr" == *long.txt* ]]
  [[ "$stderr" != *short.txt* ]]
}

@test "R4: rejects shellcheck findings" {
  stage bad.sh "$(printf '%s\n' '#!/bin/sh' 'echo $undefined_var' 'cd /tmp')"
  run --separate-stderr pre_commit
  [ "$status" -ne 0 ]
  check '✗' shellcheck
}

@test "R5: judges the staged content" {
  stage app.mjs "const a = 1"
  printf '%s\n' '// unstaged comment' >> app.mjs
  run --separate-stderr pre_commit
  [ "$status" -eq 0 ]
  stage app.mjs "$(printf '%s\n' 'const a = 1' '// staged comment')"
  echo "const a = 1" > app.mjs
  run --separate-stderr pre_commit
  [ "$status" -ne 0 ]
}

@test "R6: changes no file and no staged file" {
  stage notes.md "text"
  echo "unstaged" > other.md
  before="$(git status --porcelain; git diff --cached | cksum; find . -path ./.git -prune -o -type f -print | sort | xargs cksum)"
  run --separate-stderr pre_commit
  [ "$status" -eq 0 ]
  [ "$(git status --porcelain; git diff --cached | cksum; find . -path ./.git -prune -o -type f -print | sort | xargs cksum)" = "$before" ]
}

@test "R7: prints the backlog after the check lines and keeps the status" {
  stage .agents/backlog.md "$(printf '%s\n' '- first item' '' '- second item')"
  run --separate-stderr pre_commit
  [ "$status" -eq 0 ]
  last_check="$(printf '%s\n' "$stderr" | grep -n '✓' | tail -n 1 | cut -d: -f1)"
  first_item="$(printf '%s\n' "$stderr" | grep -n 'first item' | cut -d: -f1)"
  [ "$first_item" -gt "$last_check" ]
  [[ "$stderr" == *"second item"* ]]
  stage bad.mjs "// comment"
  run --separate-stderr pre_commit
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"first item"* ]]
}

@test "R8: prints no escape sequences without a terminal" {
  stage bad.mjs "// comment"
  run --separate-stderr pre_commit
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

@test "R14: the staged fingerprint follows staged files and ignores the working tree" {
  component alpha
  git add -A
  staged="$(fingerprint --staged .agents/tests/alpha)"
  [ "$staged" = "$(fingerprint .agents/tests/alpha)" ]
  echo "unstaged" > .agents/tests/alpha/extra.txt
  echo "unstaged" > .agents/tests/alpha/requirements.md
  [ "$(fingerprint --staged .agents/tests/alpha)" = "$staged" ]
  git add .agents/tests/alpha/extra.txt
  [ "$(fingerprint --staged .agents/tests/alpha)" != "$staged" ]
}

@test "R10: accepts a reviewed component and rejects an unreviewed change" {
  component alpha
  review alpha
  git add -A
  run --separate-stderr pre_commit
  [ "$status" -eq 0 ]
  commit reviewed
  echo "weaker" > .agents/tests/alpha/requirements.md
  git add -A
  run --separate-stderr pre_commit
  [ "$status" -ne 0 ]
  check '✗' 'reviewed tests'
  [[ "$stderr" == *.agents/tests/alpha* ]]
}

@test "R10: rejects a review that is only in the working tree" {
  component alpha
  git add -A
  review alpha
  run --separate-stderr pre_commit
  [ "$status" -ne 0 ]
  [[ "$stderr" == *.agents/tests/alpha* ]]
}

@test "R11: accepts deleting a whole component and ignores untouched ones" {
  component alpha
  component beta
  git add -A
  commit unreviewed
  git rm -rq .agents/tests/alpha
  run --separate-stderr pre_commit
  [ "$status" -eq 0 ]
}

@test "R12: pre-push runs shellcheck on tracked shell files" {
  suite pass '@test "R1: passes" { true; }'
  run --separate-stderr pre_push
  [ "$status" -eq 0 ]
  check '✓' shellcheck
  [[ "$stderr" != *$'\033'* ]]
  stage bad.sh "$(printf '%s\n' '#!/bin/sh' 'echo $undefined_var')"
  suite pass '@test "R1: never runs" { touch "$BATS_TEST_DIRNAME/ran"; }'
  run --separate-stderr pre_push
  [ "$status" -ne 0 ]
  check '✗' shellcheck
  [ ! -e .agents/tests/pass/ran ]
}

@test "R13: pre-push fails when a test of any component fails" {
  suite pass '@test "R1: passes" { true; }'
  suite zfail '@test "R1: fails" { false; }'
  run --separate-stderr pre_push
  [ "$status" -ne 0 ]
  check '✓' shellcheck
}

@test "R16: pre-push prints a progress mark per test and no passed test name" {
  suite alpha "$(printf '%s\n' '@test "R1: passes" { true; }' '@test "R2: skipped" { skip; }')"
  suite beta '@test "R1: fails" { false; }'
  run --separate-stderr pre_push
  [ "$(marks | cut -d: -f2- | tr -d ' \n' | fold -w1 | LC_ALL=C sort | tr -d '\n')" = ".Fs" ]
  [[ "$stderr" != *"R1: passes"* ]]
}

@test "R17: pre-push prints the name and output of a failed test" {
  suite alpha '@test "R1: passes" { true; }'
  suite beta '@test "R1: fails" { echo "visible output"; false; }'
  run --separate-stderr pre_push
  [[ "$stderr" == *"R1: fails"* ]]
  [[ "$stderr" == *"visible output"* ]]
  last_mark="$(marks | tail -n 1 | cut -d: -f1)"
  name="$(printf '%s\n' "$stderr" | grep -n 'R1: fails' | tail -n 1 | cut -d: -f1)"
  [ "$name" -gt "$last_mark" ]
}

@test "R18: pre-push prints a summary line for the tests that is no check line" {
  suite alpha "$(printf '%s\n' '@test "R1: passes" { true; }' '@test "R2: skipped" { skip; }')"
  run --separate-stderr pre_push
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"1 pass, 0 fail, 1 skip"* ]]
  suite beta '@test "R1: fails" { false; }'
  run --separate-stderr pre_push
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"1 pass, 1 fail, 1 skip"* ]]
  run ! grep -Eq '[✓✗] +tests' <<< "$stderr"
}

@test "R15: pre-push runs tests of different components concurrently" {
  command -v parallel > /dev/null || skip "GNU parallel is not installed"
  [ "$(getconf _NPROCESSORS_ONLN)" -gt 1 ] || skip "one processor is online"
  meet='touch "$BATS_TEST_DIRNAME/arrived"; for i in $(seq 100); do [ -e "$BATS_TEST_DIRNAME/../$1/arrived" ] && return 0; sleep 0.1; done; return 1'
  suite alpha "$(printf '%s\n' "meet() { $meet; }" '@test "R1: meets beta" { meet beta; }')"
  suite beta "$(printf '%s\n' "meet() { $meet; }" '@test "R1: meets alpha" { meet alpha; }')"
  run --separate-stderr pre_push
  [ "$status" -eq 0 ]
}
