#!/bin/sh
component=${1%/}
if [ -z "$component" ]; then
  echo "usage: sh fingerprint.sh <component>" >&2
  exit 2
fi
root=$(git -C "$component" rev-parse --show-toplevel) || exit 1
{
  (cd "$component" && find . -type f ! -path ./reviewed | while IFS= read -r f; do
    printf '%s %s\n' "$f" "$(git hash-object "$f")"
  done)
  [ ! -f "$component/tests" ] || grep -v '^[[:space:]]*$' "$component/tests" | while IFS= read -r f; do
    printf '/%s %s\n' "$f" "$(git hash-object "$root/$f" 2> /dev/null || echo missing)"
  done
} | LC_ALL=C sort | git hash-object --stdin
