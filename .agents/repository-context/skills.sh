#!/bin/sh
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root" || exit 1
start='<!-- ai-for-dummies:start -->'
end='<!-- ai-for-dummies:end -->'
grep -qxF "$start" AGENTS.md 2>/dev/null || exit 0
table=$(
  echo "## Skills"
  echo "Read a skill's file when its use matches the task"
  echo ""
  echo "| Skill | Use it when | File |"
  echo "|---|---|---|"
  find .agents/skills -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
    awk -v path="$f" '
      NR == 1 && $0 == "---" { front = 1; next }
      front && $0 == "---" { exit }
      front && /^name:/ { sub(/^name:[ \t]*/, ""); gsub(/^["\047]|["\047]$/, ""); name = $0 }
      front && /^description:/ { sub(/^description:[ \t]*/, ""); gsub(/^["\047]|["\047]$/, ""); description = $0 }
      END {
        if (name == "") { n = split(path, parts, "/"); name = parts[n - 1] }
        gsub(/\|/, "\\|", description)
        printf "| %s | %s | `%s` |\n", name, description, path
      }' "$f"
  done
)
updated=$(TABLE=$table awk -v start="$start" -v end="$end" '
  $0 == start { inside = 1 }
  inside && $0 == "## Skills" { skip = 1; next }
  inside && $0 == end { print ENVIRON["TABLE"]; skip = 0; inside = 0 }
  !skip { print }' AGENTS.md) || exit 1
printf '%s\n' "$updated" > AGENTS.md
