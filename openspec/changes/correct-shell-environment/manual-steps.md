# Manual steps and reboot checks: correct-shell-environment

What only the user can do or prove: the steps that use sudo, the steps that need the user's go, the reboot and the checks that only a new login can show.
Everything else is in `tasks.md` and is done by a build session.
Groups 11 and 12 of `tasks.md` point here for the exact commands.

## Rules for every step

- The commands print counts, modes and locales, never the name or the value of a key.
  Do not replace them by `env`, `printenv`, `systemctl --user show-environment` or a listing of `/proc/<pid>/environ`.
- Run the probe in a fresh terminal on which `secrets load` has not been typed: a shell that loaded the keys, and its children, hold them on purpose and would be counted.
- A step that needs your go is marked **go**.
  A build session never deletes, never uses sudo and never reboots on its own.
- Before anything that logs you out or reboots: commit and push the work, export the sessions of the agents that run (they end with the reboot), and close what you do not need.

## The probe

Plain shell for bash and zsh.
The build keeps it as `tests/helpers/session-probe.sh` (task 2.3 of `tasks.md`); until then save it under `.state/tmp/` and run it with `bash`.

```sh
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
```

## Values before and after

Measured on 2026-11-21, before any change of this work, on the session that started on 2026-11-11.
The expected values hold only after the system script has run and after a reboot and a new login.

| Line | Before | Expected after |
| --- | --- | --- |
| A1 | 10 | 0 |
| A2 | 11 | 0 |
| A3 | 1 | 0 |
| A4 | 1 | 0 |
| A5 | `LANG=fr_FR.UTF-8 LANGUAGE=en_US` | `LANG` from the system or KDE's region settings, `LANGUAGE=en_US:en` |
| A6 | 83 of 98 readable processes | 0 |
| A7 | 0002 | 0027 |
| A8 | 0002 | 0027 |
| A9 | 0002 | 0027 |
| A10 | 0 | 1 |
| A11 | 755 | 700 |
| A12 | 0 | 1 |
| A13 | 0 | 1 |
| A14 | regular | link |
| A15 | absent | present |
| A16 | 78 of 95 readable processes | 0 |

A3 and A2 differ by one on purpose: the revoked GitHub variable is still in the user manager's memory until the next reboot.

## Reboot check before the change is deployed

If the machine reboots for another reason before group 11 of `tasks.md` is deployed, run the probe at once.
This is the check that `TODO.md` asks for after the next reboot, and nothing else is needed for it.

| Line | Expected |
| --- | --- |
| A3 | 0 |
| A16 | 0 |
| A1 | 10 |
| A2 | 10 |
| A4 | 1 |

A16 covers the terminal, the multiplexer and every other process at once: it counts all the readable processes, so a process that still holds the variable shows in the number, and `cat /proc/<pid>/comm` on a pid of the loop names its kind without printing the environment.

A1 and A2 stay at 10 because the profile still exports the private file until this change is deployed.
Tick the check in `TODO.md`; the reboot of step 5 below then only has to show the values of the table above.

## Step 1: deploy the shell targets (group 11), with you present

- The build session lists each target before it applies it; every `chezmoi apply` uses `--exclude=scripts` and one target at a time.
- After each apply, open a new tab, check the prompt, `alias cm`, one completion, and that `echo $PATH | tr : '\n' | sort | uniq -d` prints nothing; then close the tab by id.
- **go** for each deletion of an old target: the five renamed `rc.d` files, `930-highlighting.sh`, the four stub and empty files, `~/.config/zsh/zshrc` and `~/.config/bash/bashrc`.
- `profile` is deployed last.
  Keep a text console or a second terminal open while you test the first new login shell.
- Rollback of one target: restore the previous version of its source file with `git checkout <commit> -- <path>` and apply that one target, `profile` first.

## Step 2: the session-defaults script, with sudo (tasks 12.1 and 12.2)

1. Render it and read it: `chezmoi execute-template < home/.chezmoiscripts/run_onchange_before_03-session-defaults.sh.tmpl > .state/tmp/session-defaults.sh`.
2. Dry run, which makes no change: `CHEZMOI_SCRIPTS_DRY_RUN=1 bash .state/tmp/session-defaults.sh`.
   Review each line it prints with the build session.
   Never set that variable on `chezmoi apply`.
3. **go**: run it for real in a terminal where sudo can ask for the password: `bash .state/tmp/session-defaults.sh`.
   It prints the previous value of the `other` sub-field of your account's comment field, which the rollback needs; keep that line.
   chezmoi has not recorded this run, so the next full apply runs the script again and it changes nothing.
4. At once, without a reboot:
   - A10 prints 1, A11 prints 700, A12 prints 1, A13 prints 1;
   - `sudo -l` works;
   - `sudo touch /tmp/umask-check && stat -c %a /tmp/umask-check` prints 644, then **go** for `sudo rm /tmp/umask-check`.
5. Rollback: `sudo chfn -o '<previous value>' <user>` (or `sudo chfn -o '' <user>` when the field was empty), `sudo rm /etc/sudoers.d/50-umask`, `chmod 755 ~`; the generated locale can stay.

## Step 3: reboot (task 12.3)

A full logout is not enough while user services keep the manager alive.
Everything in the terminals and the agents ends with the reboot, so do the checklist of the rules above first.

## Step 4: probe after the reboot (task 12.4)

In the first terminal after the login, without `secrets load`:

1. Run the probe: every line of the table "Values before and after" must match its expected value.
2. `mise run test:live` passes.
3. Tick the reboot check in `TODO.md`.

If A1 or A6 is not 0, something still exports the private file: run `chezmoi status ~/.config/shell`, which prints paths only; a line there is a target that was not deployed.
Stop and fix that before anything else.
If A7 or A8 is not 0027, the script of step 2 did not take effect for the login: check A10 by count, then log out and in again.

## Step 5: history (task 12.5)

- After the reboot, A14 prints `link` and no regular file is left at the old path.
- **go**: remove the link, or keep it: `rm ~/.zsh_history` only when `[ -L ~/.zsh_history ]` is true.
- Start two or three shells and check that the history of an old session is there: `fc -l 1 | wc -l` is not smaller than before the migration.

## Step 6: the agent probe (task 12.6)

1. In a terminal tab, type `secrets load`, then start an agent through the `opencode` function.
2. From another terminal, with `names` defined as in the probe, count in the agent process and in its parent shell:
   - `pid=$(pgrep -n -u $USER -x opencode)`, the newest agent;
   - `ppid=$(ps -o ppid= -p $pid | tr -d ' ')`, the shell where you typed `secrets load`;
   - `tr '\0' '\n' < /proc/$pid/environ | cut -d= -f1 | grep -c -x -F -f <(names)` prints 0;
   - `tr '\0' '\n' < /proc/$ppid/environ | cut -d= -f1 | grep -c -x -F -f <(names)` prints the number of assignments of the private file (10 today).
3. Close the probe tab by id.

## After the checks

Record the before and after values in `design.md` (task 13.1), then `/opsx-verify correct-shell-environment`, and archive on your go.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
