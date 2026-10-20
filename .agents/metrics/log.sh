#!/bin/sh
if [ $# -lt 3 ]; then
  echo "usage: sh log.sh <kind> <name> <result> [detail] [source]" >&2
  exit 2
fi
common=$(git rev-parse --git-common-dir) || exit 1
tab=$(printf '\t')
escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$tab/\\\\t/g"
}
mkdir -p "$common/ai-for-dummies" || exit 1
source=
[ -z "$5" ] || source=",\"source\":\"$(escape "$5")\""
printf '{"time":"%s","kind":"%s","name":"%s","result":"%s","detail":"%s"%s}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(escape "$1")" "$(escape "$2")" "$(escape "$3")" "$(escape "$4")" "$source" \
  >> "$common/ai-for-dummies/metrics.jsonl"
