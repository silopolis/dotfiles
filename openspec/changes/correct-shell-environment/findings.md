# Findings: the environment each shell provides

Study of section 1 of the brief, run on 2026-11-20 and 2026-11-21 on the laptop, before any change.
It feeds `design.md`.

## Method and rules

- Read-only on the real home: file searches, process lists, `systemctl --user show-environment`, `/proc/<pid>/environ` and `/proc/<pid>/status`, all reduced to counts and booleans in the same pipeline.
- The ten variables of the private environment file are labelled V1 to V10 by their position in the file; a value or a name of the file is never printed, logged or written.
  Values were compared by hash, in memory.
- V1, V4, V5, V7 and V10 have names that a provider documents as its convention; the others do not, so nothing below ties a non-documented label to a tool that would tell its name.
- Shell behaviour was measured on a scratch render of the worktree (`tests/helpers/render.sh`), in a scratch home below `.state/tmp/`, under `env -i`, with a synthetic private environment file of two `DEMO_` names.
- The baseline suite passes in the worktree: `mise run test` runs 343 tests, 0 failures, 27 skipped (the live tests and the comparison with another ref).

## The private environment file

- `~/.config/env`, mode 0600, deployed from `home/dot_config/encrypted_private_env.age`, sourced by `rc.d/010-env_user.sh` in every pass of `rc.d`.
- 31 lines: 10 assignments, 16 comment lines, 5 blank lines, no other statement.
- All ten assignments use `export`, all ten names are uppercase, and all ten match the name pattern of the `opencode` function.

## Who holds the variables

- The systemd user manager holds 143 names, 11 of which match the secret pattern: the ten variables, each with the value of the file, and the revoked GitHub token variable, which the file no longer sets.
- The session started on 2026-11-11 and the machine has not rebooted since, so the reboot check of `TODO.md` is still open.
- 51 distinct process names hold all ten: the Plasma services, KWin, KRunner, the wallet daemon, the file indexer, the portals, Firefox and its content processes, the sync client, the terminal, the multiplexer, 42 of 43 zsh processes, the editor and its language servers.
- The processes that hold none are the ones started before the desktop pass exported them (PipeWire, WirePlumber) and the `opencode` processes started through the wrapper.
- Agents, counted on 2026-11-21: 12 `opencode` processes; 6 hold none, all started since 2026-11-17 (this study's own session among them); 6 hold all ten, started from 2026-11-11 to 2026-11-18 in pane shells older than the wrapper.
  The first count, on 2026-11-20, found 13 (7 holding none): two agents started that day have ended since, and one has started.
- On this machine Plasma 6 runs as systemd user services (`plasma-plasmashell.service`, `plasma-kwin_x11.service`, `plasma-krunner.service`), and the terminal and Firefox run as `app-*.service` units: every graphical process is a child of the user manager and takes its environment from it.
- The Xsession scripts import the whole environment left by the profile into the user manager (`dbus-update-activation-environment --systemd --all` in `/etc/X11/Xsession.d/95dbus_update-activation-env`).

## Readers of each variable

A reader is code that takes the key from the environment when the variable is set.
Searched: the text of `~/.config`, `~/.local/share` (tool installs included), the Neovim plugins, the VSCodium extensions, the pipx applications, the mise and brew installs, every executable on `PATH` (4206 files), the Obsidian plugins of 10 vaults, and `~/Work` (git-ignored files and session exports left out).

| Label | Readers inside the desktop session | Readers started from a terminal | Configured by the user |
| --- | --- | --- | --- |
| V1 | one VSCodium extension, through the SDK it bundles, when its own key setting is empty (it is) | several command-line clients, the Neovim AI plugin (avante) | yes |
| V2 | none | some command-line clients, avante | yes |
| V3 | none | none | no |
| V4 | none | one command-line client, avante's built-in provider list | no |
| V5, V6, V7 | none | avante's built-in provider list only | no |
| V8 | none | none | no |
| V9 | none | one mise tool, one file of cem, two files of a fleet repository | no |
| V10 | none | one file of cem, two files of a fleet repository | no |

- VSCodium is not running, and its configuration was last written on 2026-10-29.
  Two other extensions name V1 or V2 in a list of providers and do not read the environment.
- Obsidian is not running.
  Eight plugins of one vault name V1 and five of them read it through `process.env`, but all eight are disabled; the only enabled plugin that names V1 (in another vault) keeps its own key in its settings and does not read the environment.
- No systemd user unit, timer, crontab line or autostart entry of the user reads any of them.
- V3 and V8 appear only in shell history files: no reader at all on this machine.

## Where a key can live instead

- Two terminal clients already take a key from somewhere else: one of them has a command-based key setting (used once in its configuration), and avante accepts a `cmd:` key name (unused today).
- fabric keeps its own key file, mode 0600, managed by this repository; it shares one name with the private file, with a different value.
- opencode keeps its providers in its own login file, mode 0600.
- The wallet daemon (kwalletd6, with `ksecretd`) runs, the wallet is open after login (`pam_kwallet` in the display manager's PAM stack), and `secret-tool` and `age` are installed; `pass` is not.
- direnv is installed and hooked into interactive shells.

## What each kind of shell loads today

Measured on the scratch render; `rc.d` is the number of passes counted with `SHELL_RC_DEBUG`, secrets the number of the two synthetic names exported.

| Kind | Example | Files read | `rc.d` | Secrets | `PATH` entries |
| --- | --- | --- | --- | --- | --- |
| Desktop session | `/etc/sddm/Xsession` for a zsh user, not interactive | `/etc/zsh/zshenv`, `/etc/zsh/zprofile` (`/etc/profile`), `~/.zprofile` (`profile`), `zsh/zshrc`, `shellrc` | 1 | 2 | 16 |
| Interactive zsh | the terminal, the multiplexer panes (all 41 pane shells are non-login) | zshenv, `~/.zshrc` (`shellrc`) | 1 | 2 | 16 |
| Interactive login zsh | `zsh -l -i`, console, ssh login | zshenv, `/etc/profile`, `profile` (nothing for zsh), `shellrc` | 1 | 2 | 16 |
| Interactive bash, login or not | `bash -i`, `bash -l -i` | `~/.bashrc` (`shellrc`), and `profile` first for a login | 1 | 2 | 15 |
| Non-interactive login zsh | `zsh -l -c` | as the desktop session | 1 | 2 | 16 |
| Non-interactive zsh | `zsh -c`, an ssh command (the login shell is zsh) | `/etc/zsh/zshenv` | 0 | 0 | 8 |
| Non-interactive login bash | `bash -l -c` | `/etc/profile`, `profile`, `bash/bashrc`, which returns at its guard | 0 | 0 | 8 |
| Non-interactive bash | `bash -c` | nothing | 0 | 0 | 8 |
| bash started by sshd | an ssh command for a user whose login shell is bash | `~/.bashrc`, which is `shellrc` with its guard commented out | 1 | 2 | 15 |
| `env -i` interactive | `env -i zsh -i`, `env -i bash -i` | as the interactive shells, with `LANG` unset at start | 1 | 2 | 16, 15 |

- The desktop pass runs the interactive parts too: compinit, the completion cache, the aliases file, mise's activation, direnv's hook.
  It exports 108 names in the scratch home, among them 36 `forgit_` and `LESS_TERMCAP_` variables of the aliases file, `LS_COLORS`, `LESSOPEN`, `HSTR_CONFIG` and 8 internal variables of mise's shell hook, which reach the user manager.
- On the laptop, 41 of the 132 non-secret names of the user manager come from this repository's `rc.d`, from `envrc` or from brew's `shellenv`, among them `LC_ALL`, `CURRENT_SHELL` and the brew-file settings.
- compinit in the desktop pass depends on compaudit accepting the group-writable brew completion directories, which it does only because the user's private group has no other member and `LOGNAME` matches it; with another `LOGNAME`, the non-interactive pass prints 25 lines of compinit and `compdef` errors.

## Which rc.d file exports what, in the desktop pass

| File | Exported names it adds | `PATH` entries after it |
| --- | --- | --- |
| `000-env_xdg_dirs.sh` | the `XDG_*` base directories | 8 |
| `010-env_user.sh` | `envrc` (`EDITOR`, `VISUAL` and three more) and the private file | 8 |
| `020-env_defaults.sh` | `LANGUAGE`, `LC_ALL`, `PAGER` (`LANG` and `EDITOR` already set) | 8 |
| `040`, `050` | none (`PATH` replaced, then the user's bin directories) | 11 |
| `110-pkg_brew.sh` | 14 `HOMEBREW_*`, `INFOPATH`, `FPATH` | 13 |
| `120`, `150`, `200-lang_go` | `AQUA_*`, `KREW_*`, `GOPATH`, `GOBIN` | 14 |
| `220-lang_rust.sh` | none | 15 |
| `400-shell_utils.sh` | `LESSOPEN`, `LESSCLOSE` | 15 |
| `415-tools_mise.sh` | `MISE_SHELL` and 7 `__MISE_*` hook variables | 16 |
| `430-tools_hstr.sh` | `HSTR_CONFIG` | 16 |
| `800-aliases.sh` | 36 `forgit_` and `LESS_TERMCAP_` variables, `LS_COLORS`, `KUBECOLOR_*`, `FORGIT_INSTALL_DIR` | 16 |

The other files add no exported name.

## Prototype of an environment-only desktop pass

Copies of the scratch home with the non-interactive branch of `profile` replaced, medians of 7 alternating runs of the replayed desktop call:

| Variant | Exported names | Secrets | `PATH` entries | Median |
| --- | --- | --- | --- | --- |
| Today: `zsh/zshrc`, the whole `rc.d` | 108 | 2 | 16 | 0.62 s |
| `shell/environment` only (the `env_` files, `010` included) | 37 | 2 | 11 | 0.14 s |
| The same, plus the `PATH` files (`110`, `120`, `140`, `150`, `200-lang_go`, `220`) and `mise activate --shims` | 57 | 2 | 16 | 0.23 s |
| The same, with `010` reading the private file in interactive shells only | 55 | 0 | 16 | 0.23 s |

- The third and fourth variants keep the same `PATH` length and every name the session uses (`PATH`, the XDG directories, the locale, `EDITOR`, `VISUAL`, the brew variables); they lose only shell-only variables (aliases, `LS_COLORS`, `LESSOPEN`, `HSTR_CONFIG`) and mise's hook state, which every interactive shell sets again.
- The scratch home has no mise tool installed, so the real activation (50 tool directories) costs more than shown; with `--shims` the session would hold one shims directory instead of one directory per tool.
- `shell/environment` already exists and sources exactly the `rc.d/*-env_*.sh` files: it is the loader an environment-only pass needs, and nothing calls it today.

## PATH

- The interactive shell of an agent holds 69 entries, the user manager 62.
- Two duplicates in both, `~/.local/bin` and `~/.local/sbin`, come from the unmanaged live `190-env_path_user.sh`, a copy of `050`; the scratch render, without that file, has none.
- `040-env_path_base.sh` replaces `PATH`, so a nested shell does not grow it, but it also drops what the parent added (mise's directories are added again by mise).
- `120-pkg-aqua.sh` appends `/bin` to an inherited `AQUA_BIN_DIR`: one more level per nested shell (`bin/bin/bin` in an agent's shell, measured in nested bash on the render); aqua's root directory does not exist on the laptop, so the entry is missing at every level.
- mise's activation puts its tool directories first at every prompt: `~/.local/bin` is at position 54 in an agent's shell, behind 50 mise directories, so a requirement that it comes first cannot hold while mise is activated.
- Five commands of `~/.local/bin` also exist elsewhere on `PATH`; putting `~/.local/bin` before brew would change the one that runs for one of them.

## Locale

- Generated: `C`, `C.utf8`, `fr_FR.utf8` (and `POSIX`); `/etc/default/locale` sets `LANG=fr_FR.UTF-8`.
- The login modules of the console, ssh, cron, su and the display manager read `/etc/default/locale`, so those sessions start with `LANG=fr_FR.UTF-8`; `020` then forces `LC_ALL=fr_FR.UTF-8` and defaults `LANGUAGE` to `en_US`.
- `LANGUAGE=en_US` already gives English messages, and the forced `LC_ALL` defeats the `man` alias of the aliases file (`LANG=C man`): `LANG=C date` still prints a French day name.
- A shell started without `LANG` (`env -i bash -i`, `env -i bash -l -i`) gets `LANG=en_US.UTF-8`, which is not generated, and prints 4 `setlocale` warnings for `LC_CTYPE` and `LC_COLLATE` while `330-shell_completion.sh` loads bash-completion, which clears `LC_ALL` for a moment; zsh prints none.
- An ssh client that sends `LC_ALL=en_US.UTF-8` (sshd accepts `LANG` and `LC_*`) makes an interactive bash print 7 `setlocale` warnings, because `020` keeps an inherited `LC_ALL`.
- Removing only the forced `LC_ALL` while keeping the `en_US.UTF-8` default makes a child program warn in a shell started without `LANG` (perl, measured).

## umask

- The system's login modules set it: `pam_umask` with per-user groups (`USERGROUPS_ENAB yes`) gives 0002 to every login, the user manager included, and every process of the session has 0002 except speech-dispatcher (0007).
- The graphical processes are services of the user manager, so a `umask` in the desktop pass of `profile` would reach `startplasma-x11` and not the applications; a shell umask changes shells and what they start.
- The user's private group has no other member, so 002 and 022 grant the same access in practice; three human accounts have a login shell, and the home directory is mode 0755, so files that are world-readable are readable by the other accounts: 224 of the 554 files in the first two levels of `~/.config`.
- The mode drift under `~/.config/shell` predates chezmoi's umask 027: the 30 files at 0664 were last written before 2026-11-08, the 11 files applied since are 0640.

## Corrections to the proposal and the brief

- The draft spec of `shell-environment` existed, moved unchanged from `fast-correct-shell-startup`.
- `reconcile-drift-and-supervised-apply` (tasks 2.3 and 2.4) owns both unmanaged `rc.d` files; `190` is identical to `050`.
- The `setlocale` warnings of a shell started without `LANG` are real in bash, through bash-completion; the console, ssh and cron do not start without `LANG`.
- The scenario "User bin first" of the draft spec cannot hold while mise is activated.
- The shell umask does not decide the umask of the desktop session or of the user manager.
- `shell/environment` is not unused material: it is the loader of an environment-only pass.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
