# shellcheck shell=bash
# Runs once before the first test (tests/run.sh passes it with --setup-suite-file, because bats looks
# for setup_suite.bash in the directory of the first test file only).
# It resolves the tools once, with the home of the caller, and checks that the libraries are fetched.
# What it exports reaches every test, including the parallel ones.

setup_suite() {
  local here lib
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
  # shellcheck source=/dev/null
  . "$here/../common.sh"
  if [ -z "${DT_TOOLS_RESOLVED:-}" ]; then
    dt_resolve_tools
  fi
  for lib in bats-support bats-assert bats-file; do
    if [ ! -f "$DT_TESTS_DIR/.lib/$lib/load.bash" ]; then
      printf 'setup_suite: %s is not fetched: run mise run test:deps\n' "$lib" >&2
      return 1
    fi
  done
}
