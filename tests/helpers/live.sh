#!/usr/bin/env bash
# What the live tests of the new login share (task 6.7 of the change correct-shell-environment): plain bash, no bats.
# Source it (`. tests/helpers/live.sh`; it loads common.sh), or call one function:
#   tests/helpers/live.sh <function> [args...]
#
# Provides:
#   dt_probe_lines PATTERN       the lines of the session probe (session-probe.sh, the only copy of them) whose label
#                                matches the extended regular expression (`A1`, `A[789]`), after the three definitions
#                                they use (`names`, `pat`, `um`), as text for bash: `eval "$(dt_probe_lines A1)"`
#                                defines the functions and sets the variable, `bash -c "$(dt_probe_lines 'A[789]')"`
#                                prints the lines
#   dt_process_ancestors PID [LAST]   the ancestors of PID, one per line, nearest first, read from /proc/<pid>/stat,
#                                up to LAST (included) or to pid 1 (excluded)
#   dt_environ_name_count PID LIST    how many of the names in the file LIST (one per line; a process substitution
#                                `<(names)` keeps them in memory) the environment of PID holds: a number, never a
#                                name; the status is 1, and nothing is printed, when the environment cannot be read
#   dt_user_manager_pid          the pid of the systemd user manager of the user, as the probe finds it
#
# Nothing here prints a name or a value of a process's environment: only counts and pids.

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

dt_probe_lines() {
  local probe=$DT_HELPERS_DIR/session-probe.sh
  grep -E -e '^(names\(\) |pat=|um\(\) )' "$probe"
  grep -E -e "^echo \"($1) " "$probe"
}

# dt_process_parent PID: the parent of a process. The command name sits in parentheses in /proc/<pid>/stat and may
# hold spaces and parentheses itself: the fields are read after the last parenthesis.
dt_process_parent() {
  local stat ppid
  stat=$(cat "/proc/$1/stat" 2> /dev/null) || return 1
  stat=${stat##*) }
  read -r _ ppid _ <<< "$stat"
  [ -n "$ppid" ] || return 1
  printf '%s\n' "$ppid"
}

dt_process_ancestors() {
  local pid=${1:?dt_process_ancestors PID [LAST]} last=${2:-} parent
  while parent=$(dt_process_parent "$pid") && [ "$parent" -gt 1 ]; do
    printf '%s\n' "$parent"
    [ "$parent" = "$last" ] && break
    pid=$parent
  done
  return 0
}

dt_environ_name_count() {
  local pid=${1:?dt_environ_name_count PID LIST} list=${2:?dt_environ_name_count PID LIST}
  { cat "/proc/$pid/environ" > /dev/null; } 2> /dev/null || return 1
  { tr '\0' '\n' < "/proc/$pid/environ" | cut -d= -f1 | grep -c -x -F -f "$list" || true; } 2> /dev/null
}

dt_user_manager_pid() {
  pgrep -u "${USER:-$(id -un)}" -x systemd | head -n 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn=${1:?usage: live.sh <function> [args...]}
  shift
  "$fn" "$@"
fi
