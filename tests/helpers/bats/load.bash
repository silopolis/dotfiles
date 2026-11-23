# shellcheck shell=bash
# Bats glue, the only place that knows about bats: every test file starts with
#   load ../helpers/bats/load
# (the path is relative to the test file). It loads the pinned libraries and the plain helpers of
# tests/helpers/*.sh, and turns what a helper returns into a skip that names what is missing.
#
# Provides:
#   require_tool NAME...       skip, naming the tool, when it is absent; sets DT_TOOL_<NAME>
#   require_shell SHELL        skip, naming the build, when zsh, bash or brewbash is absent; sets DT_SHELL
#   require_live               skip unless DOTFILES_TEST_LIVE=1
#   require_base_ref           skip unless DOTFILES_TEST_BASE_REF is set
#   setup_scratch              a scratch home below BATS_TEST_TMPDIR (DT_HOME) and a default DT_PATH
#
# A skip leaves the function it is called from, so call the require_* functions from a test, from
# setup or from a function the test calls, never inside a command substitution or a pipe.
# A missing library is not a skip: bats_load_library fails the file at load.

DT_BATS_GLUE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=/dev/null
. "$DT_BATS_GLUE_DIR/../common.sh"
# shellcheck source=/dev/null
. "$DT_BATS_GLUE_DIR/../scratch.sh"
# shellcheck source=/dev/null
. "$DT_BATS_GLUE_DIR/../synth.sh"
# shellcheck source=/dev/null
. "$DT_BATS_GLUE_DIR/../fixtures.sh"
# shellcheck source=/dev/null
. "$DT_BATS_GLUE_DIR/../render.sh"
# shellcheck source=/dev/null
. "$DT_BATS_GLUE_DIR/../compare.sh"
# shellcheck source=/dev/null
. "$DT_BATS_GLUE_DIR/../kinds.sh"
# shellcheck source=/dev/null
. "$DT_BATS_GLUE_DIR/../timing.sh"
# shellcheck source=/dev/null
. "$DT_BATS_GLUE_DIR/../script-fixtures.sh"

BATS_LIB_PATH="$DT_TESTS_DIR/.lib${BATS_LIB_PATH:+:$BATS_LIB_PATH}"
export BATS_LIB_PATH
bats_load_library bats-support
bats_load_library bats-assert
bats_load_library bats-file

require_tool() {
  local name var path
  for name in "$@"; do
    var=DT_TOOL_$(printf '%s' "${name^^}" | tr -c 'A-Z0-9\n' '_')
    if [ -n "${DT_TOOLS_RESOLVED:-}" ] && [[ " ${DT_KNOWN_TOOLS[*]} " == *" $name "* ]]; then
      path=${!var:-}
    else
      path=$(dt_find_tool "$name" 2> /dev/null) || path=
    fi
    if [ -z "$path" ] || [ ! -x "$path" ]; then
      skip "tool $name is not installed"
    fi
    export "$var=$path"
  done
}

require_shell() {
  local path
  if ! path=$(dt_shell_path "$1" 2> /dev/null); then
    case $1 in
      brewbash) skip "shell build brewbash (a Homebrew bash) is not installed" ;;
      *) skip "shell build $1 is not installed" ;;
    esac
  fi
  DT_SHELL=$path
  export DT_SHELL
}

require_live() {
  if [ "${DOTFILES_TEST_LIVE:-}" != 1 ]; then
    skip "reads this machine: set DOTFILES_TEST_LIVE=1 to run it"
  fi
}

require_base_ref() {
  if [ -z "${DOTFILES_TEST_BASE_REF:-}" ]; then
    skip "compares with another ref: set DOTFILES_TEST_BASE_REF=<ref> to run it"
  fi
}

setup_scratch() {
  dt_scratch_home "$BATS_TEST_TMPDIR" > /dev/null
  DT_PATH=${DT_PATH:-/usr/bin:/bin}
  export DT_PATH
}
