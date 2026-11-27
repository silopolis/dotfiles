## 1. Start

- [x] 1.1 Read `design.md`, `findings.md`, `manual-steps.md` and the specs of this change; `mise run test:deps` if `tests/.lib` is missing, then `mise run test` (baseline of 2026-11-21: 343 tests, 0 failures, 27 skipped)
- [x] 1.2 Each group below writes its tests first and sees them fail on the current tree (`tests/run.sh <file>`), then the code, then sees them pass; every new mutant goes in `tests/mutants/` with its row in `tests/mutants/README.md` (`mise run test:mutants` exits 0)

## 2. Test helpers

- [x] 2.1 `tests/helpers/`: a runner for the shell kinds of the `shell-environment` spec (the desktop replay with the session's `PATH`, `LANG`, `SHELL`, `USER` and `LOGNAME`, the interactive kinds under a pseudo-terminal, the kinds started without `LANG`, `bash -c` as sshd starts it), printing counts only (`bash -n` and `shellcheck -s bash` on the helper; `bats tests/unit/harness.bats` passes)
- [x] 2.2 Synthetic fixtures made at run time: a zsh history file in extended format with multi-line entries, a second one with extra entries, the same two for bash (plain lines), and an inherited missing locale name (`rg -n 'DEMO_[A-Z_]*(KEY|TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL)' tests` prints nothing)
- [x] 2.3 `tests/helpers/session-probe.sh`: the probe of `manual-steps.md` as a script that prints the 16 lines A1 to A16, counts and modes only, bash and zsh; `tests/unit/session-probe.bats` runs it on a synthetic private file of `DEMO_` names with stubs for `systemctl` and `getent` and checks the counts, and that no name of the synthetic file and no value is in its output; `bash -n` and `shellcheck -s bash`; the probe in `manual-steps.md` and the script stay identical (a test compares them)

## 3. PATH and the env_ files

- [x] 3.1 `tests/unit/path-helper.bats`: `_path_prepend` and `_path_clean` in zsh and bash (scenario "The helper")
- [x] 3.2 `rc.d/035-env_path_helper.sh`: `_path_prepend` (move to the front, skip a missing directory) and `_path_clean` (drop duplicates and missing directories), POSIX for both shells
- [x] 3.3 `rc.d/040-env_path_base.sh`: keep the inherited `PATH`, append the missing system directories, clean
- [x] 3.4 `110-pkg_brew.sh` split: `rc.d/041-env_pkg_brew.sh` holds `brew shellenv` and every `HOMEBREW_*` export, `110` keeps completions, `fpath` and the brew-file wrapper (`zsh -n`, `bash -n`; the brew hook still defined in `zsh -i`)
- [x] 3.5 Renames with `git mv`: `120-pkg-aqua.sh` to `042-env_pkg_aqua.sh` (an inherited `AQUA_BIN_DIR` kept as it is), `140-pkg_snap.sh` to `043-env_pkg_snap.sh`, `150-pkg_krew.sh` to `044-env_pkg_krew.sh`, `200-lang_go.sh` to `045-env_lang_go.sh`, `220-lang_rust.sh` to `046-env_lang_rust.sh`; new `047-env_tools_mise.sh` (mise's shims directory, `${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims`, which does not need `MISE_DATA_DIR` to be set); `050-env_path_user.sh` through `_path_prepend`; each old target in `home/.chezmoiremove`
- [x] 3.6 `tests/smoke/environment-path.bats`: scenarios "No duplicates and no missing directory", "Inherited entries are kept", "User bin directories first", "Nested shells do not grow PATH" (zsh, bash and from the desktop replay)
- [x] 3.7 Mutant `env-path-no-clean` (`_path_clean` returns at once): at least the duplicate and nested tests fail

## 4. Locale

- [x] 4.1 `tests/unit/locale.bats` (the filter of inherited missing locales, the default of an unset `LANG`, with a stub `locale -a`) and `tests/smoke/environment-locale.bats` (scenarios "No forced LC_ALL", "No locale warnings from the user's files" with `perl -e1` in every kind, "An inherited missing locale is dropped", "The man alias takes effect", skipped with a message when `fr_FR.UTF-8` is not generated)
- [x] 4.2 `rc.d/020-env_defaults.sh`: no `LC_ALL`; drop an inherited `LANG`, `LC_ALL` or `LC_*` naming a locale that `locale -a` does not list (names compared without case and without `-`); `LANG` default `en_US.UTF-8` when generated, else `C.UTF-8`; `LANGUAGE` default `en_US:en`; one `locale -a` call per start
- [x] 4.3 Mutant `env-lc-all-forced` (the old `LC_ALL` line back): at least the "No forced LC_ALL" tests fail

## 5. Keys on demand

- [x] 5.1 `tests/unit/secrets.bats`, zsh and bash: scenarios "Load in the calling shell and its children", "A child shell keeps what its parent loaded", "Unload and status", "No private file", and the `rg` half of "No name in the repository"
- [x] 5.2 `rc.d/446-tools_secrets.sh`: `secrets load|unload` and the count; at sourcing, without `DOTFILES_SECRETS`, unset the inherited names of the private file (names read from the file at each call, never written in the file); does nothing in a non-interactive shell
- [x] 5.3 `rc.d/010-env_user.sh`: keep `envrc` and the `unset` line that `dt_unset_name` parses, stop sourcing the private file
- [x] 5.4 `tests/smoke/environment-keys.bats`: scenarios "Every shell kind", "Inherited copies are dropped", "The revoked variable stays unset"; update `tests/smoke/startup-behaviour.bats` (private environment and desktop replay now count 0 synthetic names, and the bypass check of the `opencode` function counts 3 secret-named names instead of 4, since startup no longer exports the private file's name) and keep the mutant `startup-unset-removed` failing as before
- [x] 5.5 Mutant `env-keys-at-startup` (`010` sources the private file again): at least the "Every shell kind" tests fail
- [x] 5.6 Live test in `tests/smoke/environment-live.bats`: no name of the user's private file in the shell source (names in memory, a count printed)

## 6. Desktop login and shellrc

- [x] 6.1 `tests/smoke/environment-desktop.bats`: scenarios "No rc.d pass in the desktop replay", "What the session keeps", "What the session no longer gets", "Only env_ files hold the environment", "A login sh loads nothing" (skipped with a message where `sh` is bash); `tests/smoke/environment-shellrc.bats`: "Non-interactive source", "bash started for an ssh command"
- [x] 6.2 `profile`: the non-interactive branch sources `shell/environment` for bash and zsh only (`CURRENT_SHELL`; the `env_` files use `source`, so any other login shell, `sh` among them, loads nothing and prints nothing, as today; `shell/environment` itself is not rewritten with the dot command); `shell/environment` keeps its debug line; comments say who reads each branch; the guard is shown once to matter, by a manual change that is not committed (the "A login sh loads nothing" test fails without it)
- [x] 6.3 `shellrc`: the interactive guard back, before anything else
- [x] 6.4 Remove `home/dot_config/zsh/zshrc` and `home/dot_config/bash/bashrc`, both in `home/.chezmoiremove`; `tests/smoke/startup-single.bats`: the non-interactive login tests count 0 `rc.d` passes and 1 environment line, for zsh and bash
- [x] 6.5 Mutants `env-desktop-full-pass` (a sed on `profile` that replaces the sourcing of `shell/environment` in the non-interactive branch by a loop over `rc.d/*.sh`, a real `rc.d` pass: sourcing `shellrc` there would change nothing once `shellrc` has its guard) and `env-shellrc-no-guard` (a sed that removes the guard of `shellrc`): the first fails at least "No rc.d pass in the desktop replay" and "What the session no longer gets", the second the scenarios of `environment-shellrc.bats`
- [x] 6.6 Comparison with `main`: `DOTFILES_TEST_BASE_REF=main DOTFILES_TEST_BASE_ALLOW=<file> mise run test`, the allow file listing the names this change removes or adds, with a comment per group; the file is kept in the change folder as `compare-allow.txt`
- [x] 6.7 Live tests for the scenarios "After the next login" and "The live session holds no key" in `tests/smoke/environment-live.bats`, read-only, counts only, names kept in memory; they run only with `DOTFILES_TEST_LIVE=1` and a second opt-in variable, `DOTFILES_TEST_AFTER_LOGIN=1` (the deployment is done and the machine was rebooted; its meaning is written in `tests/README.md`), and skip with a message that names it, so that `mise run test:live` stays green before the deployment; the umask of the user manager, of `plasmashell` and of a new interactive shell is `0027`, read through lines A7, A8 and A9 of `tests/helpers/session-probe.sh` and not through a second implementation; the user manager (line A1) and the ancestors of the test process (the parent chain walked through `/proc/<pid>/stat` up to the user manager) hold 0 names of the private file, with a count printed (not line A6: a pane where `secrets load` was typed holds the keys on purpose); a unit test of the counting function on a synthetic file of `DEMO_` names and a synthetic process (a child started with one of them counts 1, a clean one 0, no name printed); no mutant for these two, said in `tests/mutants/README.md`

## 7. Loose ends of F33

- [x] 7.1 `git mv` `930-highlighting.sh` to `999-highlighting.sh`, old target in `home/.chezmoiremove`; test of scenario "Last file"; mutant `env-highlighting-not-last`
- [x] 7.2 Remove `005-dbg_prof_enable.sh`, `995-dbg_prof_results.sh`, `130-pkg-flatpack.sh`, `200-lang_python.sh`, each in `home/.chezmoiremove`; test of scenario "Source and removal list" over every removed or renamed target of this change
- [x] 7.3 `tests/unit/history.bats`: scenarios "Paths", "First start moves the legacy file", "Two shells at once", "Merge after a trim" on synthetic zsh and bash history files in a scratch home
- [x] 7.4 `rc.d/320-shell_history.sh`: `HISTFILE` under `$XDG_STATE_HOME` for zsh and bash, directories 0700, the move and link of `~/.zsh_history` and `~/.bash_history`, the merge at start when the old path is a regular file (temporary file and move, silent on every failure)
- [x] 7.5 Mutant `env-history-no-merge`: at least the merge test fails
- [x] 7.6 A failed merge loses nothing: `tests/unit/history.bats` with a failing `awk` first on `PATH` (exit status 2, exit status 127 as a missing tool gives, part of the output and then a failure) for zsh and bash, which fails on the code of 7.4 (the zsh merge is a pipeline and `sh` has no `pipefail`); `_history_migrate` runs the merge with `pipefail` on and refuses to replace the new file when the merged output is empty while an input is not; mutant `env-history-merge-unchecked` (the `pipefail` line removed): at least the new test fails

## 8. Session defaults script

- [x] 8.1 `home/.chezmoidata/packages.yaml`: `system.session` (`umask: "027"`, `sudo_umask: "022"`, `home_mode: "0700"`, `locales: [en_US.UTF-8, fr_FR.UTF-8]`), with a comment that names the script; the tools it calls declared where the install-scripts capability wants them
- [x] 8.2 Harness: stubs and fixtures for `chfn`, `getent`, `visudo`, `locale-gen` and `locale`, and the scratch paths that stand for `/etc/sudoers.d`, `/etc/locale.gen` and the home (`bats tests/unit/harness.bats` passes)
- [x] 8.3 `tests/unit/install-scripts-isolated.bats`: the scenarios of "Session defaults are set for the login" (eleven since the review of 2026-11-27: the sudoers file that only root can read, the force variable, a failing tool changes nothing), and a test of the failure of every step that writes; `tests/unit/install-scripts-render.bats`: the script re-renders when `system.session` changes and not otherwise, render failure on bad data
- [x] 8.4 `home/.chezmoiscripts/run_onchange_before_03-session-defaults.sh.tmpl` on `script-lib.sh`: GECOS `other` sub-field, sudoers file through `visudo -cf` then `install -m 0440`, `chmod` of the home, locales; never weaker, sudo only to write, dry run (rendered with `chezmoi -S <worktree> execute-template`, run with `CHEZMOI_SCRIPTS_DRY_RUN=1`, `shellcheck -s bash` on the render)
- [x] 8.5 Mutant `install-session-weakens` (a stricter GECOS umask overwritten): at least the "A stricter live value is left" test fails

## 9. Documents

- [ ] 9.1 `tests/README.md`: the scenario table maps every scenario of `shell-environment` and the changed scenarios of `shell-startup`, `agent-environment` and `install-scripts` (rows equal the sum of the four `rg -c '^#### Scenario'` counts after the archive: 35 scenarios for `shell-environment`, 61 for the five delta specs together); "After the next login" and "The live session holds no key" map to `smoke/environment-live.bats`, opt-in with `DOTFILES_TEST_AFTER_LOGIN=1`
- [ ] 9.2 `AGENTS.md`, wording shown to the user first: `secrets load` (the user types it; an agent never does), the session umask from the login, and the line about non-interactive shells and brew (a non-interactive login shell now loads the environment)
- [ ] 9.3 `proposal.md`: open questions answered, capabilities modified (`shell-startup`, `agent-environment`, `install-scripts`, `shell-test-harness`), impact (the system script, `.chezmoiremove`, the deleted targets)
- [ ] 9.4 Ask the orchestrator to forward the note for the Neovim repository (avante `cmd:` key names) and to add the `~/.zshenv` review to the backlog of `TODO.md`

## 10. Checks before deployment

- [ ] 10.1 `mise run test` and `mise run test:mutants` exit 0; `zsh -n`, `bash -n` and `shellcheck` on every changed shell file; `openspec validate --all --strict`
- [ ] 10.2 The redaction tool (public profile, `--check`, file by file) and `gitleaks dir tests` report nothing on the new tests and fixtures
- [ ] 10.3 `chezmoi -S <worktree> apply --dry-run --verbose --exclude=scripts` on the shell targets lists only the expected files and removals (reviewed with the user)

## 11. Deployment, one target at a time, with the user present

The exact steps, the expected output and the rollbacks are in `manual-steps.md` (step 1).

Each step: `chezmoi -S <worktree> apply --exclude=scripts <targets>`, then a new interactive shell in a spare herdr tab (prompt, `alias cm`, a completion, `echo $PATH | tr : '\n' | sort | uniq -d` prints nothing), the tab closed by id; deletions only with the user's go.

- [ ] 11.1 `rc.d/035-env_path_helper.sh`, `040`, `050`
- [ ] 11.2 Each renamed `env_` file with the removal of its old target, then `041-env_pkg_brew.sh` with the new `110`
- [ ] 11.3 `rc.d/446-tools_secrets.sh`, then `rc.d/010-env_user.sh` (`secrets` prints `0` in a new shell, the count after `secrets load` equals the number of assignments of the private file)
- [ ] 11.4 `rc.d/020-env_defaults.sh` (`echo ${LC_ALL-unset}` prints `unset`), `rc.d/320-shell_history.sh` (the old history path is a link, the history of the running panes still grows)
- [ ] 11.5 `999-highlighting.sh` with the removal of `930`, and the removal of the four stub and empty files
- [ ] 11.6 `shellrc`, then `profile` last, with the removal of `~/.config/zsh/zshrc` and `~/.config/bash/bashrc`

## 12. Session defaults, reboot and live checks (the user)

The exact commands, the expected values before and after, and the rollbacks are in `manual-steps.md` (steps 2 to 6): it is the checklist to follow, and every line below is one of its steps.
The probe prints counts only: run it in a terminal that did not run `secrets load`.

- [ ] 12.1 Render the script, run it with `CHEZMOI_SCRIPTS_DRY_RUN=1` and review its lines with the user; then the user runs it in a terminal where sudo asks for the password
- [ ] 12.2 At once: `getent passwd <user>` shows `umask=027` in the GECOS field (checked by a count), `sudo -l` works, `sudo touch /tmp/umask-check && stat -c %a /tmp/umask-check` prints `644` (then the file is removed with the user's go), `stat -c %a ~` prints `700`, `locale -a` lists `en_US.utf8`
- [ ] 12.3 Reboot
- [ ] 12.4 `DOTFILES_TEST_AFTER_LOGIN=1 mise run test:live` (task 6.7: the two live scenarios of the new login pass); the counts of the user manager's and the terminal's variables against the names of the private file and the secret pattern print 0 (as in `TODO.md`'s reboot check, which is then ticked); the umask of the user manager, `plasmashell` and a new shell is `0027`; `LC_ALL` is not in the user manager
- [ ] 12.5 The old history path is a link with no regular file left; the user removes it, or keeps it
- [ ] 12.6 The live probe of `agent-environment` ("A herdr-started agent holds none of them", modified): a probe tab, `secrets load`, a probe agent, the counts, the tab closed

## 13. Close

- [ ] 13.1 Record before and after in `design.md` ("Results"): desktop replay time and names, `PATH` entries, warnings, and the probe's lines A1 to A16 against the table of `manual-steps.md`
- [ ] 13.2 `/opsx-verify correct-shell-environment`; archive on the user's go; then the merged `shell-startup` Purpose names the capability `shell-environment` instead of this change, and no modeline sits inside a requirement
- [ ] 13.3 Rebase on `main`, `openspec validate --all --strict`, report the last commit hash with the frictions met

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
