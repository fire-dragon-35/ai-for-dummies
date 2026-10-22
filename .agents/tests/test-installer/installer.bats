bats_require_minimum_version 1.5.0

setup() {
  source_root="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  target="$BATS_TEST_TMPDIR/my target"
  mkdir -p "$target"
  git -C "$target" init -q
  echo "app" > "$target/app.py"
}

install() {
  sh "$source_root/install.sh" "$@"
}

core_files() {
  (cd "$source_root" && find .agents/skills -name SKILL.md ! -path '*/metrics/*' ! -path '*/benchmark/*'
    printf '%s\n' .agents/repository-context/generate.sh .agents/repository-context/skills.sh .agents/web-sources.md)
}

hook_files() {
  (cd "$source_root" && find .agents/hooks .agents/metrics -type f; echo .agents/skills/metrics/SKILL.md)
}

git_hook() {
  echo "$target/.git/hooks/post-commit"
}

same() {
  while IFS= read -r f; do
    cmp -s "$source_root/$f" "$target/$f" || { echo "differs: $f"; return 1; }
    [ ! -x "$source_root/$f" ] || [ -x "$target/$f" ] || { echo "not executable: $f"; return 1; }
  done
}

none() {
  while IFS= read -r f; do [ ! -e "$target/$f" ] || { echo "exists: $f"; return 1; }; done
}

snapshot() {
  (cd "$target" && find . -path ./.git/objects -prune -o -print | LC_ALL=C sort | while IFS= read -r p; do
    if [ -f "$p" ]; then printf '%s %s\n' "$p" "$(cksum < "$p")"; else printf '%s\n' "$p"; fi
  done)
}

block() {
  awk '/^<!-- ai-for-dummies:start -->$/ { on = 1 } on { print } /^<!-- ai-for-dummies:end -->$/ { on = 0 }' "$1"
}

rules() {
  block "$1" | sed '/^## Skills$/,$d'
}

@test "R1: installs the core files, both blocks, the map and the skills table" {
  printf '%s\n' '# Mine' 'keep me' > "$target/AGENTS.md"
  run install "$target"
  [ "$status" -eq 0 ]
  core_files | same
  [ "$(head -n 2 "$target/AGENTS.md")" = "$(printf '%s\n' '# Mine' 'keep me')" ]
  [ "$(rules "$target/AGENTS.md")" = "$(rules "$source_root/AGENTS.md")" ]
  block "$target/AGENTS.md" | grep -q '^## Skills$'
  block "$target/AGENTS.md" | grep -qF '.agents/skills/context/SKILL.md'
  block "$target/CLAUDE.md" | grep -qx '@AGENTS.md'
  grep -qx 'app.py' "$target/.agents/repository-context/directories.md"
}

@test "R2: a plain install adds no hooks and leaves .git alone" {
  before="$(cd "$target/.git" && find . -path ./objects -prune -o -type f -print | sort | xargs cksum)"
  run install "$target"
  [ "$status" -eq 0 ]
  hook_files | none
  [ "$(cd "$target/.git" && find . -path ./objects -prune -o -type f -print | sort | xargs cksum)" = "$before" ]
}

@test "R3: --hooks copies the hook files and writes a git hook that runs the post-commit hook" {
  run install --hooks "$target"
  [ "$status" -eq 0 ]
  hook_files | same
  [ -x "$(git_hook)" ]
  [ -z "$(git -C "$target" config --local core.hooksPath)" ]
  grep -qF .agents/hooks/post-commit "$(git_hook)"
}

@test "R4: --hooks refuses a target with its own hooks setting" {
  git -C "$target" config core.hooksPath .husky
  before="$(snapshot)"
  run --separate-stderr install --hooks "$target"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *hooksPath* ]]
  [ "$(snapshot)" = "$before" ]
}

@test "R4: --hooks refuses a target with a git hook" {
  printf '%s\n' '#!/bin/sh' > "$(git_hook)"
  before="$(snapshot)"
  run --separate-stderr install --hooks "$target"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *post-commit* ]]
  [ "$(snapshot)" = "$before" ]
}

@test "R15: --hooks leaves other git hooks and samples in place" {
  printf '%s\n' '#!/bin/sh' 'echo mine' > "$target/.git/hooks/pre-commit"
  touch "$target/.git/hooks/post-commit.sample"
  run install --hooks "$target"
  [ "$status" -eq 0 ]
  [ "$(cat "$target/.git/hooks/pre-commit")" = "$(printf '%s\n' '#!/bin/sh' 'echo mine')" ]
  [ -e "$target/.git/hooks/post-commit.sample" ]
}

@test "R7: .claude/skills shows the same skills" {
  install "$target"
  [ -s "$target/.claude/skills/context/SKILL.md" ]
  (cd "$target" && find .agents/skills -type f) | while IFS= read -r f; do
    cmp "$target/$f" "$target/.claude/skills/${f#.agents/skills/}" || exit 1
  done
}

@test "R8: refuses a missing target, a non-repository and a subdirectory" {
  run --separate-stderr install "$BATS_TEST_TMPDIR/missing"
  [ "$status" -ne 0 ]
  [ -n "$stderr" ]
  mkdir -p "$BATS_TEST_TMPDIR/plain" "$target/sub"
  run --separate-stderr install "$BATS_TEST_TMPDIR/plain"
  [ "$status" -ne 0 ]
  [ -z "$(ls -A "$BATS_TEST_TMPDIR/plain")" ]
  before="$(snapshot)"
  run --separate-stderr install "$target/sub"
  [ "$status" -ne 0 ]
  [ "$(snapshot)" = "$before" ]
}

@test "R8: refuses an existing file and a second install" {
  mkdir -p "$target/.agents"
  echo mine > "$target/.agents/web-sources.md"
  before="$(snapshot)"
  run --separate-stderr install "$target"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *web-sources.md* ]]
  [ "$(snapshot)" = "$before" ]
  rm "$target/.agents/web-sources.md"
  install "$target"
  before="$(snapshot)"
  run --separate-stderr install "$target"
  [ "$status" -ne 0 ]
  [ "$(snapshot)" = "$before" ]
}

@test "R9: names the target and the commit command" {
  run install "$target"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$target"* ]]
  [[ "$output" == *"git add . && git commit"* ]]
}

@test "R17: install and update copy no file of the benchmark skill" {
  [ -e "$source_root/.agents/skills/benchmark/SKILL.md" ]
  install --hooks "$target"
  [ ! -e "$target/.agents/skills/benchmark" ]
  [ ! -e "$target/.claude/skills/benchmark" ]
  run install --update --hooks "$target"
  [ "$status" -eq 0 ]
  [ ! -e "$target/.agents/skills/benchmark" ]
}

@test "R10: prints usage for an unknown option or a missing target" {
  run --separate-stderr install --bogus "$target"
  [ "$status" -eq 2 ]
  [[ "${stderr,,}" == *usage* ]]
  run --separate-stderr install
  [ "$status" -eq 2 ]
  [[ "${stderr,,}" == *usage* ]]
}

@test "R10: prints usage for the removed options --metrics and --ci" {
  for option in --metrics --ci; do
    run --separate-stderr install "$option" "$target"
    [ "$status" -eq 2 ]
    [[ "${stderr,,}" == *usage* ]]
  done
}

@test "R11: update refreshes the block and the installed parts and keeps other lines" {
  install --hooks "$target"
  printf '%s\n' 'after the block' >> "$target/AGENTS.md"
  awk '{ print } /^<!-- ai-for-dummies:start -->$/ { print "- outdated rule" }' "$target/AGENTS.md" > "$target/AGENTS.tmp" && mv "$target/AGENTS.tmp" "$target/AGENTS.md"
  echo changed > "$target/.agents/hooks/qa.sh"
  rm "$target/.agents/metrics/log.sh" "$target/.agents/skills/context/SKILL.md"
  run install --update "$target"
  [ "$status" -eq 0 ]
  core_files | same
  hook_files | same
  [ "$(rules "$target/AGENTS.md")" = "$(rules "$source_root/AGENTS.md")" ]
  [ "$(tail -n 1 "$target/AGENTS.md")" = 'after the block' ]
}

@test "R11: update adds no part the target does not have, unless asked" {
  install "$target"
  run install --update "$target"
  [ "$status" -eq 0 ]
  hook_files | none
  run install --update --hooks "$target"
  [ "$status" -eq 0 ]
  hook_files | same
  [ -x "$(git_hook)" ]
}

@test "R12: update keeps the target's own files and hooks setting" {
  install --hooks "$target"
  mkdir -p "$target/.agents/tests/test-app" "$target/.agents/skills/own"
  for f in .agents/tests/test-app/requirements.md .agents/backlog.md .agents/scout.md .agents/web-sources.md .agents/skills/own/SKILL.md; do
    echo "mine" > "$target/$f"
  done
  git -C "$target" config core.hooksPath custom-hooks
  run install --update "$target"
  [ "$status" -eq 0 ]
  for f in .agents/tests/test-app/requirements.md .agents/backlog.md .agents/scout.md .agents/web-sources.md .agents/skills/own/SKILL.md; do
    [ "$(cat "$target/$f")" = mine ]
  done
  [ "$(git -C "$target" config --local core.hooksPath)" = custom-hooks ]
}

@test "R13: update refuses a target that is not installed" {
  before="$(snapshot)"
  run --separate-stderr install --update "$target"
  [ "$status" -ne 0 ]
  [ "$(snapshot)" = "$before" ]
}

@test "R16: update replaces the old hooks and the CI file by the git hook" {
  install "$target"
  mkdir -p "$target/.agents/hooks" "$target/.github/workflows"
  echo old > "$target/.agents/hooks/pre-commit"
  echo old > "$target/.agents/hooks/pre-push"
  echo old > "$target/.github/workflows/agents.yml"
  git -C "$target" config core.hooksPath .agents/hooks
  run install --update "$target"
  [ "$status" -eq 0 ]
  [ ! -e "$target/.agents/hooks/pre-commit" ]
  [ ! -e "$target/.agents/hooks/pre-push" ]
  [ ! -e "$target/.github/workflows/agents.yml" ]
  [ -z "$(git -C "$target" config --local core.hooksPath)" ]
  hook_files | same
  [ -x "$(git_hook)" ]
}
