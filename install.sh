#!/bin/sh
update=0
hooks=0
name=
for arg; do
  case $arg in
    --update) update=1 ;;
    --hooks) hooks=1 ;;
    -*) name=--usage ;;
    *) [ -z "$name" ] && name=$arg || name=--usage ;;
  esac
done
if [ -z "$name" ] || [ "$name" = --usage ]; then
  echo "usage: sh install.sh [--update] [--hooks] <target-repository>" >&2
  exit 2
fi
source=$(cd "$(dirname "$0")" && pwd) || exit 1
target=$(cd "$name" 2>/dev/null && pwd -P)
if [ -z "$target" ] || [ "$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)" != "$target" ]; then
  echo "$name is not the top-level directory of a git repository" >&2
  exit 1
fi
start='<!-- ai-for-dummies:start -->'
end='<!-- ai-for-dummies:end -->'
if grep -qxF "$start" "$target/AGENTS.md" 2>/dev/null; then
  if [ "$update" -eq 0 ]; then
    echo "The agent setup is already installed in $name: AGENTS.md contains the ai-for-dummies block. Use --update" >&2
    exit 1
  fi
elif [ "$update" -eq 1 ]; then
  echo "The agent setup is not installed in $name: run without --update" >&2
  exit 1
fi
new_hooks=$hooks
old_hooks=0
if [ "$update" -eq 1 ]; then
  [ ! -e "$target/.agents/hooks/pre-commit" ] || old_hooks=1
  if [ -e "$target/.agents/hooks/post-commit" ]; then
    hooks=1
    new_hooks=0
  elif [ "$old_hooks" -eq 1 ] || [ -d "$target/.agents/metrics" ]; then
    hooks=1
    new_hooks=1
  fi
fi
if [ "$new_hooks" -eq 1 ]; then
  existing=$(git -C "$target" config --local --get core.hooksPath)
  if [ -n "$existing" ] && { [ "$old_hooks" -eq 0 ] || [ "$existing" != .agents/hooks ]; }; then
    echo "core.hooksPath is already set to $existing in $name. Install without --hooks" >&2
    exit 1
  fi
  hook="$(git -C "$target" rev-parse --path-format=absolute --git-common-dir)/hooks/post-commit"
  if [ -e "$hook" ]; then
    echo "The repository already has the git hook $hook, so --hooks would replace it" >&2
    exit 1
  fi
fi
cd "$source" || exit 1
files=$(echo .claude/skills
  find .agents/skills -type f ! -path '.agents/skills/metrics/*' ! -path '.agents/skills/benchmark/*'
  echo .agents/repository-context/generate.sh
  echo .agents/repository-context/skills.sh
  [ "$update" -eq 1 ] || echo .agents/web-sources.md
  [ "$hooks" -eq 0 ] || find .agents/hooks .agents/metrics .agents/skills/metrics -type f)
set -f
IFS='
'
if [ "$update" -eq 0 ]; then
  conflict=0
  for f in $files; do
    if [ -e "$target/$f" ] || [ -L "$target/$f" ]; then
      echo "$f already exists in $name" >&2
      conflict=1
    fi
  done
  [ "$conflict" -eq 0 ] || exit 1
fi
for f in $files; do
  mkdir -p "$target/$(dirname "$f")" && rm -f "$target/$f" && cp -P "$f" "$target/$f" || exit 1
done
end_line() {
  if [ -s "$1" ] && [ -n "$(tail -c 1 "$1")" ]; then
    echo >> "$1"
  fi
}
if [ "$update" -eq 1 ]; then
  replaced=$(awk -v start="$start" -v end="$end" -v block="$source/AGENTS.md" '
    BEGIN { while ((getline line < block) > 0) { if (line == start) copy = 1; if (copy) text = text line "\n"; if (line == end) copy = 0 } }
    $0 == start && !done { printf "%s", text; skip = 1; next }
    skip { if ($0 == end) { skip = 0; done = 1 } next }
    { print }' "$target/AGENTS.md") || exit 1
  printf '%s\n' "$replaced" > "$target/AGENTS.md"
else
  if [ -e "$target/AGENTS.md" ]; then
    end_line "$target/AGENTS.md"
  else
    echo "# AGENTS.md" > "$target/AGENTS.md"
  fi
  echo >> "$target/AGENTS.md"
  awk -v start="$start" -v end="$end" '$0 == start, $0 == end' AGENTS.md >> "$target/AGENTS.md"
fi
if ! grep -qxF '@AGENTS.md' "$target/CLAUDE.md" 2>/dev/null; then
  if [ -s "$target/CLAUDE.md" ]; then
    end_line "$target/CLAUDE.md"
    echo >> "$target/CLAUDE.md"
  fi
  printf '%s\n' "$start" '@AGENTS.md' "$end" >> "$target/CLAUDE.md"
fi
(cd "$target" && sh .agents/repository-context/skills.sh && sh .agents/repository-context/generate.sh) || exit 1
if [ "$old_hooks" -eq 1 ]; then
  rm -f "$target/.agents/hooks/pre-commit" "$target/.agents/hooks/pre-push" "$target/.github/workflows/agents.yml"
  rmdir "$target/.github/workflows" "$target/.github" 2> /dev/null
  [ "$(git -C "$target" config --local --get core.hooksPath)" != .agents/hooks ] || git -C "$target" config --local --unset core.hooksPath || exit 1
fi
if [ "$new_hooks" -eq 1 ]; then
  mkdir -p "$(dirname "$hook")" || exit 1
  # shellcheck disable=SC2016
  printf '%s\n' '#!/bin/sh' 'exec sh "$(git rev-parse --show-toplevel)/.agents/hooks/post-commit"' > "$hook" && chmod +x "$hook" || exit 1
fi
if [ "$update" -eq 1 ]; then
  printf "Updated the agent setup in %s\nNext, commit the changes: git add . && git commit\n" "$name"
else
  printf "Installed the agent setup in %s\nNext, commit the added files: git add . && git commit\n" "$name"
fi
