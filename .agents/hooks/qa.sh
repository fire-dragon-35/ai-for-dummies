#!/bin/sh
# shellcheck disable=SC1091,SC2154
. "$(dirname "$0")/common.sh"
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars)
cd "$hooks/../.." || exit 1
state="$(git rev-parse --git-common-dir)/ai-for-dummies"
lock="$state/qa.lock"
mkdir -p "$state" || exit 1
if ! mkdir "$lock" 2> /dev/null; then
  if kill -0 "$(cat "$lock/pid" 2> /dev/null)" 2> /dev/null; then
    : > "$state/qa.again"
    exit 0
  fi
  rm -rf "$lock"
  mkdir "$lock" || exit 1
fi
echo "$$" > "$lock/pid"
reports=$(mktemp -d) || exit 1
trap 'rm -rf "$lock" "$reports"' EXIT
status=0

report() {
  if [ -z "$3" ]; then
    mark pass "$1" "$2"
  else
    mark fail "$1" "$(printf '%s\n' "$3" | sed '/^$/d' | paste -sd, - | cut -c1-200)"
    status=1
  fi
}

run_checks() {
  started=$(date +%s)
  stale=
  for d in .agents/tests/*/; do
    d=${d%/}
    [ -d "$d" ] || continue
    [ "$(cat "$d/reviewed" 2> /dev/null)" = "$(sh "$hooks/fingerprint.sh" "$d")" ] || stale="$stale$d needs a review
"
  done
  set --
  set -f
  IFS='
'
  checked=0
  scripts=0
  long=
  comments=
  for f in $(git -c core.quotePath=false ls-files --cached --others --exclude-standard | grep -v '^\.agents/skills/'); do
    [ -f "$f" ] || continue
    checked=$((checked + 1))
    lines=$(awk 'END { print NR }' "$f")
    [ "$lines" -le 400 ] || long="$long$f ($lines lines)
"
    case $f in
      *.sh | .agents/hooks/*)
        module=0
        set -- "$@" "$f"
        ;;
      *.mjs) module=1 ;;
      *) continue ;;
    esac
    scripts=$((scripts + 1))
    if awk -v module="$module" 'NR == 1 && /^#!/ { next } !module && /^[ \t]*# shellcheck / { next } !module && /^[ \t]*#/ { found = 1 } module && /^[ \t]*(\/\/|\/\*)/ { found = 1 } END { exit !found }' "$f"; then
      comments="$comments$f
"
    fi
  done
  unset IFS
  set +f
  findings=
  if [ $# -gt 0 ] && ! findings=$(run_shellcheck -f gcc "$@" 2>&1); then
    findings="${findings:-shellcheck failed}"
  fi
  report "reviewed tests" "up to date" "$stale"
  report "no comments" "$scripts script files" "$comments"
  report "line limit" "$checked files" "$long"
  report "shellcheck" "$# shell files" "$findings"
  log_duration checks "$started"
}

run_tests() {
  [ -d .agents/tests ] || return 0
  set -- --formatter tap --report-formatter tap -o "$reports" -r .agents/tests
  ! command -v parallel > /dev/null 2>&1 || set -- --jobs "$(getconf _NPROCESSORS_ONLN)" "$@"
  [ -t 2 ] && terminal=1 || terminal=0
  started=$(date +%s)
  { npx --yes bats@1.13.0 "$@"; echo "$?" > "$reports/status"; } | awk -v terminal="$terminal" -v counts="$reports/counts" '
    function paint(text, color) { return terminal ? "\033[" color "m" text "\033[0m" : text }
    function progress(mark) {
      if (column == 0) printf "  "
      printf "%s", mark
      if (++column == 60) { printf "\n"; column = 0 }
      fflush()
    }
    /^not ok / { failing = 1; failed++; name = $0; sub(/^not ok [0-9]+ /, "", name); details = details "\n  " paint("F " name, 31); progress(paint("F", 31)); next }
    /^ok .* # skip/ { failing = 0; skipped++; progress(paint("s", 33)); next }
    /^ok / { failing = 0; passed++; progress(paint(".", 32)); next }
    /^#/ && failing { details = details "\n    " substr($0, 3); next }
    { failing = 0 }
    END {
      if (column) printf "\n"
      if (details != "") print substr(details, 2)
      print passed + 0, failed + 0, skipped + 0 > counts
    }
  ' >&2
  [ "$(cat "$reports/status")" -eq 0 ] || status=1
  read -r passed failed skipped < "$reports/counts"
  summary="$passed pass, $failed fail, $skipped skip in $(($(date +%s) - started)) s"
  [ "$terminal" -eq 0 ] || summary="\033[$([ "$status" -eq 0 ] && echo 32 || echo 31)m$summary\033[0m"
  printf '  %b\n' "$summary" >&2
  log_duration tests "$started"
  grep -E '^(not )?ok [0-9]+ ' "$reports/report.tap" | while IFS= read -r line; do
    case $line in
      "not ok"*) result=fail ;;
      *"# skip"*) result=skip ;;
      *) result=pass ;;
    esac
    sh "$metrics/log.sh" test "$(printf '%s\n' "$line" | sed -E 's/^(not )?ok [0-9]+ //; s/ # skip.*$//')" "$result" "$started"
  done
}

run_project_tests() {
  [ -f .agents/test-command ] || return 0
  command=$(cat .agents/test-command)
  if output=$(sh -c "$command" 2>&1); then
    report "project tests" "$command" ""
  else
    code=$?
    report "project tests" "$command" "$(printf '%s\n' "$output" | tail -n 4)
exit status $code"
  fi
}

while :; do
  rm -f "$state/qa.again" "$reports/status" "$reports/counts"
  status=0
  run_checks
  run_tests
  run_project_tests
  [ -e "$state/qa.again" ] || break
done
exit "$status"
