#!/usr/bin/env bats
# Proves the spec agent-environment on home/dot_config/shell/rc.d/445-tools_opencode.sh.
#
# The 13 checks run in zsh, in the system bash and in a Homebrew bash, each shell under `env -i` with
# only PATH, a scratch HOME and the variables the check names, so the secret-named variables of the
# shell that runs the suite never enter a count. Only synthetic variables are used, with canary values
# built at run time; nothing prints a name or a value of a real variable.
# The tests are named `zsh ...`, `bash ...` and `brewbash ...`: `bats --count --filter '^(zsh|bash|brewbash) '` is 39.

load ../helpers/bats/load

setup() {
  setup_scratch
  work=$BATS_TEST_TMPDIR/work
  mkdir -p "$work"
  dt_make_opencode_stub "$work"
  dt_write_syn_file "$work/syn.sh"
  dt_all_canaries > "$work/canaries"
  OCFN=$(dt_source_file dot_config/shell/rc.d/445-tools_opencode.sh)
  SH_PATH=$work/bin:/usr/bin:/bin
  mapfile -t SYN < <(dt_syn_names)
}

# sh_run SCRIPT [VAR=value ...]: the shell under test (DT_SHELL) runs SCRIPT under env -i, outputs merged.
sh_run() {
  local script=$1
  shift
  (cd "$work" && DT_PATH=$SH_PATH dt_clean OCFN="$OCFN" OCSYN="$work/syn.sh" "$@" -- \
    timeout 20 "$DT_SHELL" -c "$script" 2>&1)
}

join_lines() {
  printf '%s\n' "$@"
}

# The 13 checks. Each starts from the shell tag (zsh, bash, brewbash) that `check` has resolved.

check_defined() {
  case $1 in
    zsh)
      run sh_run '. "$OCFN"; whence -w opencode'
      assert_output 'opencode: function'
      ;;
    *)
      run sh_run '. "$OCFN"; type -t opencode'
      assert_output function
      ;;
  esac
}

check_silent() {
  run sh_run '. "$OCFN"'
  assert_equal "$output" ""
}

check_nocalls() {
  rm -f "$work/calls.log"
  run sh_run '. "$OCFN"'
  if [ -s "$work/calls.log" ]; then
    fail "sourcing the file called the stub"
  fi
}

check_removed() {
  run sh_run '. "$OCSYN"; . "$OCFN"; opencode'
  assert_output "$(join_lines 0 --args--)"
}

check_later() {
  local script
  script=". \"\$OCSYN\"; . \"\$OCFN\"; export $(dt_late_name)=$(dt_canary 99); opencode"
  run sh_run "$script"
  assert_output "$(join_lines 0 --args--)"
}

check_multiline() {
  local script
  printf -v script '. "$OCFN"; export DEMO_NOTE="line one\n%s=%s"; opencode; echo "rc=$?"' "$(dt_fake_name)" "$(dt_canary 98)"
  run sh_run "$script" STUB_STATUS=3
  # the stub splits the two-line value into two names, so it may count 1; never an error from env
  case $output in
    "$(join_lines 0 --args-- rc=3)" | "$(join_lines 1 --args-- rc=3)") ;;
    *) fail "expected a count of 0 or 1, rc=3 and no env error; got: $output" ;;
  esac
}

check_survive() {
  local keep values exports='' script i want
  mapfile -t keep < <(dt_keep_names)
  values=(/nonexistent/sock /nonexistent/xauth pubdemo sessdemo "$(dt_canary 97)")
  for i in "${!keep[@]}"; do
    exports+=" ${keep[$i]}=${values[$i]}"
  done
  script=". \"\$OCSYN\"; export$exports; . \"\$OCFN\"; opencode"
  want=$(
    join_lines 0 --args-- --present--
    for i in "${keep[@]}"; do printf '%s=present\n' "$i"; done
    for i in "${SYN[@]}"; do printf '%s=absent\n' "$i"; done
  )
  run sh_run "$script" STUB_PRESENT="${keep[*]} ${SYN[*]}"
  assert_output "$want"
}

check_keeps() {
  run sh_run '. "$OCSYN"; . "$OCFN"; opencode > /dev/null; env | cut -d= -f1 | grep -c "^DEMO_"'
  assert_output "${#SYN[@]}"
}

check_args() {
  run sh_run '. "$OCFN"; opencode -s ses_demo run "two words" --flag=1'
  assert_output "$(join_lines 0 --args-- -s ses_demo run 'two words' --flag=1)"
}

check_odd() {
  run sh_run '. "$OCFN"; opencode "a*b" "" "it'"'"'s" "\"dq\"" "\$HOME"'
  assert_output "$(join_lines 0 --args-- 'a*b' '' "it's" '"dq"' '$HOME')"
}

check_status() {
  run sh_run '. "$OCFN"; opencode > /dev/null; echo $?' STUB_STATUS=7
  assert_output 7
}

check_recursion() {
  SH_PATH=/usr/bin:/bin
  run sh_run '. "$OCFN"; opencode; echo "rc=$?"'
  local first second total
  first=$(printf '%s\n' "$output" | sed -n 1p)
  second=$(printf '%s\n' "$output" | sed -n 2p)
  total=$(printf '%s\n' "$output" | wc -l)
  case $first in
    env:*opencode*"No such file or directory") ;;
    *) fail "the first line is not the message of env: $first" ;;
  esac
  assert_equal "$total $second" "2 rc=127"
}

check_bypass() {
  run sh_run '. "$OCSYN"; . "$OCFN"; command opencode'
  assert_output "$(join_lines "${#SYN[@]}" --args--)"
}

# check ID SHELL: one of the checks above, in one shell build; a build that is absent skips with its name.
check() {
  require_shell "$2"
  "check_$1" "$2"
}

ids=(defined silent nocalls removed later multiline survive keeps args odd status recursion bypass)
descs=(
  "defined as a function"
  "sourcing prints nothing"
  "sourcing runs nothing (call log)"
  "synthetic set removed"
  "variable added later is covered"
  "multi-line value, status and no env error"
  "non-matching names survive, synthetic set absent"
  "calling shell keeps its variables"
  "five arguments unchanged"
  "glob, empty, quote and dollar arguments unchanged"
  "exit status 7 comes back"
  "no recursion: one message from env"
  "bypass keeps the environment"
)
for tag in zsh bash brewbash; do
  for i in "${!ids[@]}"; do
    bats_test_function --description "$tag ${descs[$i]}" -- check "${ids[$i]}" "$tag"
  done
done

# The other scenarios of the spec that need no terminal and no deployed target.

@test "canary scan: no shell prints a value of the synthetic set" {
  local tag out leaks=0 n
  require_shell zsh
  for tag in zsh bash brewbash; do
    DT_SHELL=$(dt_shell_path "$tag" 2> /dev/null) || continue
    out=$(sh_run '. "$OCSYN"; . "$OCFN"; opencode; command opencode; env | cut -d= -f1')
    n=$(printf '%s\n' "$out" | grep -c -F -f "$work/canaries" || true)
    leaks=$((leaks + n))
  done
  assert_equal "$leaks" 0
}

@test "syntax: bash -n accepts the file" {
  require_shell bash
  run "$DT_SHELL" -n "$OCFN"
  assert_success
  assert_equal "$output" ""
}

@test "syntax: zsh -n accepts the file" {
  require_shell zsh
  run "$DT_SHELL" -n "$OCFN"
  assert_success
  assert_equal "$output" ""
}

@test "no name of a variable is written in the file" {
  run grep -E 'DEMO_|_KEY=|_TOKEN=' "$OCFN"
  assert_failure 1
  assert_equal "$output" ""
}

@test "AGENTS.md documents the bypass" {
  run grep -n 'command opencode' "$DT_ROOT/AGENTS.md"
  assert_success
}
