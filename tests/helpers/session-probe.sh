#!/usr/bin/env bash
# The session probe of manual-steps.md in openspec/changes/correct-shell-environment/ (task 2.3): the lines after these
# comments are the probe of that file, the same text, and tests/unit/session-probe.bats compares them.
# It prints sixteen lines, A1 to A16 (A16 comes after A6): counts, modes and the words link, regular, none, present and
# absent. It never prints a name or a value of the private file. Run it with bash or zsh, in a terminal on which
# `secrets load` has not been typed: a shell that loaded the keys, and its children, hold them on purpose.
names() { sed -n 's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}\([A-Za-z_][A-Za-z0-9_]*\)=.*/\2/p' "${XDG_CONFIG_HOME:-$HOME/.config}/env"; }
pat='(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY|ACCESS_?KEY|PRIVATE_?KEY|CREDENTIAL)'
um() { systemctl --user show-environment | cut -d= -f1; }
echo "A1 private-file names in the user manager: $(um | grep -c -x -F -f <(names))"
echo "A2 secret-pattern names in the user manager: $(um | grep -c -E "$pat")"
echo "A3 GITHUB_TOKEN in the user manager: $(um | grep -c -x GITHUB_TOKEN)"
echo "A4 LC_ALL in the user manager: $(um | grep -c -x LC_ALL)"
echo "A5 locale in the user manager: $(systemctl --user show-environment | grep -E '^(LANG|LANGUAGE)=' | tr '\n' ' ')"
n=0; t=0; g=0
for p in /proc/[0-9]*; do
  { cat "$p/environ" > /dev/null; } 2>/dev/null || continue
  t=$((t+1))
  { tr '\0' '\n' < "$p/environ" | cut -d= -f1 | grep -q -x -F -f <(names); } 2>/dev/null && n=$((n+1))
  { tr '\0' '\n' < "$p/environ" | cut -d= -f1 | grep -q -x GITHUB_TOKEN; } 2>/dev/null && g=$((g+1))
done
echo "A6 readable processes: $t, holding at least one private-file name: $n"
echo "A16 readable processes holding GITHUB_TOKEN: $g"
echo "A7 user manager umask: $(awk '/^Umask/{print $2}' "/proc/$(pgrep -u "$USER" -x systemd | head -1)/status")"
echo "A8 plasmashell umask: $(awk '/^Umask/{print $2}' "/proc/$(pgrep -u "$USER" -x plasmashell | head -1)/status")"
echo "A9 this shell umask: 0$(printf '%03d' "$(umask | sed 's/^0*//')")"
echo "A10 GECOS carries umask=027: $(getent passwd "$USER" | cut -d: -f5 | grep -c 'umask=027')"
echo "A11 home mode: $(stat -c %a ~)"
echo "A12 en_US.UTF-8 generated: $(locale -a | grep -c -i -x 'en_US\.utf-\?8')"
echo "A13 sudoers umask file present: $([ -f /etc/sudoers.d/50-umask ] && echo 1 || echo 0)"
echo "A14 old history path: $(if [ -L ~/.zsh_history ]; then echo link; elif [ -f ~/.zsh_history ]; then echo regular; else echo none; fi)"
echo "A15 XDG history file: $([ -f "${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history" ] && echo present || echo absent)"
