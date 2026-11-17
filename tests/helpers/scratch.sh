#!/usr/bin/env bash
# Scratch directories and the runners that start the code under test: plain bash, no bats.
# Source it (`. tests/helpers/scratch.sh`); it needs common.sh and loads it.
#
# Provides:
#   dt_scratch_home BASE        make BASE/home (mode 0700), set and print DT_HOME
#   dt_clean [VAR=value ...] -- COMMAND [ARGS...]
#                               run COMMAND under `env -i` with PATH (DT_PATH, default /usr/bin:/bin),
#                               HOME (DT_HOME), LANG (DT_LANG, default C.UTF-8) and the named variables,
#                               standard input from /dev/null
#   dt_pty [VAR=value ...] -- COMMAND [ARGS...]
#                               the same, under a pseudo-terminal (script -qec), so that a shell sees a tty
#   dt_suite_copy DEST          a minimal copy of the suite (run.sh, helpers, a link to the fetched libraries,
#                               an empty tests/unit) in DEST, for a test that runs the runner itself
#
# Nothing here reads or writes the real home: HOME is always a scratch directory the caller made.

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

dt_scratch_home() {
  local base=${1:?dt_scratch_home BASE}
  mkdir -p -- "$base"
  [ -d "$base/home" ] || mkdir -m 0700 -- "$base/home"
  DT_HOME=$base/home
  export DT_HOME
  printf '%s\n' "$DT_HOME"
}

# The command line of dt_clean and dt_pty: variables until `--`, then the command.
_dt_split_args() {
  _dt_vars=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do
    _dt_vars+=("$1")
    shift
  done
  [ "${1:-}" = -- ] && shift
  _dt_cmd=("$@")
}

dt_clean() {
  _dt_split_args "$@"
  [ -n "${DT_HOME:-}" ] || {
    printf 'dt_clean: DT_HOME is not set (call dt_scratch_home first)\n' >&2
    return 2
  }
  env -i PATH="${DT_PATH:-/usr/bin:/bin}" HOME="$DT_HOME" LANG="${DT_LANG:-C.UTF-8}" \
    "${_dt_vars[@]}" "${_dt_cmd[@]}" < /dev/null
}

dt_pty() {
  local script_bin cmdline
  _dt_split_args "$@"
  [ -n "${DT_HOME:-}" ] || {
    printf 'dt_pty: DT_HOME is not set (call dt_scratch_home first)\n' >&2
    return 2
  }
  script_bin=$(dt_find_tool script) || return 2
  printf -v cmdline '%q ' "${_dt_cmd[@]}"
  # script reads the terminal side from /dev/null here: the child sees a tty on all three descriptors
  env -i PATH="${DT_PATH:-/usr/bin:/bin}" HOME="$DT_HOME" LANG="${DT_LANG:-C.UTF-8}" TERM="${DT_TERM:-xterm-256color}" \
    "${_dt_vars[@]}" "$script_bin" -qec "$cmdline" /dev/null < /dev/null
}

dt_suite_copy() {
  local dest=${1:?dt_suite_copy DEST}
  mkdir -p -- "$dest/tests/unit"
  cp -a -- "$DT_TESTS_DIR/run.sh" "$DT_TESTS_DIR/helpers" "$dest/tests/"
  ln -s -- "$DT_TESTS_DIR/.lib" "$dest/tests/.lib"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn=${1:?usage: scratch.sh <function> [args...]}
  shift
  "$fn" "$@"
fi
