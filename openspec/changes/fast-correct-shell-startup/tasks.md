## 1. Measure

- [x] 1.1 Baseline timings (interleaved runs, medians), per-file and per-command costs, a `zprof` profile, saved outside the repository (`/tmp/opencode/shell-startup/baseline.txt`, directory mode 700)

## 2. Silent startup

- [x] 2.1 Banners of `profile`, `shellrc`, `shell/environment` and `zsh/zshrc` only on standard error and only with `SHELL_RC_DEBUG` (`SHELL_RC_DEBUG=1 zsh -l -i -c exit 2>&1 >/dev/null` under `sh -c` shows the lines; without it nothing)
- [x] 2.2 `330-shell_completion.sh` skips an empty `completions.d` glob and a missing gcloud script; `bash/bashrc` falls back to `$HOME/.config` (`bash -n` and `zsh -n` on each file)
- [x] 2.3 `420-tools_fzf.sh` loads the zsh integration only when the line editor is on and `/dev/tty` can be opened (`zsh -i -c exit 2>&1 </dev/null | wc -c` prints 0)

## 3. Load order

- [x] 3.1 `profile`: interactive login shells source nothing for zsh and `~/.bashrc` for bash, non-interactive login shells keep the pass of today (`SHELL_RC_DEBUG=1 ... | grep -c 'rc.d'` prints 1 for `zsh -l -i`, `zsh -l -c`, `bash -l -i`)
- [x] 3.2 `110-pkg_brew.sh`: `typeset -U fpath` in zsh, `$?` tests replaced by directory tests, `brew completions link` removed (the completion dump header is the same after alternating login and normal starts)

## 4. Speed

- [x] 4.1 `rc.d/335-shell_completion_cache.sh`: `_cached_completion`, silent, atomic, keyed on the resolved tool, `SHELL_COMPLETION_REFRESH` (driver cases of the spec scenarios under "Cached completions")
- [x] 4.2 `aliases`: kubectl, minikube, kind, gh, glab, localstack, infracost (fixed call) and docker use it; the unguarded gh and glab calls are guarded by the helper
- [x] 4.3 `cmll`, `cmlla`, `cmmkdir`, `cmtouch` evaluate `chezmoi source-path` when used (`alias cmll` shows a quoted command substitution)
- [x] 4.4 `220-lang_rust.sh`: constant rustup prefix when the directory exists (`PATH` equal before and after in the driver)
- [x] 4.5 `run_onchange_after_10-brew.sh.tmpl`: `brew completions link` only when `brew completions state` does not report linked completions (rendered with `chezmoi execute-template`, run with `CHEZMOI_SCRIPTS_DRY_RUN=1`, nothing but a `would run` line or nothing)
- [x] 4.6 `aliases`: the seven shellcheck findings fixed (`shellcheck -s bash -S error` prints nothing); `mkcd`, `cmmkdir` and `cmtouch` are functions, `convert_to_png` reads `$1` (driver `t-aliases.sh`: each command with stub tools in zsh and bash)

## 5. Tests in a scratch destination

- [x] 5.1 Render the previous commit and the working tree into two scratch directories, after a dry run that writes nothing (`chezmoi apply --dry-run --verbose` lists only paths under the scratch; the real home is unchanged)
- [x] 5.2 Driver kept in `/tmp/opencode/shell-startup/`, every shell under `env -i`, scratch `HOME`, `XDG_CONFIG_HOME` and mise directories, `DEMO_` names only
- [x] 5.3 Silent: 0 bytes in zsh and bash, login or not, with and without a terminal; debug lines on standard error only
- [x] 5.4 Single load: counts of the `rc.d` debug line per shell kind; dump header stable over alternating starts
- [x] 5.5 Behaviour kept: private environment and the unset name, `opencode` function in both shells, alias and function lists, replay of the display manager's call, bash login on a bare terminal
- [x] 5.6 Cache: hit, tool changed, failing generator, refresh, completions registered as before in zsh and bash
- [x] 5.7 Timings in the scratch destination, before and after, alternating, medians of at least 7

## 6. Documents

- [x] 6.1 `AGENTS.md`: the startup-time command of the Commands section replaced by the method used; the line about bash login startup (F22) says this change fixes it (wording shown to the user first)
- [x] 6.2 `openspec/changes/correct-shell-environment/`: proposal with what moved and its open questions, no design; audit change map row 7 updated and the new row added (`openspec validate --all --strict`)

## 7. Deploy, one target at a time, with the user's go

- [x] 7.1 `rc.d/335-shell_completion_cache.sh` (new, nothing calls it yet)
- [x] 7.2 `aliases` (first version: completions and `cm*` at use time)
- [x] 7.2b `aliases` again, with the shellcheck fixes of 4.6
- [x] 7.3 `rc.d/110-pkg_brew.sh` and `rc.d/220-lang_rust.sh`
- [x] 7.4 `rc.d/330-shell_completion.sh` and `rc.d/420-tools_fzf.sh`
- [x] 7.5 `shellrc`, `shell/environment` and `zsh/zshrc`
- [x] 7.6 `bash/bashrc`, then `profile` last
- [x] 7.7 After each target: a new interactive shell in a spare herdr tab, checked, the tab closed by id; the brew script is left for the supervised apply

## 8. Close

- [x] 8.1 Re-measure on the deployed configuration and record before and after in `design.md`, "Results", with the first-prompt hooks the method does not time
- [ ] 8.2 `zsh -n`, `bash -n` and `shellcheck` (through `mise exec`, or say it cannot run) on every changed file; `openspec validate --all --strict`; `/opsx-verify fast-correct-shell-startup`; archive on the user's go, then check the merged spec's Purpose and that no modeline sits inside a requirement
- [ ] 8.3 Rebase on `main`, validate, report the last commit hash; list the frictions met with the tooling

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
