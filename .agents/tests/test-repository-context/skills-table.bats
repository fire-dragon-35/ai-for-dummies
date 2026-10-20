bats_require_minimum_version 1.5.0

setup() {
  source_root="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  repo="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$repo/.agents/repository-context"
  cp "$source_root/.agents/repository-context/skills.sh" "$repo/.agents/repository-context/"
  skill alpha "Do alpha things"
  skill beta "Do beta things, then: check"
  printf '%s\n' '# Mine' 'Keep this' '<!-- ai-for-dummies:start -->' '## Rules' '- one' '<!-- ai-for-dummies:end -->' 'After' > "$repo/AGENTS.md"
  cd "$repo" || return 1
  git init -q
}

skill() {
  mkdir -p "$repo/.agents/skills/$1"
  printf '%s\n' '---' "name: $1" "description: $2" '---' '' 'Body' > "$repo/.agents/skills/$1/SKILL.md"
}

generate() {
  sh .agents/repository-context/skills.sh
}

table() {
  awk '/^<!-- ai-for-dummies:start -->$/ { inside = 1 } inside && /^## Skills$/ { on = 1 } /^<!-- ai-for-dummies:end -->$/ { on = 0; inside = 0 } on' "$1"
}

outside_table() {
  awk '/^<!-- ai-for-dummies:start -->$/ { inside = 1 } inside && /^## Skills$/ { on = 1 } /^<!-- ai-for-dummies:end -->$/ { on = 0; inside = 0 } !on' "$1"
}

row_for() {
  table AGENTS.md | grep -F "$1" | grep -F "$2" | grep -qF ".agents/skills/$3/SKILL.md"
}

@test "R19: lists every skill with name, description and path" {
  run generate
  [ "$status" -eq 0 ]
  row_for alpha "Do alpha things" alpha
  row_for beta "Do beta things, then: check" beta
}

@test "R19: skips a directory without SKILL.md" {
  mkdir -p .agents/skills/notes
  echo "text" > .agents/skills/notes/README.md
  generate
  run ! grep -q 'notes' AGENTS.md
}

@test "R19: puts the table at the end of the block" {
  generate
  [ "$(grep -n '^## Skills$' AGENTS.md | cut -d: -f1)" -lt "$(grep -n '^<!-- ai-for-dummies:end -->$' AGENTS.md | cut -d: -f1)" ]
  [ "$(grep -n '^## Rules$' AGENTS.md | cut -d: -f1)" -lt "$(grep -n '^## Skills$' AGENTS.md | cut -d: -f1)" ]
}

@test "R19: replaces an outdated table instead of adding another" {
  generate
  rm -r .agents/skills/beta
  skill gamma "Do gamma things"
  generate
  [ "$(grep -c '^## Skills$' AGENTS.md)" -eq 1 ]
  row_for gamma "Do gamma things" gamma
  run ! grep -q 'beta' AGENTS.md
}

@test "R20: keeps every line outside the table" {
  before="$(outside_table AGENTS.md)"
  generate
  [ "$(outside_table AGENTS.md)" = "$before" ]
}

@test "R21: changes nothing without a block" {
  printf '%s\n' '# Mine' > AGENTS.md
  run generate
  [ "$status" -eq 0 ]
  [ "$(cat AGENTS.md)" = "# Mine" ]
}

@test "R21: changes nothing without AGENTS.md" {
  rm AGENTS.md
  run generate
  [ "$status" -eq 0 ]
  [ ! -e AGENTS.md ]
}

@test "R22: this repository's skills table is up to date" {
  copy="$BATS_TEST_TMPDIR/copy"
  mkdir -p "$copy"
  cp -r "$source_root/.agents" "$source_root/AGENTS.md" "$copy/"
  git -C "$copy" init -q
  (cd "$copy" && sh .agents/repository-context/skills.sh)
  cmp "$source_root/AGENTS.md" "$copy/AGENTS.md"
}
