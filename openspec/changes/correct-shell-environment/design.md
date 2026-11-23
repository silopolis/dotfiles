## Context

The study of section 1 of the brief is in `findings.md` (counts and labels only, V1 to V10 for the ten variables of the private environment file); this section keeps what the decisions rest on.

- The display manager runs `/etc/sddm/Xsession` in zsh, which sources `~/.zprofile` (`profile`) without being interactive; `profile` then runs `zsh/zshrc`, `shellrc` and the whole `rc.d`, and `/etc/X11/Xsession.d/95dbus_update-activation-env` imports everything into the systemd user manager.
  Plasma 6, the terminal and Firefox run as services of that manager, so every graphical process takes its environment, and its umask, from it.
- That pass exports 108 names in a scratch home, among them the private file, 36 variables of the aliases file, `LS_COLORS`, `LESSOPEN`, `LC_ALL` and the hook state of mise; on the laptop 51 kinds of process hold all ten variables.
- Readers inside the desktop session: one VSCodium extension for V1, through the SDK it bundles, when its own key setting is empty; VSCodium is not running.
  No enabled Obsidian plugin reads the environment.
  Every other reader starts from a terminal: command-line clients, the Neovim AI plugin, cem and a fleet repository; V3 and V8 have no reader at all.
- The umask is not the shell's: `pam_umask` with per-user groups gives 0002 to every login, the systemd user manager included (`/usr/lib/pam.d/systemd-user` includes `common-session-noninteractive`).
  The home directory is 0755 and two other human accounts exist.
- Locales generated: `C`, `C.utf8`, `fr_FR.utf8`; sessions start with `LANG=fr_FR.UTF-8` from `/etc/default/locale`; `020-env_defaults.sh` forces `LC_ALL=fr_FR.UTF-8` and defaults `LANG` to `en_US.UTF-8`, which is not generated.
  A bash started without `LANG` prints 4 `setlocale` warnings while bash-completion loads; an ssh client that sends a missing `LC_ALL` gets 7 in `bash -l -i`.
- `PATH`: `040` replaces it, `050` adds the user's bin directories before the package managers add theirs in front of them, `120` appends `/bin` to an inherited `AQUA_BIN_DIR` at every nested shell, and the live unmanaged `190` adds the user's directories a second time.
- `shell/environment` already sources `rc.d/*-env_*.sh` and nothing calls it; `~/.config/zsh/zshrc` and `~/.config/bash/bashrc` are called only by the non-interactive branch of `profile` (`~/.zshrc` and `~/.bashrc` point at `shellrc`).
- The `shell-test-harness` suite passes in the worktree: 343 tests, 0 failures, 27 skipped.

## Goals / Non-Goals

**Goals:**

- No process holds a key it was not given: the desktop session and new shells hold none of the private file's variables; a shell gets them when the user asks, and its children with it.
- The desktop login loads the environment the session uses and nothing interactive.
- `PATH` without duplicates or missing directories, stable in nested shells, user directories before the package managers.
- A locale that exists, no forced `LC_ALL`, no `setlocale` warning from the user's files in any kind of shell.
- New files private to the user in every session, without making root's files private.
- The loose ends of F33 that touch this startup: highlighting last, stub and dead files removed, history under XDG.

**Non-Goals:**

- The `opencode` function of `rc.d/445-tools_opencode.sh` (decision of 2026-11-20): it stays as it is.
- Giving each tool its key without the environment (key command, key file, wallet): recorded as follow-ups, below.
- A managed `~/.zshenv` for non-interactive non-login shells (ssh commands, cron, scripts): backlog, below.
- The live unmanaged `060-libvirt.sh` and `190-env_path_user.sh`: `reconcile-drift-and-supervised-apply` (tasks 2.3 and 2.4).
- The history and identity of this repository (decision of 2026-11-20).

## Decisions

The five decisions were taken with the user on 2026-11-21, one at a time, with the options below.

### 1. Keys on demand: a `secrets` function, per-tool keys as the target

- `rc.d/010-env_user.sh` keeps `envrc` and the `unset` of the revoked GitHub variable, and stops sourcing the private file.
- A new interactive-only file, `rc.d/446-tools_secrets.sh`, defines `secrets`:
  - `secrets load` sources the private file into the calling shell and exports a marker, `DOTFILES_SECRETS=loaded`;
  - `secrets unload` unsets every name the file sets;
  - `secrets` alone prints how many of the file's names are set, a count and never a name.
- When it is sourced at the start of an interactive shell without the marker, the file unsets the names of the private file that the shell inherited: terminals and multiplexers started by the old session hold them until the next login.
  With the marker, the shell is a child of a shell that loaded them on purpose, and keeps them.
  The names are read from the file at each call, as the `opencode` function does: no name is written in the repository.
- The marker matches the secret pattern, so the `opencode` function removes it with the keys, and a shell started inside an agent unsets nothing it does not hold.
- Alternatives considered:
  - interactive shells keep loading the file and only the desktop stops: it protects the desktop and leaves every terminal and every agent other than opencode with every key (F23 unchanged);
  - per-directory loading (direnv `.envrc` or mise `[env]`): it fits cem and the fleet repository, not the general tools that run anywhere; it stays possible later, an `.envrc` can call `secrets load`;
  - per-tool keys now: best isolation, but configured tool by tool, for configurations that live in other repositories or are not managed yet.
- Follow-ups, the target: a key command or a key file of mode 0600 per tool (`secret-tool` reads the wallet that `pam_kwallet` opens at login): a note to the Neovim repository for avante, whose key names accept `cmd:`; `manage-ai-tool-configs` for the command-line client that has a key-command setting; the VSCodium extension's own key setting if it is ever used again.

### 2. umask 027 for the user's sessions, 022 for sudo, home 0700, from one install script

- A new script, `run_onchange_before_03-session-defaults.sh.tmpl`, with data under `system.session` in `.chezmoidata/packages.yaml`:
  - `umask: "027"`: written as `umask=027` in the `other` sub-field of the user's GECOS field (`chfn -o`, root only), which `pam_umask` reads first; set explicitly there, it is not turned into 007 by `USERGROUPS_ENAB`; the other entries of that sub-field (`pri=`, `ulimit=`) are kept;
  - `sudo_umask: "022"`: `/etc/sudoers.d/50-umask` holds `Defaults umask=0022` and `Defaults umask_override`, written to a temporary file, checked with `visudo -cf`, installed with mode 0440;
  - `home_mode: "0700"`: `chmod` on `$HOME`, no sudo;
  - `locales: [en_US.UTF-8, fr_FR.UTF-8]`: decision 3.
- The script follows the install-scripts capability: no-op when everything matches (no sudo call), dry run, non-interactive, never weakens: a stricter umask in GECOS, a stricter home mode or a generated locale that the list does not name are left as they are, with a warning.
  On a system without `chfn`, `/etc/sudoers.d` or `locale-gen` it skips that part and says so.
- The shell sets no umask: the login does, for shells and graphical applications alike.
- Why GECOS: `pam_umask` reads the umask from the GECOS field, its own argument, `UMASK` in `/etc/login.defs` and `/etc/default/login`, nothing else.
  `~/.pam_environment` sets variables, the umask is not one, `user_readenv` is deprecated and only the display manager's stack enables it, and the user manager's stack has no `pam_env`; systemd 262 has no per-user default umask.
  `UMASK 027` in `login.defs` would change the two other accounts and root.
- Why sudo 022: without a umask in sudoers, sudo uses the union of the user's umask and 022, so 027: `sudo cp tool /usr/local/bin/` would give a root:root 0750 file the user cannot run, APT keyrings written with `sudo tee` would be ignored by apt's download user, desktop files under `/usr/local/share/applications` would vanish from the menu.
- Alternatives considered: keep 002 (the other accounts read every new world-readable file), 022 (identical to 002 with an empty private group), 027 in interactive shells only (applications keep 0002, and sudo gets 027), home 0700 alone (closes existing files but new files stay world-readable outside the home).

### 3. Locale: no `LC_ALL`, missing locales dropped, `en_US.UTF-8` generated

- `rc.d/020-env_defaults.sh`:
  - sets no `LC_ALL`;
  - drops an inherited `LANG`, `LC_ALL` or `LC_*` that names a locale not generated on the machine (one `locale -a`, about 2 ms, names compared without case and without `-`);
  - defaults an unset `LANG` to `en_US.UTF-8` when it is generated and to `C.UTF-8` otherwise;
  - defaults `LANGUAGE` to `en_US:en`, so messages stay English while formats follow `LANG` (French here, as today).
- The script of decision 2 makes sure the locales of `system.session.locales` are generated (`/etc/locale.gen` and `locale-gen`), adding and never removing.
- Measured on a prototype of `020` (scratch render, 20 kinds of shell): 0 warnings from the user's files, child programs included; an ssh client sending a missing `LC_ALL` goes from 7 warnings to 1 in `bash -i` and 3 in `bash -l -i`, printed by bash and `/etc/profile` before any user file runs (out of reach: the client or sshd's `AcceptEnv` is the place); zsh prints none.
- The `man` alias of the aliases file (`LANG=C man`) works again.
- Alternatives considered: generating `en_US.UTF-8` alone (it does not remove the forced `LC_ALL` nor handle a missing inherited locale), dropping `LC_ALL` alone (the `en_US.UTF-8` default then warns in a shell started without `LANG`).

### 4. The desktop login loads the environment only; `shellrc` is interactive-only again

- The non-interactive branch of `profile` (the desktop session, `zsh -l -c`, `bash -l -c`) sources `shell/environment` instead of `zsh/zshrc` or `bash/bashrc`.
- `shell/environment` sources `rc.d/*-env_*.sh`, so the environment is exactly the `env_` files:

  | File | Content |
  | --- | --- |
  | `000-env_xdg_dirs.sh` | XDG base directories |
  | `010-env_user.sh` | `envrc`, the `unset` of the revoked variable |
  | `020-env_defaults.sh` | locale, `EDITOR`, `PAGER` |
  | `030-env_current_shell.sh` | `CURRENT_SHELL` |
  | `035-env_path_helper.sh` (new) | `_path_prepend` and `_path_clean`, defined in each pass |
  | `040-env_path_base.sh` | keeps the inherited `PATH`, appends the missing system directories, drops missing directories and duplicates |
  | `041-env_pkg_brew.sh` (from `110`) | `brew shellenv`, the `HOMEBREW_*` settings |
  | `042-env_pkg_aqua.sh` (from `120`) | `AQUA_ROOT_DIR`, an inherited `AQUA_BIN_DIR` kept as it is |
  | `043-env_pkg_snap.sh` (from `140`) | `/snap/bin` |
  | `044-env_pkg_krew.sh` (from `150`) | `KREW_ROOT`, its bin directory |
  | `045-env_lang_go.sh` (from `200-lang_go`) | `GOPATH`, `GOBIN` |
  | `046-env_lang_rust.sh` (from `220`) | rustup's directory |
  | `047-env_tools_mise.sh` (new) | mise's shims directory, `${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims` |
  | `050-env_path_user.sh` | the user's bin directories, last, so first on `PATH` |

  `060` stays free for the `060-env_libvirt.sh` that `reconcile-drift-and-supervised-apply` plans.
- `110-pkg_brew.sh` keeps what is interactive: completions, `fpath`, the brew-file wrapper and its commit hook.
- `_path_prepend` moves a directory to the front when it is already there and skips one that does not exist, so a nested shell, or a terminal that inherits the session's `PATH`, ends with the same list.
- Order of `PATH` after the environment part: the user's bin directories, mise's shims, the package managers and languages, the inherited entries this file does not know, the system directories.
  In an interactive shell mise's activation then puts its tool directories first, at every prompt: the draft scenario "`~/.local/bin` first" becomes "the user's bin directories come before every system and package-manager directory".
  One command of `~/.local/bin` that brew also provides changes owner on the laptop (measured).
- `shellrc` gets its guard back (`case $- in *i*) ;; *) return ;; esac`): no caller sources it non-interactively any more.
  A bash run by sshd for a command reads `~/.bashrc`, so ssh commands of a bash user stop loading the interactive configuration (the user's login shell is zsh).
- The `case $-` of `profile` is the guard against a second environment pass in an interactive login shell: zsh does nothing in `profile` and reads `~/.zshrc`, bash sources `~/.bashrc`; both run the `env_` files once, through `shellrc`.
- Measured on prototypes (scratch render, medians of 7 alternating runs of the replayed desktop call): 0.23 s and 55 exported names, 0 synthetic secrets, the same `PATH` length, against 0.62 s and 108 names today.
- Alternatives considered: the full pass minus the private file (106 names, 0.62 s, mise's hook state and the aliases variables still in the user manager, `shellrc` cannot be guarded); the same plus a managed `~/.zshenv` (backlog, below).

### 5. Loose ends of F33

- `930-highlighting.sh` becomes `999-highlighting.sh`: zsh-syntax-highlighting must load after every plugin that defines widgets, and the prompt (`990`) defines one.
- Removed: `005-dbg_prof_enable.sh` and `995-dbg_prof_results.sh` (commented-out profiling; `SHELL_RC_DEBUG` and the timing tests replace them), `130-pkg-flatpack.sh` and `200-lang_python.sh` (empty), `~/.config/zsh/zshrc` and `~/.config/bash/bashrc` (decision 4 removes their only caller).
  Each removed or renamed target, the old names of the moved `env_` files included, gets an entry in `home/.chezmoiremove`.
- `HISTFILE` moves under `$XDG_STATE_HOME`: `zsh/history` and `bash/history`, directories 0700, files 0600.
  About 40 live zsh processes share `~/.zsh_history` (`share_history`), so the migration loses nothing:
  - the first new shell finds no new file and a regular legacy file, moves it (same file system, an atomic rename) and leaves a symbolic link at the old path;
  - running shells append through the link into the new file;
  - a running shell that trims its history rewrites the old path as a regular file (zsh writes a copy and renames it over the link); the next shell that starts finds a regular file there again, merges it into the new file (every entry once, in timestamp order, written to a temporary file and moved into place) and puts the link back;
  - two shells that start at once: the second one's move, merge or link fails silently and it uses the new file;
  - after the reboot no old shell is left, and the link at the old path can go;
  - bash follows the same steps with `~/.bash_history` and `bash/history`: its running shells append through the link (`histappend`), one that truncates its file turns the link back into a regular file, and the next start merges it; a plain bash file carries no timestamp, so the merge keeps the entries of the new file, then those of the legacy file it lacks, a repeated command as many times as it was typed.
- `shell/environment` is the loader of decision 4.

### Load order, before and after

| Kind | Example | Today | After |
| --- | --- | --- | --- |
| Desktop session | `/etc/sddm/Xsession`, zsh, not interactive | `profile`, `zsh/zshrc`, `shellrc`, all of `rc.d` (private file included) | `profile`, `shell/environment` (`env_` files only), no key |
| Interactive zsh | the terminal, multiplexer panes | `shellrc`, all of `rc.d`, private file | `shellrc`, all of `rc.d`, no key until `secrets load`; inherited keys unset unless the marker is set |
| Interactive login zsh | `zsh -l -i`, console, ssh login | `profile` (nothing for zsh), then as above | same |
| Interactive bash, login or not | `bash -i`, `bash -l -i` | `profile` for a login, `shellrc`, all of `rc.d` | same as zsh |
| Non-interactive login | `zsh -l -c`, `bash -l -c` | zsh: all of `rc.d`; bash: nothing (`bash/bashrc` returns) | both: `shell/environment` |
| Non-interactive zsh | `zsh -c`, ssh command | `/etc/zsh/zshenv` only | same |
| Non-interactive bash | `bash -c` | nothing | same |
| bash run by sshd | ssh command, login shell bash | `~/.bashrc` = `shellrc`, all of `rc.d` | `shellrc` returns at once |
| `env -i` interactive | `env -i zsh -i` | as interactive, `LANG=en_US.UTF-8` (missing), bash warns | as interactive, `LANG=en_US.UTF-8` once generated (else `C.UTF-8`), no warning |

### What the desktop session sees after the next login

- None of the private file's variables, and not the revoked GitHub variable.
- No `LC_ALL`; `LANG` from the system or KDE's region settings, `LANGUAGE=en_US:en`.
- `PATH`: the user's bin directories, mise's shims instead of one directory per mise tool, brew, the language directories, the system directories, no duplicate.
- Gone, because only shells use them: the aliases file's variables (`forgit_*`, `LESS_TERMCAP_*`, `FORGIT_INSTALL_DIR`, `KUBECOLOR_*`), `LS_COLORS`, `LESSOPEN`, `LESSCLOSE`, `HSTR_CONFIG`, `MISE_SHELL` and the `__MISE_*` hook state.
- Kept: the XDG directories, `EDITOR`, `VISUAL`, `PAGER`, the `HOMEBREW_*` and brew-file settings, `GOPATH`, `KREW_ROOT`, `AQUA_*`, `CURRENT_SHELL`, `envrc`'s variables.
- Until `reconcile-drift-and-supervised-apply` adopts the live libvirt file as `060-env_libvirt.sh`, the libvirt default URI is no longer in the user manager (terminals keep it).
- umask 0027 in every process of the session, once the script of decision 2 has run.

### Specifications

- New capability `shell-environment`, replacing the draft moved from `fast-correct-shell-startup`.
- `shell-startup`: "Single load of the interactive configuration" and "Behaviour that a startup change must keep" are modified (a non-interactive login shell loads the environment part, and startup no longer exports the private file); the other five requirements stay.
- `agent-environment`: "A herdr-started agent holds none of them" is modified (the pane's shell holds the keys only after `secrets load`); the other five stay.
- `install-scripts`: one requirement added for the session-defaults script; the others stay.
- `shell-test-harness`: "The three ported suites keep their strictness" is modified so the scenario table of `tests/README.md` also maps `shell-environment`; the others stay.
- `secret-hygiene`: unchanged; where keys live is `shell-environment`'s business and the per-tool keys are follow-ups.

### Tests

- Smoke tests on the scratch render (`tests/smoke/environment-*.bats`) start the 20 kinds of shell of the study with a synthetic private file of `DEMO_` names, and count: names exported, `rc.d` passes, `PATH` entries, duplicates and missing directories, locale variables, `setlocale` lines, history paths.
- Unit tests for `_path_prepend`, the locale filter, the history migration and merge (synthetic history files, multi-line entries), `secrets` in zsh and bash, and the session-defaults script in the isolated harness (stubs for `chfn`, `getent`, `visudo`, `locale-gen`, `install`, `sudo`).
- Live tests, read-only and opt-in, for the checks that only a new login proves: the user manager and the terminal hold 0 names of the private file, session processes have umask 0027, no `LC_ALL` in the user manager.
- One mutant per requirement in `tests/mutants/`, each making at least one test fail.
- The startup tests that expect the private names in new shells and in the desktop replay change meaning; the mutant `startup-unset-removed` is kept against the `unset` line of `010`.

## Risks / Trade-offs

- [Risk] A mistake in `profile` leaves the desktop session without `PATH` or without a usable environment at the next login. → The replay of the display manager's call runs in the smoke tests before and after (`DOTFILES_TEST_BASE_REF`, with the removed names listed in an allow file); `profile` is deployed last; rollback from a text console is one command (`chezmoi apply` of the previous `profile`, or `git checkout` of it and an apply), and the old file's content is in git.
- [Risk] A tool used from the desktop needed one of the keys. → The study found one reader, a VSCodium extension that is not running and has its own key setting; a key-reading tool started from a terminal works after `secrets load`.
- [Trade-off] The user types `secrets load` before a key-reading tool, and Neovim must be started from a shell that did. → Accepted; the per-tool keys of the follow-ups remove the step tool by tool.
- [Risk] The session-defaults script writes outside `$HOME` with sudo: the GECOS field, a sudoers file, `/etc/locale.gen`. → Idempotent and guarded: it compares before writing and calls sudo only to write; the sudoers file is validated with `visudo -cf` before it is installed (a broken sudoers file would lock sudo out); a stricter value is never weakened; dry run first; first run by hand with the user's go, then at the supervised apply.
- [Risk] umask 027 makes a file unreadable for another account or a service: containers whose user is not the user's cannot read bind-mounted files, `qemu:///system` cannot read an image kept in the home. → Accepted by the user; none of them exists on the laptop today (0 libvirt domains or pools, 0 Incus instances); virt-manager offers an ACL fix; an `.envrc` or `umask 022` in a shell covers a one-off.
- [Risk] `chmod 700 ~` hides a file that another account or service reads from the home. → None found (no ACL, the display manager uses its own copy of the avatar); rollback `chmod 755 ~`.
- [Risk] The history migration loses entries while old shells run. → Link at the old path, merge at the next start when a trim turned it back into a file, tests on synthetic files; the legacy file is never replaced before the merged file is in place.
- [Risk] A deployed old `rc.d` file and its renamed `env_` copy both run during a partial deployment. → `_path_prepend` drops duplicates; each rename is deployed together with the removal of the old target.
- [Trade-off] `120`, `140`, `150`, `200-lang_go` and `220` become `env_` files: five renames in one change. → They are one line of `PATH` each, and the rule "the environment is the `env_` files" is what makes the desktop pass and the tests simple.
- [Risk] A future `rc.d` file exports something the desktop needs without being an `env_` file. → The rule is written in `shell/environment` and in the spec; the desktop replay test lists the exported names.
- [Limit] The `setlocale` warning that bash or `/etc/profile` prints before any user file runs, when an ssh client sends a missing locale, stays. → Documented; the client or sshd is the place.

## Migration Plan

The steps that only the user can take (sudo, deletions, the reboot, the live probes) are written out, with their expected output and rollbacks, in `manual-steps.md`.

1. Build: tests first, then code, `mise run test` green, `mise run test:mutants` green, shellcheck and `zsh -n` on every changed file.
2. Deploy one target at a time with `chezmoi apply --exclude=scripts <target>`, each followed by a new interactive shell in a spare tab:
   1. `rc.d/035-env_path_helper.sh`, then each renamed `env_` file together with the removal of its old target (the user's go for each deletion);
   2. `rc.d/446-tools_secrets.sh`, then `rc.d/010-env_user.sh` (from then on new shells hold no key until `secrets load`);
   3. `rc.d/020-env_defaults.sh`, `rc.d/320-shell_history.sh` (the first new shell moves the history), `999-highlighting.sh` with the removal of `930`, the removal of the four stub and empty files;
   4. `shellrc`, then `profile` last, with the removal of `zsh/zshrc` and `bash/bashrc`.
3. The session-defaults script: rendered and run with `CHEZMOI_SCRIPTS_DRY_RUN=1`, reviewed, then run by hand by the user in a terminal where sudo asks for the password; `sudo -l` and a test file created with sudo (mode 0644) check the sudoers file at once.
4. Reboot (a full logout is not enough while user services keep the manager alive).
5. Live checks: `mise run test:live`; the counts of the user manager's and the terminal's variables (0 names of the private file, 0 secret-pattern names); `umask` of session processes 0027; `ls -ld ~` 0700; the old history path is a link (then it can be removed).
6. Tick the `TODO.md` reboot check and update the "Secrets held by the desktop session" item when the orchestrator asks.

Rollback: the previous version of each target from git and a single-target apply (`profile` first); `sudo chfn -o '' <user>` (or the previous `other` sub-field, which the script prints in its log), `sudo rm /etc/sudoers.d/50-umask`, `chmod 755 ~`; the generated locale can stay; the history file can be moved back to `~/.zsh_history`.

## Follow-ups

- Per-tool keys (decision 1): a note to the Neovim repository for avante's `cmd:` key names; `manage-ai-tool-configs` for the command-line client with a key-command setting.
- Backlog: a managed `~/.zshenv` that loads the environment part for non-interactive non-login zsh (ssh commands, cron, scripts), to be reviewed with its cost on every `zsh -c`.
- `reconcile-drift-and-supervised-apply`: adopt the live libvirt file as `060-env_libvirt.sh` (an `env_` file, so the desktop gets it again) and delete the live `190`.

## Open Questions

None left: the five questions of the proposal were decided with the user on 2026-11-21, and the order question closed when the study moved inside this change.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
