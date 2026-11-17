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
#                               A command that runs longer than DT_TIMEOUT seconds (default 60) is killed and the call
#                               returns 124, so a shell that waits for input fails its test instead of hanging the suite.
#   dt_pty [VAR=value ...] -- COMMAND [ARGS...]
#                               the same, under a pseudo-terminal (script -qec), so that a shell sees a tty
#   dt_realbin DIR [NAME...]    DIR holds a link to each base utility (default list: DT_BASE_UTILS) found at run time,
#                               so that a PATH of DIR alone gives the code under test the utilities it needs and no
#                               other tool: a stubbed tool cannot be found behind its stub. A missing name is skipped.
#   dt_pty_argv [VAR=value ...] -- COMMAND [ARGS...]
#                               build the command line of dt_pty in the array _dt_pty_argv without running it, for a
#                               caller that must hand an executable to another program (GNU time cannot run a function)
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
  timeout -k 5 "${DT_TIMEOUT:-60}" env -i PATH="${DT_PATH:-/usr/bin:/bin}" HOME="$DT_HOME" LANG="${DT_LANG:-C.UTF-8}" \
    "${_dt_vars[@]}" "${_dt_cmd[@]}" < /dev/null
}

dt_pty_argv() {
  local script_bin cmdline
  _dt_split_args "$@"
  [ -n "${DT_HOME:-}" ] || {
    printf 'dt_pty: DT_HOME is not set (call dt_scratch_home first)\n' >&2
    return 2
  }
  script_bin=${DT_TOOL_SCRIPT:-$(dt_find_tool script)} || return 2
  printf -v cmdline '%q ' "${_dt_cmd[@]}"
  # script reads the terminal side from /dev/null here: the child sees a tty on all three descriptors
  _dt_pty_argv=(timeout -k 5 "${DT_TIMEOUT:-60}" env -i PATH="${DT_PATH:-/usr/bin:/bin}" HOME="$DT_HOME" LANG="${DT_LANG:-C.UTF-8}"
    TERM="${DT_TERM:-xterm-256color}" "${_dt_vars[@]}" "$script_bin" -qec "$cmdline" /dev/null)
}

dt_pty() {
  dt_pty_argv "$@" || return $?
  "${_dt_pty_argv[@]}" < /dev/null
}

# The utilities that scripts and shell startup files use, as the old harness listed them, plus the ones the new tests call.
DT_BASE_UTILS=(awk basename bash cat chmod cksum cmp comm cp cut date diff dircolors dirname env find git grep gzip head id install jq ln ls
  mkdir mktemp mv readlink realpath rm sed sh sha256sum sleep sort stat tail tar tee timeout touch tr uniq wc xargs)

dt_realbin() {
  local dir=${1:?dt_realbin DIR} name path
  shift
  local names=("$@")
  [ "${#names[@]}" -gt 0 ] || names=("${DT_BASE_UTILS[@]}")
  mkdir -p -- "$dir"
  for name in "${names[@]}"; do
    if path=$(dt_find_tool "$name" 2> /dev/null); then
      ln -sfn -- "$(readlink -f "$path")" "$dir/$name"
    fi
  done
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
