#!/usr/bin/env bats
# The helpers of the live checks of the new login (helpers/live.sh): the probe lines they reuse, the walk up the
# parent chain through /proc/<pid>/stat, and the count of the names of a private file that a process's environment
# holds. Run on a synthetic private file of DEMO_ names and on synthetic processes (a child started with a name in its
# environment). Counts and pids only: nothing here prints a name or a value.

load ../helpers/bats/load

setup() {
  setup_scratch
  mkdir -p "$DT_HOME/.config"
  # unique to the test: the tests of a file run in parallel and each of them starts processes that hold these names
  PRIV_A=DEMO_LIVE${BATS_TEST_NUMBER}_${DT_NAME_PART^^}
  PRIV_B=DEMO_LIVE${BATS_TEST_NUMBER}_SETTING
  printf 'export %s=value-a\n# a comment\n\n%s=value-b\n' "$PRIV_A" "$PRIV_B" > "$DT_HOME/.config/env"
  chmod 0600 "$DT_HOME/.config/env"
  PIDS=$BATS_TEST_TMPDIR/pids
  : > "$PIDS"
}

teardown() {
  local pid
  while read -r pid; do
    kill "$pid" 2> /dev/null || true
  done < "$PIDS"
}

# started_with VAR=value...: a sleeping process whose environment is only PATH and the given variables; prints its pid
started_with() {
  local pid i
  env -i PATH=/usr/bin:/bin "$@" sleep 60 > /dev/null 2>&1 3>&- < /dev/null &
  pid=$!
  echo "$pid" >> "$PIDS"
  for i in $(seq 100); do
    [ "$(cat "/proc/$pid/comm" 2> /dev/null)" = sleep ] && break
    sleep 0.05
  done
  printf '%s\n' "$pid"
}

@test "dt_probe_lines gives the three definitions and the lines that match, as they are in the probe" {
  assert_equal "$(dt_probe_lines A1 | wc -l)" 4
  assert_equal "$(dt_probe_lines 'A[789]' | wc -l)" 6
  assert_equal "$(dt_probe_lines A1 | grep -c -F -x -f "$DT_HELPERS_DIR/session-probe.sh")" 4
  assert_equal "$(dt_probe_lines 'A[789]' | grep -c -F -x -f "$DT_HELPERS_DIR/session-probe.sh")" 6
}

@test "the lines of dt_probe_lines run on their own: A1 counts the names that the user manager holds" {
  local bin=$BATS_TEST_TMPDIR/bin
  mkdir -p "$bin"
  dt_realbin "$bin"
  printf '#!/bin/sh\nprintf "%%s\\n" "%s=held" "UNRELATED=held"\n' "$PRIV_A" > "$bin/systemctl"
  chmod +x "$bin/systemctl"
  run env -i PATH="$bin" HOME="$DT_HOME" XDG_CONFIG_HOME="$DT_HOME/.config" "$(type -P bash)" -c "$(dt_probe_lines A1)"
  assert_success
  assert_output 'A1 private-file names in the user manager: 1'
}

@test "dt_environ_name_count counts 1 for a child that holds a name of the private file, 2 for both, 0 for a clean one, for another name and for a longer name" {
  local held both clean other super
  export XDG_CONFIG_HOME=$DT_HOME/.config
  eval "$(dt_probe_lines A1)"
  held=$(started_with "$PRIV_A=held")
  both=$(started_with "$PRIV_A=held" "$PRIV_B=held")
  clean=$(started_with)
  other=$(started_with "DEMO_OTHER${BATS_TEST_NUMBER}=held")
  super=$(started_with "${PRIV_A}_EXTRA=held")
  assert_equal "$(dt_environ_name_count "$held" <(names))" 1
  assert_equal "$(dt_environ_name_count "$both" <(names))" 2
  assert_equal "$(dt_environ_name_count "$clean" <(names))" 0
  assert_equal "$(dt_environ_name_count "$other" <(names))" 0
  assert_equal "$(dt_environ_name_count "$super" <(names))" 0
}

@test "dt_environ_name_count prints a number and no name, and a value that holds a name does not count" {
  local held out
  export XDG_CONFIG_HOME=$DT_HOME/.config
  eval "$(dt_probe_lines A1)"
  held=$(started_with "$PRIV_A=held" "DEMO_LIVE_NOTE=prefix-$PRIV_B")
  out=$(dt_environ_name_count "$held" <(names) 2>&1)
  assert_equal "$out" 1
  [ "$(printf '%s' "$out" | grep -c -F -e "$PRIV_A" -e "$PRIV_B" -e held || true)" -eq 0 ]
}

@test "dt_environ_name_count has a status of 1 and prints nothing for a process that is gone" {
  local gone
  export XDG_CONFIG_HOME=$DT_HOME/.config
  eval "$(dt_probe_lines A1)"
  gone=$(started_with "$PRIV_A=held")
  kill "$gone"
  for _ in $(seq 100); do
    [ -d "/proc/$gone" ] || break
    sleep 0.05
  done
  run dt_environ_name_count "$gone" <(names)
  assert_failure 1
  assert_output ''
}

@test "dt_process_ancestors lists the parents nearest first, stops at a given pid or before pid 1" {
  local mid leaf me=$BASHPID f=$BATS_TEST_TMPDIR/leaf
  bash -c 'sleep 60 & echo $! > "$1"; wait' _ "$f" > /dev/null 2>&1 3>&- < /dev/null &
  mid=$!
  echo "$mid" >> "$PIDS"
  for _ in $(seq 100); do
    [ -s "$f" ] && break
    sleep 0.05
  done
  leaf=$(cat "$f")
  echo "$leaf" >> "$PIDS"
  assert_equal "$(dt_process_ancestors "$leaf" | sed -n 1p)" "$mid"
  assert_equal "$(dt_process_ancestors "$leaf" | sed -n 2p)" "$me"
  assert_equal "$(dt_process_ancestors "$leaf" "$mid" | wc -l)" 1
  assert_equal "$(dt_process_ancestors "$leaf" "$me" | wc -l)" 2
  assert_equal "$(dt_process_ancestors "$leaf" | grep -c -x 1 || true)" 0
}

@test "dt_process_parent reads past a command name that holds spaces and parentheses" {
  local odd=$BATS_TEST_TMPDIR/'x) 1 (y' me=$BASHPID pid i
  cp "$(type -P sleep)" "$odd"
  "$odd" 60 > /dev/null 2>&1 3>&- < /dev/null &
  pid=$!
  echo "$pid" >> "$PIDS"
  for i in $(seq 100); do
    [ "$(cat "/proc/$pid/comm" 2> /dev/null)" = 'x) 1 (y' ] && break
    sleep 0.05
  done
  assert_equal "$(dt_process_parent "$pid")" "$me"
}
