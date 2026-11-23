#!/usr/bin/env bats
# The session probe (helpers/session-probe.sh): the sixteen lines of manual-steps.md, run in bash and in zsh on a
# synthetic private file of DEMO_ names, with stubs for systemctl, getent, pgrep and locale. It prints counts, modes
# and the words link, regular, none, present and absent: never a name of the private file and never a value.
# The text of the script and the probe of manual-steps.md are the same: a test compares them.

load ../helpers/bats/load

PROBE=$DT_HELPERS_DIR/session-probe.sh
STEPS=$DT_ROOT/openspec/changes/correct-shell-environment/manual-steps.md

setup() {
  setup_scratch
  chmod 0700 "$DT_HOME"
  PROBE_BIN=$BATS_TEST_TMPDIR/bin
  mkdir -p "$PROBE_BIN" "$DT_HOME/.config" "$DT_HOME/.local/state"
  dt_realbin "$PROBE_BIN"
  # the two names of the synthetic private file (the first matches the secret pattern, the second does not),
  # and a third name that only the user manager holds
  # unique to the test: the tests of a file run in parallel, and A6 counts the processes that hold these names
  PRIV_A=DEMO_PROBE${BATS_TEST_NUMBER}_${DT_NAME_PART^^}
  PRIV_B=DEMO_PROBE${BATS_TEST_NUMBER}_SETTING
  printf 'export %s=value-a\n# a comment\n\n%s=value-b\n' "$PRIV_A" "$PRIV_B" > "$DT_HOME/.config/env"
  chmod 0600 "$DT_HOME/.config/env"
  UNSET_NAME=$(dt_unset_name)
  make_stubs
}

# the stubs answer from the variables of the run, and print the synthetic names and nothing else
make_stubs() {
  cat > "$PROBE_BIN/systemctl" << 'STUB'
#!/bin/sh
# the call of the probe: systemctl --user show-environment
printf '%s\n' "PATH=/usr/bin" "LANG=fr_FR.UTF-8" "LANGUAGE=en_US:en"
[ -n "$STUB_UM_NAMES" ] && for n in $STUB_UM_NAMES; do printf '%s=stub-value\n' "$n"; done
exit 0
STUB
  cat > "$PROBE_BIN/getent" << 'STUB'
#!/bin/sh
printf '%s:x:1000:1000:%s:/nonexistent:/bin/zsh\n' "$2" "$STUB_GECOS"
STUB
  cat > "$PROBE_BIN/pgrep" << 'STUB'
#!/bin/sh
printf '%s\n' "$STUB_PID"
STUB
  cat > "$PROBE_BIN/locale" << 'STUB'
#!/bin/sh
printf '%s\n' C C.utf8 POSIX $STUB_LOCALES
STUB
  chmod 0755 "$PROBE_BIN/systemctl" "$PROBE_BIN/getent" "$PROBE_BIN/pgrep" "$PROBE_BIN/locale"
}

# probe SHELL [VAR=value ...]: the output of the probe under env -i; the umask of the run is 0027
probe() {
  local shell=$1
  shift
  (
    umask 0027
    env -i PATH="$PROBE_BIN" HOME="$DT_HOME" USER="$(id -un)" XDG_STATE_HOME="$DT_HOME/.local/state" \
      STUB_PID="$$" STUB_GECOS='Demo User,,,umask=027' STUB_LOCALES=en_US.utf8 \
      STUB_UM_NAMES="$PRIV_A $PRIV_B $UNSET_NAME LC_ALL" "$@" "$(dt_shell_path "$shell")" "$PROBE" < /dev/null
  )
}

line() { # the text after "AN " of line AN of the output
  printf '%s\n' "$output" | sed -n "s/^$1 //p"
}

@test "the probe script and the probe of manual-steps.md hold the same text" {
  local block
  block=$(sed -n '/^```sh$/,/^```$/p' "$STEPS" | sed '1d;$d')
  [ -n "$block" ] || fail "no probe block in manual-steps.md"
  assert_equal "$(sed '/^#/d' "$PROBE")" "$block"
}

@test "the probe script is syntactically right in bash and zsh, and shellcheck -s bash accepts it" {
  bash -n "$PROBE"
  if dt_shell_path zsh > /dev/null 2>&1; then
    zsh -n "$PROBE"
  fi
  require_tool shellcheck
  run "$DT_TOOL_SHELLCHECK" -s bash "$PROBE"
  assert_success
}

@test "bash: the probe prints the sixteen lines A1 to A16 and nothing else" {
  require_shell bash
  run probe bash
  assert_success
  assert_equal "$(printf '%s\n' "$output" | wc -l)" 16
  assert_equal "$(printf '%s\n' "$output" | sed -n 's/^\(A[0-9]*\) .*/\1/p' | sort -V | tr '\n' ' ')" "A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 A11 A12 A13 A14 A15 A16 "
}

@test "zsh: the probe prints the sixteen lines A1 to A16 and nothing else" {
  require_shell zsh
  run probe zsh
  assert_success
  assert_equal "$(printf '%s\n' "$output" | wc -l)" 16
  assert_equal "$(printf '%s\n' "$output" | sed -n 's/^\(A[0-9]*\) .*/\1/p' | sort -V | tr '\n' ' ')" "A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 A11 A12 A13 A14 A15 A16 "
}

# the counts that the stubs make certain, in each shell
check_counts() {
  assert_equal "$(line A1)" 'private-file names in the user manager: 2'
  assert_equal "$(line A2)" 'secret-pattern names in the user manager: 2'
  assert_equal "$(line A3)" 'GITHUB_TOKEN in the user manager: 1'
  assert_equal "$(line A4)" 'LC_ALL in the user manager: 1'
  assert_equal "$(line A5)" 'locale in the user manager: LANG=fr_FR.UTF-8 LANGUAGE=en_US:en '
  assert_equal "$(line A9)" 'this shell umask: 0027'
  assert_equal "$(line A10)" 'GECOS carries umask=027: 1'
  assert_equal "$(line A11)" 'home mode: 700'
  assert_equal "$(line A12)" 'en_US.UTF-8 generated: 1'
}

@test "bash: the counts that the stubs decide" {
  require_shell bash
  run probe bash
  check_counts
}

@test "zsh: the counts that the stubs decide" {
  require_shell zsh
  run probe zsh
  check_counts
}

@test "the umask of the user manager and of plasmashell is read from the process the stub names" {
  require_shell bash
  local mine
  mine=$(awk '/^Umask/{print $2}' /proc/$$/status)
  run probe bash
  assert_equal "$(line A7)" "user manager umask: $mine"
  assert_equal "$(line A8)" "plasmashell umask: $mine"
}

@test "a GECOS field without the entry, a missing locale and another home mode give the other values" {
  require_shell bash
  chmod 0755 "$DT_HOME"
  run probe bash STUB_GECOS='Demo User' STUB_LOCALES=
  assert_equal "$(line A10)" 'GECOS carries umask=027: 0'
  assert_equal "$(line A11)" 'home mode: 755'
  assert_equal "$(line A12)" 'en_US.UTF-8 generated: 0'
}

@test "A14 and A15: link, regular file or none for the old history path, present or absent for the new one" {
  require_shell zsh
  require_shell bash
  run probe bash
  assert_equal "$(line A14)" 'old history path: none'
  assert_equal "$(line A15)" 'XDG history file: absent'
  mkdir -p "$DT_HOME/.local/state/zsh"
  : > "$DT_HOME/.local/state/zsh/history"
  : > "$DT_HOME/.zsh_history"
  run probe bash
  assert_equal "$(line A14)" 'old history path: regular'
  assert_equal "$(line A15)" 'XDG history file: present'
  rm -f "$DT_HOME/.zsh_history"
  ln -s .local/state/zsh/history "$DT_HOME/.zsh_history"
  run probe zsh
  assert_equal "$(line A14)" 'old history path: link'
}

@test "A6 and A16 count the processes that hold a name of the private file and the revoked variable" {
  require_shell bash
  local holder
  # one process holds both names of the synthetic file and the revoked name, nothing else on the machine holds them
  env "$PRIV_A=held" "$PRIV_B=held" "$UNSET_NAME=held" sleep 30 &
  holder=$!
  # wait until the process has become sleep, which holds the names (env holds none of them while it starts)
  for _ in $(seq 1 100); do
    tr '\0' '\n' < "/proc/$holder/environ" 2> /dev/null | grep -q "^$PRIV_A=" && break
    sleep 0.05
  done
  run probe bash
  kill "$holder" 2> /dev/null || true
  [[ $(line A6) =~ ^readable\ processes:\ [0-9]+,\ holding\ at\ least\ one\ private-file\ name:\ 1$ ]] || fail "A6 is not a count of one holder"
  [[ $(line A16) =~ ^readable\ processes\ holding\ GITHUB_TOKEN:\ [1-9][0-9]*$ ]] || fail "A16 counts no holder"
}

@test "no name of the synthetic file and no value is in the output of the probe" {
  require_shell zsh
  require_shell bash
  local value
  value=$(dt_canary 7)
  printf 'export %s=%s\n' "$PRIV_A" "$value" > "$DT_HOME/.config/env"
  printf '%s=%s\n' "$PRIV_B" "$value" >> "$DT_HOME/.config/env"
  run probe bash "$PRIV_A=$value"
  assert_success
  assert_equal "$(printf '%s\n' "$output" | grep -c -F -e "$PRIV_A" -e "$PRIV_B" -e "$value" || true)" 0
  run probe zsh
  assert_equal "$(printf '%s\n' "$output" | grep -c -F -e "$PRIV_A" -e "$PRIV_B" -e "$value" || true)" 0
}

# without a private file grep gets no pattern and prints nothing for A1 (the probe keeps its text: the file exists
# on the machine it is written for); the other lines are still printed
@test "the probe runs with no private file and nothing in the user manager: sixteen lines, counts of 0" {
  require_shell bash
  rm -f "$DT_HOME/.config/env"
  run probe bash STUB_UM_NAMES=
  assert_success
  assert_equal "$(printf '%s\n' "$output" | grep -c '^A[0-9]* ')" 16
  assert_equal "$(line A3)" 'GITHUB_TOKEN in the user manager: 0'
  assert_equal "$(line A4)" 'LC_ALL in the user manager: 0'
  [[ $(line A6) =~ ^readable\ processes:\ [0-9]+,\ holding\ at\ least\ one\ private-file\ name:\ 0$ ]] || fail "A6 holds a count other than 0"
}
