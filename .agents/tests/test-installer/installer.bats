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
  (cd "$source_root" && find .agents/skills -name SKILL.md ! -path '*/metrics/*'
    printf '%s\n' .agents/repository-context/generate.sh .agents/repository-context/skills.sh .agents/web-sources.md)
}

hook_files() {
  (cd "$source_root" && find .agents/hooks -type f)
}

metrics_files() {
  (cd "$source_root" && find .agents/metrics -type f; echo .agents/skills/metrics/SKILL.md)
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

@test "R2: a plain install adds no hooks, metrics or CI and leaves .git alone" {
  before="$(cd "$target/.git" && find . -path ./objects -prune -o -type f -print | sort | xargs cksum)"
  run install "$target"
  [ "$status" -eq 0 ]
  hook_files | none
  metrics_files | none
  [ ! -e "$target/.github/workflows/agents.yml" ]
  [ "$(cd "$target/.git" && find . -path ./objects -prune -o -type f -print | sort | xargs cksum)" = "$before" ]
}

@test "R3: --hooks copies the hooks and sets core.hooksPath" {
  run install --hooks "$target"
  [ "$status" -eq 0 ]
  hook_files | same
  [ "$(git -C "$target" config --local core.hooksPath)" = .agents/hooks ]
}

@test "R4: --hooks refuses a target with its own hooks setting" {
  git -C "$target" config core.hooksPath .husky
  before="$(snapshot)"
  run --separate-stderr install --hooks "$target"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *hooksPath* ]]
  [ "$(snapshot)" = "$before" ]
}

@test "R4: --hooks refuses a target with an active git hook but accepts samples" {
  touch "$target/.git/hooks/pre-commit.sample"
  printf '%s\n' '#!/bin/sh' > "$target/.git/hooks/pre-commit"
  before="$(snapshot)"
  run --separate-stderr install --hooks "$target"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *pre-commit* ]]
  [ "$(snapshot)" = "$before" ]
  rm "$target/.git/hooks/pre-commit"
  run install --hooks "$target"
  [ "$status" -eq 0 ]
}

@test "R5: --metrics copies the metrics files" {
  run install --metrics "$target"
  [ "$status" -eq 0 ]
  metrics_files | same
  hook_files | none
}

@test "R6: --ci with --hooks copies the CI file" {
  run install --hooks --ci "$target"
  [ "$status" -eq 0 ]
  cmp "$source_root/.github/workflows/agents.yml" "$target/.github/workflows/agents.yml"
}

@test "R14: --ci without hooks is refused on install and update" {
  before="$(snapshot)"
  run install --ci "$target"
  [ "$status" -ne 0 ]
  [ "$(snapshot)" = "$before" ]
  install "$target"
  before="$(snapshot)"
  run install --update --ci "$target"
  [ "$status" -ne 0 ]
  [ "$(snapshot)" = "$before" ]
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

@test "R10: prints usage for an unknown option or a missing target" {
  run --separate-stderr install --bogus "$target"
  [ "$status" -eq 2 ]
  [[ "${stderr,,}" == *usage* ]]
  run --separate-stderr install
  [ "$status" -eq 2 ]
  [[ "${stderr,,}" == *usage* ]]
}

@test "R11: update refreshes the block and the installed parts and keeps other lines" {
  install --hooks --metrics --ci "$target"
  printf '%s\n' 'after the block' >> "$target/AGENTS.md"
  awk '{ print } /^<!-- ai-for-dummies:start -->$/ { print "- outdated rule" }' "$target/AGENTS.md" > "$target/AGENTS.tmp" && mv "$target/AGENTS.tmp" "$target/AGENTS.md"
  echo changed > "$target/.agents/hooks/pre-commit"
  echo changed > "$target/.github/workflows/agents.yml"
  rm "$target/.agents/metrics/log.sh" "$target/.agents/skills/context/SKILL.md"
  run install --update "$target"
  [ "$status" -eq 0 ]
  core_files | same
  hook_files | same
  metrics_files | same
  cmp "$source_root/.github/workflows/agents.yml" "$target/.github/workflows/agents.yml"
  [ "$(rules "$target/AGENTS.md")" = "$(rules "$source_root/AGENTS.md")" ]
  [ "$(tail -n 1 "$target/AGENTS.md")" = 'after the block' ]
}

@test "R11: update adds no part the target does not have, unless asked" {
  install "$target"
  run install --update "$target"
  [ "$status" -eq 0 ]
  hook_files | none
  metrics_files | none
  run install --update --metrics "$target"
  [ "$status" -eq 0 ]
  metrics_files | same
}

@test "R12: update keeps the target's own files and hooks setting" {
  install --hooks --metrics "$target"
  mkdir -p "$target/.agents/tests/test-app" "$target/.agents/skills/own"
  for f in .agents/tests/test-app/requirements.md .agents/backlog.md .agents/scout.md .agents/web-sources.md .agents/skills/own/SKILL.md; do
    echo "mine" > "$target/$f"
  done
  git -C "$target" config core.hooksPath custom-hooks
  run install --update --hooks "$target"
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
