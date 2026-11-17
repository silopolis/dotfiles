#!/usr/bin/env bash
# Timing of a command: plain bash, no bats. Source it (`. tests/helpers/timing.sh`; it loads common.sh), or call
# one function: tests/helpers/timing.sh <function> [args...]
#
# Provides:
#   dt_elapsed COMMAND [ARGS...]   print the elapsed seconds of an executable command, its output discarded: GNU time,
#                                  called by path because `time` is a reserved word in bash and zsh (dt_gnu_time finds
#                                  it at run time), or `date +%s.%N` around the command when there is none
#   dt_median NUMBER...            print the median of the numbers (the upper one for an even count)
#   dt_timing_tool                 print `gnu-time` or `date`: the tool dt_elapsed uses

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

dt_timing_tool() {
  if dt_gnu_time > /dev/null 2>&1; then
    printf 'gnu-time\n'
  else
    printf 'date\n'
  fi
}

dt_elapsed() {
  local gt out start end
  if gt=$(dt_gnu_time 2> /dev/null); then
    out=$(mktemp "${TMPDIR:-/tmp}/dt-elapsed.XXXXXX")
    "$gt" -q -f %e -o "$out" -- "$@" > /dev/null 2>&1 < /dev/null || true
    cat "$out"
    rm -f -- "$out"
  else
    start=$(date +%s.%N)
    "$@" > /dev/null 2>&1 < /dev/null || true
    end=$(date +%s.%N)
    awk -v a="$start" -v b="$end" 'BEGIN { printf "%.3f\n", b - a }'
  fi
}

dt_median() {
  printf '%s\n' "$@" | sort -n | awk '{ a[NR] = $1 } END { print a[int((NR + 2) / 2)] }'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn=${1:?usage: timing.sh <function> [args...]}
  shift
  "$fn" "$@"
fi
