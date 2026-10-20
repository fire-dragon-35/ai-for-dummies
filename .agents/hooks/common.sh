#!/bin/sh
export npm_config_progress=false
export npm_config_prefer_offline=true
metrics="$(dirname "$0")/../metrics"
mark() {
  if [ "$1" = pass ]; then
    symbol='✓'
    color=32
  else
    symbol='✗'
    color=31
  fi
  [ ! -t 2 ] || symbol="\033[${color}m$symbol\033[0m"
  printf '  %b %-15s %s\n' "$symbol" "$2" "$3" >&2
  [ ! -f "$metrics/log.sh" ] || sh "$metrics/log.sh" check "$2" "$1" "$3" ".agents/hooks/$(basename "$0")"
}
log_duration() {
  [ ! -f "$metrics/log.sh" ] || sh "$metrics/log.sh" duration "$1" "$(($(date +%s) - $2))"
}
run_shellcheck() {
  if command -v shellcheck > /dev/null 2>&1; then
    shellcheck "$@"
  else
    npx --yes shellcheck@4.1.0 "$@"
  fi
}
