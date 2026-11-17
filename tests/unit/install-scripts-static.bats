#!/usr/bin/env bats
# Proves the static part of the spec install-scripts: every non-empty rendered script, in the two renders (real
# directories and scratch directories), passes `bash -n` and `shellcheck -s bash`. Nothing is run.
# The script that a render leaves empty is skipped, naming it.

load ../helpers/bats/load
load ../helpers/bats/scripts

setup_file() {
  scripts_setup_file real iso
}

static_check() { # RENDER SCRIPT
  local dir file
  require_tool shellcheck
  case $1 in
    real) dir=$R ;;
    iso) dir=$RI ;;
  esac
  file=$dir/$2
  [ -s "$file" ] || skip "the script $2 renders empty in the $1 render"
  run bash -n "$file"
  assert_success
  run "$DT_TOOL_SHELLCHECK" -s bash "$file"
  assert_success
}

for script_file in "$(dt_source_file .chezmoiscripts)"/*; do
  script_name=${script_file##*/}
  script_name=${script_name%.tmpl}
  for render in real iso; do
    bats_test_function --description "static $render $script_name" -- static_check "$render" "$script_name"
  done
done
