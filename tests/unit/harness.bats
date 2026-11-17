#!/usr/bin/env bats
# The suite checks its own helpers and guards: the synthetic names and canaries, the clean
# environment of the code under test, and the leak check of the runner.
# It also checks the install-script harness: that a stub logs and answers from a fixture, that `sudo` logs and never
# elevates, that live mode refuses and logs what is not on its allow-list, that isolated mode refuses a script whose
# use_tool_dirs lists a real directory, and the helper that every script includes.

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

# --- the install-script harness: its stubs and its two modes, on synthetic scripts

harness_setup() {
  DT_HARNESS_ROOT=$BATS_TEST_TMPDIR/h
  export DT_HARNESS_ROOT
  mkdir -p "$DT_HARNESS_ROOT" "$BATS_TEST_TMPDIR/fix"
  SCRIPT=$BATS_TEST_TMPDIR/probe.sh
}

# hrun NAME [FLAGS...] SCRIPT-TEXT: write the script, run it under the harness (isolated unless a -m flag says otherwise)
hrun() {
  local name=$1 text=${*: -1} mode=isolated f flags=()
  printf '%s\n' "$text" > "$SCRIPT"
  for f in "${@:2:$#-2}"; do
    if [ "$f" = live ]; then mode=live; else flags+=("$f"); fi
  done
  dt_harness_run -m "$mode" -n "$name" "${flags[@]}" "$SCRIPT" > /dev/null 2>&1 || true
}

hlog() { # NAME FILE
  cat "$(dt_harness_logdir "$1")/$2"
}

@test "a stub logs its call and answers from the fixture, and a stubbed tool is never run for real" {
  harness_setup
  mkdir -p "$BATS_TEST_TMPDIR/fix/f"
  printf '#!/bin/sh\necho answer-from-the-fixture\n' > "$BATS_TEST_TMPDIR/fix/f/dpkg-query"
  chmod 0700 "$BATS_TEST_TMPDIR/fix/f/dpkg-query"
  hrun h1 -f "$BATS_TEST_TMPDIR/fix/f" "dpkg-query -W curl; brew install foo; echo done"
  assert_equal "$(hlog h1 out.log)" "$(printf '%s\n' answer-from-the-fixture done)"
  assert_equal "$(hlog h1 calls.log | grep -c '^stub ')" 2
  hlog h1 calls.log | grep -q '^stub dpkg-query -W curl$'
  hlog h1 calls.log | grep -q '^stub brew install foo$'
}

@test "sudo logs its call and exits without elevating, with the status the run asks for" {
  harness_setup
  hrun h2 'sudo touch should-not-exist; echo "status=$?"'
  assert_equal "$(hlog h2 out.log)" "status=0"
  assert_equal "$(hlog h2 sudo.log | wc -l)" 1
  [ ! -e "$(dt_harness_logdir h2)/userhome/should-not-exist" ]
  hrun h2b -u 5 'sudo true; echo "status=$?"'
  assert_equal "$(hlog h2b out.log)" "status=5"
}

@test "sudo runs the command as the plain user when asked, in isolated mode only" {
  harness_setup
  hrun h3 -E 'sudo touch made-by-sudo; echo "status=$?"'
  assert_equal "$(hlog h3 out.log)" "status=0"
  [ -e "$(dt_harness_logdir h3)/userhome/made-by-sudo" ]
  assert_equal "$(hlog h3 sudo.log | wc -l)" 1
}

@test "a live-mode call outside the allow-list is refused and logged, with the status the run asks for" {
  require_tool brew
  harness_setup
  hrun h4 live 'brew install foo; echo "status=$?"'
  assert_equal "$(hlog h4 out.log | tail -n 1)" "status=1"
  assert_equal "$(hlog h4 refused.log | wc -l)" 1
  hlog h4 refused.log | grep -q '^brew install foo$'
  hlog h4 calls.log | grep -q '^refused brew install foo$'
  hrun h4b live -x 9 'brew install foo; echo "status=$?"'
  assert_equal "$(hlog h4b out.log | tail -n 1)" "status=9"
}

@test "live mode logs sudo and never runs it" {
  harness_setup
  hrun h5 live 'sudo true; echo "status=$?"'
  assert_equal "$(hlog h5 out.log | tail -n 1)" "status=1"
  assert_equal "$(hlog h5 sudo.log | wc -l)" 1
}

@test "isolated mode refuses a script whose use_tool_dirs lists a real directory" {
  harness_setup
  printf '%s\n' "use_tool_dirs '/usr/bin'" 'echo ran' > "$SCRIPT"
  run dt_harness_run -m isolated -n h6 "$SCRIPT"
  assert_failure 3
  assert_equal "$(hlog h6 status)" 3
  [ ! -s "$(dt_harness_logdir h6)/out.log" ] || fail "the refused script ran"
}

@test "isolated mode accepts a tilde entry and an entry below the scratch tools root" {
  harness_setup
  DT_ISO_ROOT=$BATS_TEST_TMPDIR/iso
  export DT_ISO_ROOT
  printf '%s\n' "use_tool_dirs '~/.local/bin' '$DT_ISO_ROOT/brew/bin'" 'echo ran' > "$SCRIPT"
  run dt_harness_run -m isolated -n h7 "$SCRIPT"
  assert_success
}

@test "isolated mode reaches no tool but the stubs and the curated utilities" {
  harness_setup
  hrun h8 'for t in rg python3 vim ls; do command -v "$t" > /dev/null && echo "$t=found" || echo "$t=missing"; done'
  # rg is a real tool that is not curated, python3 and vim are stubs (found), ls is a curated utility
  assert_equal "$(hlog h8 out.log | tr '\n' ' ')" "rg=missing python3=found vim=found ls=found "
}

@test "a tool left out with -a is missing, and so is a curated utility" {
  harness_setup
  hrun h9 -a vim -a jq 'command -v vim > /dev/null && echo vim=found || echo vim=missing; command -v jq > /dev/null && echo jq=found || echo jq=missing'
  assert_equal "$(hlog h9 out.log | tr '\n' ' ')" "vim=missing jq=missing "
}

@test "the scratch home is a copy of the fixture home, and a second run can keep it" {
  harness_setup
  mkdir -p "$BATS_TEST_TMPDIR/fix/g/userhome"
  printf 'from the fixture\n' > "$BATS_TEST_TMPDIR/fix/g/userhome/marker"
  hrun h10 -f "$BATS_TEST_TMPDIR/fix/g" 'cat "$HOME/marker"; echo run >> "$HOME/count"'
  assert_equal "$(hlog h10 out.log)" "from the fixture"
  printf '%s\n' 'echo run >> "$HOME/count"; wc -l < "$HOME/count"' > "$SCRIPT"
  dt_harness_run -m isolated -n h10 -K -f "$BATS_TEST_TMPDIR/fix/g" "$SCRIPT" > /dev/null 2>&1
  assert_equal "$(hlog h10 out.log | tr -d ' ')" 2
}

@test "a substitution is applied to a copy of the script and not to the script" {
  harness_setup
  printf '%s\n' 'echo FROM_TEXT' > "$SCRIPT"
  dt_harness_run -m isolated -n h11 -s FROM_TEXT=TO_TEXT "$SCRIPT" > /dev/null 2>&1
  assert_equal "$(hlog h11 out.log)" TO_TEXT
  assert_equal "$(cat "$SCRIPT")" 'echo FROM_TEXT'
}

# --- the helper that every script includes (script-lib.sh), run under the harness

helper_script() { # BODY: the rendered helper followed by a body
  local lib=$BATS_TEST_TMPDIR/lib.sh
  dt_script_config "$BATS_TEST_TMPDIR/cfg"
  DT_SCRIPT_HOME=$BATS_TEST_TMPDIR/chezmoi-home
  mkdir -p "$DT_SCRIPT_HOME"
  export DT_SCRIPT_HOME
  printf '{{ template "script-lib.sh" "probe" }}' | dt_chezmoi_render --data '{}' > "$lib"
  { cat "$lib"; printf '%s\n' "$1"; } > "$SCRIPT"
}

@test "the helper: run executes a command, and prints it instead in a dry run" {
  require_tool chezmoi
  harness_setup
  helper_script 'run echo executed'
  dt_harness_run -m isolated -n h12 "$SCRIPT" > /dev/null 2>&1
  assert_equal "$(hlog h12 out.log)" executed
  dt_harness_run -m isolated -n h12b -e CHEZMOI_SCRIPTS_DRY_RUN=1 "$SCRIPT" > /dev/null 2>&1
  assert_equal "$(hlog h12b out.log)" "probe: would run: echo executed"
}

@test "the helper: as_root says why, and calls sudo once through the stub" {
  require_tool chezmoi
  harness_setup
  helper_script 'as_root "demo" true'
  dt_harness_run -m isolated -n h13 "$SCRIPT" > /dev/null 2>&1
  hlog h13 out.log | grep -q 'needs root: demo'
  assert_equal "$(hlog h13 sudo.log | wc -l)" 1
}

@test "the helper: report_undeclared lists the installed names that are not declared, and removes nothing" {
  require_tool chezmoi
  harness_setup
  helper_script 'report_undeclared "things" "$(printf "a\nb\nc\n")" "$(printf "b\n")"'
  dt_harness_run -m isolated -n h14 "$SCRIPT" > /dev/null 2>&1
  assert_equal "$(hlog h14 out.log | tr '\n' '|')" "probe: things installed but not declared (nothing is removed):|  a|  c|"
}

@test "the helper: need names a missing tool and fails, and a present tool passes" {
  require_tool chezmoi
  harness_setup
  helper_script 'need vim && echo have-vim; need vim nosuchtool || echo skipped'
  dt_harness_run -m isolated -n h15 "$SCRIPT" > /dev/null 2>&1
  hlog h15 out.log | grep -q 'have-vim'
  hlog h15 out.log | grep -q 'nosuchtool not found, skipping'
  hlog h15 out.log | grep -q 'skipped'
}
