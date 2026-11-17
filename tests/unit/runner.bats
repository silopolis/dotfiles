#!/usr/bin/env bats
# The behaviour of tests/run.sh, on scratch copies of the suite that hold one tiny test file each.

load ../helpers/bats/load

setup() {
  setup_scratch
  require_tool bats
  copy=$BATS_TEST_TMPDIR/suite
  dt_suite_copy "$copy"
}

# run_copy [VAR=value ...]: the runner of the copy under env -i, from $RUN_FROM (default: the copy).
run_copy() {
  (cd "${RUN_FROM:-$copy}" && env -i PATH="$PATH" HOME="$DT_HOME" DT_TOOL_BATS="$DT_TOOL_BATS" \
    DOTFILES_TEST_TMPDIR="$BATS_TEST_TMPDIR" "$@" "$copy/tests/run.sh")
}

passing_test() {
  printf '@test "passes" {\n  true\n}\n@test "skips" {\n  skip "tool demo is not installed"\n}\n' > "$copy/tests/unit/ok.bats"
}

@test "a green run exits 0 and writes a report that parses" {
  require_tool python3
  passing_test
  run run_copy
  assert_success
  assert_output --partial 'tests: 2, failures: 0, skipped: 1'
  run "$DT_TOOL_PYTHON3" -c 'import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])' "$copy/tests/.reports/report.xml"
  assert_success
  assert_equal "$(grep -c '<testcase' "$copy/tests/.reports/report.xml")" 2
}

@test "a failing test fails the run and the report holds exactly one failure" {
  printf '@test "fails on purpose" {\n  false\n}\n@test "passes" {\n  true\n}\n' > "$copy/tests/unit/bad.bats"
  run run_copy
  assert_failure
  assert_output --partial 'failures: 1'
  assert_equal "$(grep -c '<failure' "$copy/tests/.reports/report.xml")" 1
}

@test "the numbers are the same from the root, from a test directory and from a distant directory" {
  passing_test
  local from out
  for from in "$copy" "$copy/tests/unit" /; do
    RUN_FROM=$from run run_copy
    assert_success
    out=$(printf '%s\n' "$output" | grep '^tests: ')
    assert_equal "$out" 'tests: 2, failures: 0, skipped: 1'
  done
}

@test "a level without a test file is left out and is not an error" {
  passing_test
  [ ! -d "$copy/tests/smoke" ]
  run run_copy
  assert_success
  refute_output --partial 'no tests'
}

@test "a live run is serial and prints its jobs line before the first test" {
  passing_test
  run run_copy DOTFILES_TEST_LIVE=1
  assert_success
  assert_line --index 0 'jobs: 1'
}

@test "a run without the live variable prints a jobs line" {
  passing_test
  run run_copy
  assert_success
  assert_line --regexp '^jobs: [1-9][0-9]*$'
}
