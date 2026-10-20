#!/bin/sh
staged=0
if [ "$1" = --staged ]; then
  staged=1
  shift
fi
component=${1%/}
if [ -z "$component" ]; then
  echo "usage: sh fingerprint.sh [--staged] <component>" >&2
  exit 2
fi
if [ "$staged" -eq 1 ]; then
  git ls-files -s -z -- "$component/" | tr '\0' '\n' | awk -v prefix="$component/" '
    { split($0, parts, "\t"); split(parts[1], meta, " "); path = substr(parts[2], length(prefix) + 1)
      if (path != "reviewed") print "./" path " " meta[2] }'
else
  (cd "$component" && find . -type f ! -path ./reviewed | while IFS= read -r f; do
    printf '%s %s\n' "$f" "$(git hash-object "$f")"
  done)
fi | LC_ALL=C sort | git hash-object --stdin
