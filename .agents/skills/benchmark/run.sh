#!/bin/sh
skill=$(cd "$(dirname "$0")" && pwd)
package=$(cd "$skill/../../.." && pwd)
runs=3
task=todo
prompt=
claude=claude
usage() {
  echo "usage: sh run.sh [--task <task>] [--runs <n>] [--prompt <text>] [--claude <command>]" >&2
  exit 2
}
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || usage
  case $1 in
    --task) task=$2 ;;
    --runs) runs=$2 ;;
    --prompt) prompt=$2 ;;
    --claude) claude=$2 ;;
    *) usage ;;
  esac
  shift 2
done
case $runs in '' | *[!0-9]*) usage ;; esac
[ "$runs" -gt 0 ] || usage
[ ! -d "$skill/tasks/$task" ] || task="$skill/tasks/$task"
if [ -z "$prompt" ]; then
  if [ ! -f "$task/prompt.md" ]; then
    echo "the task $task has no prompt.md" >&2
    exit 2
  fi
  prompt=$(cat "$task/prompt.md")
fi
dir=$(mktemp -d "${TMPDIR:-/tmp}/ai-for-dummies-benchmark.XXXXXX") || exit 1
echo "runs in $dir"
names=
for i in $(seq "$runs"); do names="$names with-$i without-$i"; done
for name in $names; do
  mkdir "$dir/$name" && git -C "$dir/$name" init -q || exit 1
  case $name in with-*) sh "$package/install.sh" --hooks "$dir/$name" > /dev/null || exit 1 ;; esac
  git -C "$dir/$name" add -A || exit 1
  git -C "$dir/$name" -c core.hooksPath=/dev/null -c user.name=benchmark -c user.email=benchmark@localhost commit -q --allow-empty -m setup || exit 1
done
for name in $names; do
  (cd "$dir/$name" && "$claude" -p "$prompt" --output-format json --dangerously-skip-permissions --max-budget-usd 10 > "$dir/$name.json" 2>&1) &
done
wait
if [ -f "$task/acceptance.mjs" ]; then
  for name in $names; do
    node "$task/acceptance.mjs" "$dir/$name" > "$dir/$name.acceptance" 2>&1
  done
fi
if [ -f "$task/review.md" ]; then
  mkdir "$dir/review" || exit 1
  i=0
  for name in $(printf '%s\n' $names | shuf); do
    i=$((i + 1))
    copy="$dir/review/$i"
    mkdir "$copy" || exit 1
    git -C "$dir/$name" ls-files --cached --others --exclude-standard | grep -vE '^(\.agents/|\.claude/|node_modules/|AGENTS\.md$|CLAUDE\.md$)' | while IFS= read -r f; do
      mkdir -p "$copy/$(dirname "$f")" && cp "$dir/$name/$f" "$copy/$f"
    done
    echo "$i $name" >> "$dir/review/key"
    (cd "$copy" && "$claude" -p "$(cat "$task/review.md")" --output-format json --dangerously-skip-permissions --max-budget-usd 5 > "$dir/review/$i.json" 2>&1) &
  done
  wait
fi
# shellcheck disable=SC2086
node "$skill/tally.mjs" "$dir" "$task" $names
