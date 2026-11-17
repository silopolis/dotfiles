#!/usr/bin/env bash
# Run the test suite: `mise run test`, or tests/run.sh [bats options] [paths]
#
# Runs the unit and smoke levels (a level without a test file is left out), or the files and
# directories named on the command line, with bats and its JUnit formatter, then prints the numbers
# of tests, failures and skips and scans the report and the output for canary values.
#
#   DOTFILES_TEST_LIVE=1     also run the tests that read this machine (serial: `mise run test:live`)
#   DOTFILES_TEST_SOURCE     the tree under test (default: this repository), used by the mutants
#   DOTFILES_TEST_TMPDIR     where the scratch directory of the run is made (default: TMPDIR, then /tmp)
#   DOTFILES_TEST_REPORTS    where the report and the output are written (default: tests/.reports)
#
# The suite never touches the real home: bats runs with a scratch HOME and a scratch TMPDIR, the
# exported variables whose names match the secret pattern are removed from its environment (the names
# are computed here and never printed), and GNU parallel is silenced for this process only.
# Exit status: bats's, or 1 when a canary appears in the report or the output.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=/dev/null
. "$here/helpers/common.sh"
# shellcheck source=/dev/null
. "$here/helpers/synth.sh"

die() {
  printf 'run.sh: %s\n' "$*" >&2
  exit 2
}

# Paths on the command line are made absolute before the directory changes; everything else is a bats option.
opts=()
paths=()
for arg in "$@"; do
  if [ -e "$arg" ]; then
    paths+=("$(realpath -- "$arg")")
  else
    opts+=("$arg")
  fi
done

cd "$DT_ROOT"
real_home=$HOME
real_config=${XDG_CONFIG_HOME:-$HOME/.config}
# Counts of the secret-like names of the real environment, taken before anything is hidden; only the live tests read them.
read -r real_upper real_any < <(dt_secret_name_counts)

runner_bin=${DT_TOOL_BATS:-}
if [ -z "$runner_bin" ] || [ ! -x "$runner_bin" ]; then
  runner_bin=$(dt_find_tool bats 2> /dev/null) || die 'bats is not installed: run mise install'
fi
for lib in bats-support bats-assert bats-file; do
  [ -n "$(ls -A "$DT_TESTS_DIR/.lib/$lib" 2> /dev/null)" ] || die "$lib is not fetched: run mise run test:deps"
done

# The tools are looked up here, with the real home, before bats gets a scratch one.
dt_resolve_tools

if [ "${#paths[@]}" -eq 0 ]; then
  for level in unit smoke; do
    if [ -d "$DT_TESTS_DIR/$level" ] && [ -n "$(find "$DT_TESTS_DIR/$level" -name '*.bats' -print -quit)" ]; then
      paths+=("$DT_TESTS_DIR/$level")
    fi
  done
fi
[ "${#paths[@]}" -gt 0 ] || die 'no test file found'

# One job when the tests read this machine (the timing tests share it with nothing) or without GNU parallel.
jobs=1
if [ "${DOTFILES_TEST_LIVE:-}" = 1 ]; then
  :
elif command -v parallel > /dev/null 2>&1; then
  jobs=$(dt_jobs)
else
  printf 'run.sh: GNU parallel not found, running serially\n' >&2
fi
printf 'jobs: %s\n' "$jobs"

base=${DOTFILES_TEST_TMPDIR:-${TMPDIR:-/tmp}}
scratch=$(mktemp -d "$base/dotfiles-tests.XXXXXX")
# shellcheck disable=SC2329  # called by the EXIT trap below
cleanup() {
  case $scratch in
    "$base"/dotfiles-tests.*) rm -rf -- "$scratch" ;;
  esac
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -m 0700 -- "$scratch/home" "$scratch/tmp"

# The list of canaries of this run, for the scan; and the variables that are not handed to bats.
(umask 077 && dt_all_canaries > "$scratch/canaries")
hide=()
while IFS= read -r name; do
  [ -n "$name" ] && hide+=(-u "$name")
done < <(dt_secret_names)
hide+=(-u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_CACHE_HOME -u XDG_STATE_HOME)

reports=${DOTFILES_TEST_REPORTS:-$DT_TESTS_DIR/.reports}
mkdir -p -- "$reports"
rm -f -- "$reports/report.xml" "$reports/output.txt"

set +e
env "${hide[@]}" \
  HOME="$scratch/home" TMPDIR="$scratch/tmp" PARALLEL=--will-cite \
  DOTFILES_TEST_REAL_HOME="$real_home" DOTFILES_TEST_REAL_CONFIG="$real_config" \
  DT_REAL_SECRET_UPPER="$real_upper" DT_REAL_SECRET_ANY="$real_any" \
  "$runner_bin" --report-formatter junit --output "$reports" \
  --setup-suite-file "$DT_HELPERS_DIR/bats/setup_suite.bash" \
  --jobs "$jobs" --formatter tap -r "${opts[@]}" "${paths[@]}" 2>&1 \
  | tee "$scratch/raw.txt" | grep -v --line-buffered -F -f "$scratch/canaries" | tee "$reports/output.txt"
status=${PIPESTATUS[0]}
set -e

report=$reports/report.xml
if [ -f "$report" ]; then
  tests=$(grep -c '<testcase' "$report" || true)
  failures=$(grep -c '<failure' "$report" || true)
  skipped=$(grep -c '<skipped' "$report" || true)
  printf 'tests: %s, failures: %s, skipped: %s\n' "$tests" "$failures" "$skipped"
else
  printf 'run.sh: bats wrote no report\n' >&2
  [ "$status" -ne 0 ] || status=1
fi

# A canary in the report or in the output is a leak: print the number of matches, never the value.
# The lines of the output that hold one were dropped from what is shown and kept (raw.txt) only for this count.
leaks=0
for f in "$report" "$scratch/raw.txt"; do
  if [ -f "$f" ]; then
    n=$(grep -c -F -f "$scratch/canaries" "$f" || true)
    leaks=$((leaks + n))
  fi
done
printf 'canary scan: %s matches\n' "$leaks"
if [ "$leaks" -ne 0 ]; then
  exit 1
fi
exit "$status"
