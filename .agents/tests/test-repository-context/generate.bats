bats_require_minimum_version 1.5.0

setup() {
  script="$BATS_TEST_DIRNAME/../../repository-context/generate.sh"
  repo="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$repo/.agents/repository-context"
  cp "$script" "$repo/.agents/repository-context/"
  cd "$repo" || return 1
  git init -q
}

map() {
  cat "$repo/.agents/repository-context/directories.md"
}

entries() {
  map | tail -n +3
}

lacks() {
  ! map | grep -q -- "$1"
}

generate() {
  sh "$repo/.agents/repository-context/generate.sh"
}

outside_repo() {
  outside="$BATS_TEST_TMPDIR/outside"
  mkdir -p "$outside/.agents/repository-context"
  cp "$script" "$outside/.agents/repository-context/"
  cd "$outside" || return 1
}

@test "R1: writes the map and exits with status 0" {
  touch a.txt
  run generate
  [ "$status" -eq 0 ]
  [ -f "$repo/.agents/repository-context/directories.md" ]
}

@test "R2: starts with the header and an empty line" {
  touch a.txt
  generate
  [ "$(map | sed -n 1p)" = "# Repository structure" ]
  [ "$(map | sed -n 2p)" = "" ]
}

@test "R3: lists root files" {
  touch a.txt b.md
  generate
  entries | grep -qx "a.txt"
  entries | grep -qx "b.md"
}

@test "R3: lists tracked and hidden root files" {
  touch tracked.txt .env
  git add tracked.txt
  git -c user.name=t -c user.email=t@t commit -qm init
  generate
  entries | grep -qx "tracked.txt"
  entries | grep -qx ".env"
}

@test "R4: lists directories of any depth with a trailing slash" {
  mkdir -p one/two/three/four/five/six && touch one/two/three/four/five/six/f
  generate
  [ "$(entries)" = "$(printf '%s\n' 'one/' '  two/' '    three/' '      four/' '        five/' '          six/')" ]
}

@test "R4: lists hidden directories" {
  mkdir -p .github/workflows && touch .github/workflows/ci.yml
  generate
  entries | grep -qx ".github/"
  entries | grep -qx "  workflows/"
}

@test "R5: omits files below the root" {
  mkdir -p src/lib && touch src/main.py src/lib/util.py
  generate
  lacks "main.py"
  lacks "util.py"
}

@test "R6: indents two spaces per enclosing directory" {
  mkdir -p a/b/c && touch a/b/c/f top.txt
  generate
  [ "$(entries)" = "$(printf '%s\n' 'a/' '  b/' '    c/' 'top.txt')" ]
}

@test "R7: omits an ignored root directory and ignored root files" {
  mkdir -p build && touch build/out debug.log keep.txt
  printf '%s\n' "build/" "*.log" > .gitignore
  generate
  lacks "build"
  lacks "debug.log"
  entries | grep -qx "keep.txt"
}

@test "R7: honours nested .gitignore files" {
  mkdir -p src/cache && touch src/cache/f src/main.py
  echo "cache/" > src/.gitignore
  generate
  entries | grep -qx "src/"
  lacks "cache"
}

@test "R8: lists untracked paths that are not ignored" {
  mkdir -p new/deep && touch new/deep/f
  generate
  entries | grep -qx "new/"
  entries | grep -qx "  deep/"
}

@test "R9: omits the root .agents directory and its contents" {
  mkdir -p .agents/tests && touch .agents/tests/f
  generate
  lacks "agents"
  lacks "tests"
}

@test "R9: lists root paths whose names only start with .agents" {
  mkdir -p .agents-old agents && touch .agents-old/f agents/f .agents.txt
  generate
  entries | grep -qx ".agents-old/"
  entries | grep -qx "agents/"
  entries | grep -qx ".agents.txt"
}

@test "R10: same map from a subdirectory" {
  mkdir -p src/lib && touch src/lib/f top.txt
  generate
  from_root="$(map)"
  rm "$repo/.agents/repository-context/directories.md"
  (cd src/lib && generate)
  [ "$(map)" = "$from_root" ]
}

@test "R11: fails outside a git repository, reports on standard error and writes no map" {
  outside_repo
  run --separate-stderr env GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" sh .agents/repository-context/generate.sh
  [ "$status" -ne 0 ]
  [ -n "$stderr" ]
  [ ! -e "$outside/.agents/repository-context/directories.md" ]
}

@test "R12: places each directory's contents directly after it" {
  mkdir -p a/x b/y && touch a/x/f b/y/f
  generate
  [ "$(entries)" = "$(printf '%s\n' 'a/' '  x/' 'b/' '  y/')" ]
}

@test "R23: orders siblings by byte order, uppercase before lowercase" {
  mkdir -p b a && touch b/f a/f B.txt
  generate
  [ "$(entries)" = "$(printf '%s\n' 'B.txt' 'a/' 'b/')" ]
}

@test "R23: orders siblings by name, not by name with trailing slash" {
  mkdir -p a/x a-b && touch a/x/f a-b/f a.txt
  generate
  [ "$(entries)" = "$(printf '%s\n' 'a/' '  x/' 'a-b/' 'a.txt')" ]
}

@test "R13: lists nested directories named .agents" {
  mkdir -p src/.agents && touch src/.agents/f
  generate
  entries | grep -qx "  .agents/"
}

@test "R14: omits the .git directory" {
  touch a.txt
  generate
  lacks '\.git'
}

@test "R15: shows names with spaces and non-ASCII characters as is" {
  mkdir -p "my dir/sub dir" && touch "my dir/sub dir/f" "my file.txt" "café.txt"
  generate
  entries | grep -qx "my dir/"
  entries | grep -qx "  sub dir/"
  entries | grep -qx "my file.txt"
  entries | grep -qx "café.txt"
}

@test "R16: replaces an existing map" {
  touch a.txt
  echo "stale content" > "$repo/.agents/repository-context/directories.md"
  generate
  lacks "stale content"
  entries | grep -qx "a.txt"
}

@test "R17: writes only the header when nothing is listable" {
  generate
  [ "$(map)" = "# Repository structure" ]
  [ "$(map | awk 'END { print NR }')" -eq 2 ]
}

@test "R18: omits empty directories and directories holding only ignored files" {
  mkdir -p empty logs/old src && touch logs/old/a.log src/f
  echo "*.log" > .gitignore
  generate
  lacks "empty"
  lacks "logs"
  entries | grep -qx "src/"
}
