#!/usr/bin/env bats
# The suite checks its own helpers and guards: the synthetic names and canaries, the clean
# environment of the code under test, and the leak check of the runner.
# (The checks of the install-script stubs and of the two modes of its harness follow in this file.)

load ../helpers/bats/load

setup() {
  setup_scratch
}

@test "the nine synthetic names match the secret pattern" {
  local names n
  mapfile -t names < <(dt_syn_names)
  assert_equal "${#names[@]}" 9
  for n in "${names[@]}"; do
    [[ $n =~ $DT_SECRET_PATTERN ]] || fail "the synthetic name $n does not match the secret pattern"
  done
}

@test "the names to keep do not match the secret pattern, and one is lowercase" {
  local names n
  mapfile -t names < <(dt_keep_names)
  assert_equal "${#names[@]}" 5
  for n in "${names[@]}"; do
    if [[ $n =~ $DT_SECRET_PATTERN ]]; then
      fail "the name $n to keep matches the secret pattern"
    fi
  done
  assert_equal "${names[4]}" "${names[4],,}"
}

@test "canaries are distinct and at least 20 characters" {
  local all c
  mapfile -t all < <(dt_all_canaries)
  assert_equal "${#all[@]}" 198
  assert_equal "$(printf '%s\n' "${all[@]}" | sort -u | wc -l)" 198
  for c in "${all[@]}"; do
    ((${#c} >= 20)) || fail "a canary has fewer than 20 characters"
  done
  [[ $(dt_canary_spaced 3) == *' '* ]]
}

@test "the secret pattern of the suite is the one of the opencode function" {
  local file line pat
  file=$(dt_source_file dot_config/shell/rc.d/445-tools_opencode.sh)
  line=$(grep -F "grep -E '" "$file")
  pat=${line#*grep -E \'}
  pat=${pat%%\'*}
  assert_equal "$pat" "$DT_SECRET_PATTERN"
}

@test "the name that the user environment file unsets is read from the file" {
  local name
  name=$(dt_unset_name)
  [[ $name =~ ^[A-Z][A-Z0-9_]+$ ]] || fail "no name was read from 010-env_user.sh"
  [[ $name =~ $DT_SECRET_PATTERN ]] || fail "the unset name does not match the secret pattern"
}

@test "dt_clean hands the command PATH, HOME, LANG and the named variables only" {
  run dt_clean DEMO_ONE=1 -- env
  assert_success
  assert_equal "$(printf '%s\n' "$output" | cut -d= -f1 | sort | tr '\n' ' ')" "DEMO_ONE HOME LANG PATH "
  assert_line "HOME=$DT_HOME"
}

@test "dt_clean refuses to run without a scratch home" {
  unset DT_HOME
  run dt_clean -- env
  assert_failure 2
}

@test "env -i hides a synthetic secret-named variable and its canary" {
  local name value count
  name=$(dt_syn_names | head -n 1)
  value=$(dt_syn_value "$name")
  export "$name=$value"
  run dt_clean -- env
  assert_success
  count=$(printf '%s\n' "$output" | cut -d= -f1 | grep -Ec "$DT_SECRET_PATTERN" || true)
  assert_equal "$count" 0
  refute_output --partial "$value"
}

@test "a leaked canary fails the run, which prints a count and not the value" {
  require_tool bats
  local copy=$BATS_TEST_TMPDIR/suite canary
  canary=$(dt_canary 5)
  dt_suite_copy "$copy"
  printf '@test "prints a canary" {\n  echo "%s" >&3\n}\n' "$canary" > "$copy/tests/unit/leak.bats"
  run env -i PATH="$PATH" HOME="$DT_HOME" DT_TOOL_BATS="$DT_TOOL_BATS" \
    DOTFILES_TEST_TMPDIR="$BATS_TEST_TMPDIR" "$copy/tests/run.sh"
  assert_failure
  assert_output --regexp 'canary scan: [1-9][0-9]* matches'
  refute_output --partial "$canary"
}
