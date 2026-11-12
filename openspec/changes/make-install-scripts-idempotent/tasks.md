## 1. Preparation

Every chezmoi command in this worktree takes `-S <worktree>` (`chezmoi -S <worktree> source-path` prints `<worktree>/home`); `<worktree>` is `~/Work/trees/dotfiles-install-scripts-idempotent`.

- [x] 1.1 Re-read the current scripts and note line numbers; confirm live limits (done in the 2026-11-12 review: line numbers hold, `cat /etc/security/limits.d/ulimit.conf` prints soft 32768 and hard 65536)
- [ ] 1.2 Write the test harness in `/tmp/opencode/scripts-test/` (mode 0700), outside the repository:
  - a render loop: every script through `chezmoi -S <worktree> execute-template`, output next to the harness;
  - isolated mode: stubs first on `PATH` (`sudo`, `apt-get`, `dpkg-query`, `brew`, `pipx`, `mise`, `kubectl`, `codium`, `vim`, `gh`, `rustup`, `bat`, `unzip`) that log their arguments and answer from fixtures, a scratch `HOME`, standard input from `/dev/null`;
  - live read-only mode: the same stubs forward only an allow-list of read-only calls to the real tools (`dpkg-query -W`, `brew list`, `brew file clean --dry-run`, `brew file install --dry-run`, `pipx list`, `kubectl krew list`, `kubectl krew version`, `codium --list-extensions`, `rustup default` with no argument, `gh auth status`, `mise install --dry-run-code`), refuse and log everything else, `sudo` only logs and exits 1; `brew file edit` and `brew file cat` are not on the list
  (`ls -ld /tmp/opencode/scripts-test` shows mode 0700; a refused call is logged)

## 2. Documents, helper and data

- [ ] 2.1 `TODO.md`: call the entries items, not lines, in the "Planned order of changes" section; wording only, no reordering (`rg -n '\blines? [0-9]' TODO.md` prints nothing)
- [ ] 2.2 `TODO.md`: add a "Follow-ups from changes" section with two entries, the soft open-files limit of the desktop session and the per-system review of the krew plugins (`rg -n 'Follow-ups from changes' TODO.md`)
- [ ] 2.3 Add `home/.chezmoitemplates/script-lib.sh` (strict mode, `log`, `warn`, `have`, `run`, `as_root`, `load_brew`, the dry-run variable, the `CHEZMOI=1` warning) (`bash -n` and `shellcheck -s bash` on a rendered script that includes it)
- [ ] 2.4 `home/.chezmoidata/packages.yaml`: `packages.linux.apt` (from `00-pre-requesites`), `packages.common.krews`, `packages.linux.krews`, `packages.darwin.krews` (empty, with a review comment), `system.limits.nofile` (32768/65536), `vim.ycm_build: false`, `brew.prefix` (`/home/linuxbrew/.linuxbrew`); drop the empty `dpkgs` key (`chezmoi -S <worktree> data --format=json | jq -c '.packages, .system, .vim, .brew'`)
- [ ] 2.5 Regenerate `home/dot_config/pipx/packages.json` from `pipx list --json`, 4-space indent, in its own commit (`jq '.venvs | length'` prints 28; the installed minus declared and declared minus installed lists are both empty)

## 3. Before scripts

- [ ] 3.1 Replace `00-pre-requesites` with `run_onchange_before_00-prerequisites.sh.tmpl`: Debian-family guard, list from data, `dpkg-query` check, `as_root apt-get` only for missing packages (harness, live mode: no sudo call; isolated mode with one package missing: one `apt-get install` of that package; `--override-data` with a Fedora `osRelease`: the render is empty)
- [ ] 3.2 Rename the decrypt script to `run_onchange_before_01-decrypt-private-key.sh.tmpl`, `$HOME` instead of the literal path, `chezmoi` from `PATH` (`rg -n '/home/[a-z]+/' home/.chezmoiscripts` prints nothing; harness: identity present, nothing called; identity absent, scratch `HOME`, one `chezmoi age decrypt` call)
- [ ] 3.3 Add `run_onchange_before_02-system-limits.sh.tmpl`: write only on difference, never lower (harness, live mode: no sudo call; override to a lower value: a warning and no sudo call; override to a higher value: one `install` call through the sudo stub)

## 4. After scripts

- [ ] 4.1 `run_onchange_after_10-brew.sh.tmpl`: Brewfile hash, Homebrew and brew-file bootstrap when missing, `brew file install` on `~/.config/brewfile/Brewfile`, undeclared report (formulae and taps from `brew file clean --dry-run`, casks from `brew list --cask`), rustup guard, gh auth warning; darwin branch with the `brew bundle` call moved from `10-install-packages` (harness: dry-run mode prints its commands; live mode, with `brew file install --dry-run` standing in for the install: nothing to install, refused log empty, `whosthere` reported as an undeclared cask and still installed; isolated mode with a fixture listing an undeclared formula and tap: both named)
- [ ] 4.2 `run_onchange_after_11-mise.sh.tmpl` (harness, live mode: `mise install --dry-run-code` exits 0)
- [ ] 4.3 `run_onchange_after_12-pipx.sh.tmpl`: filtered spec of missing venvs, undeclared report (harness, live mode: no `install-all` call; isolated mode with one venv missing: the filtered file holds that venv with its full metadata; one undeclared venv named)
- [ ] 4.4 `run_onchange_after_13-krew.sh.tmpl` replacing `before_10-install-packages` (`git rm` the old script): combined list, installs missing plugins, undeclared report (harness, live mode: no `krew install` call; isolated mode with a plugin missing; render with the darwin override names the shared plugins only)
- [ ] 4.5 `20-vscodium-extensions`: helper, `.vsix` guard on the `publisher.name` read from `package.json` with a file-name fallback; fix the file name in the comment of `home/.chezmoidata/vscodium.yaml:1` (`modify_settings.json`, no `.tmpl`) (harness, live mode: no `codium --install-extension` call)
- [ ] 4.6 `run_onchange_after_21-vim-plugins.sh.tmpl` with the `vim.ycm_build` guard (harness, isolated mode: one `vim` call, no `install.py` call; with `ycm_build` true and the core library missing: the build is logged; `vim -Es -u ~/.vimrc -i NONE` answers `exists(':PluginInstall')` with 2)
- [ ] 4.7 Rename the bat script to `run_onchange_after_90-bat-cache.sh.tmpl` with real hashes of `dot_config/bat/config` and `.chezmoiexternals/bat.toml.tmpl` (render from a scratch copy of the source with a changed `dot_config/bat/config`: the output changes; with a changed unrelated file: it does not)
- [ ] 4.8 `git rm` `run_onchange_before_05-install.sh.tmpl`

## 5. Checks

- [ ] 5.1 Every rendered script passes `shellcheck -s bash` and the helper passes `bash -n`
- [ ] 5.2 No escaped action and no literal path (`grep -rn '\\{\\{' home/.chezmoiscripts/` prints nothing; `rg -n '/home/[a-z]+/|\.local/share/chezmoi' home/.chezmoiscripts/` prints nothing)
- [ ] 5.3 Full harness run, both modes: every script exits 0 with standard input from `/dev/null`, the sudo log and the refused-command log are empty in live mode
- [ ] 5.4 `chezmoi -S <worktree> status --include=scripts` and `chezmoi -S <worktree> apply --dry-run --verbose` (a dry run only, never a real apply) list exactly the new and renamed scripts as pending, and render empty scripts as absent; record the list for `reconcile-drift-and-supervised-apply`, with the stale state keys of the removed scripts (`chezmoi -S <worktree> state get-bucket --bucket=entryState` keys only)
- [ ] 5.5 Document `CHEZMOI_SCRIPTS_DRY_RUN`, its caveat under `chezmoi apply`, and the harness in `AGENTS.md` (Commands) (`rg -n CHEZMOI_SCRIPTS_DRY_RUN AGENTS.md`)
- [ ] 5.6 Propose commits, one per group, each after the user validates its message:
  - `docs(chezmoi:spec): refresh make-install-scripts-idempotent against the tree`
  - `docs(chezmoi:docs): call TODO entries items instead of lines`
  - `docs(chezmoi:docs): add the session limit and krew follow-ups to TODO`
  - `feat(chezmoi:scripts): add a shared script helper and package data`
  - `chore(pkg:pipx): sync packages.json with the installed venvs`
  - `fix(chezmoi:scripts): make before scripts idempotent and guarded`
  - `refactor(chezmoi:scripts): split the install script per package manager`
  - `fix(chezmoi:scripts): skip vsix files whose extension is installed`
  - `fix(chezmoi:scripts): hash real inputs in run_onchange scripts`
  - `docs(chezmoi:docs): document the script dry-run mode and harness`

## 6. Close

- [ ] 6.1 `openspec validate make-install-scripts-idempotent --strict`; `/opsx-verify make-install-scripts-idempotent`
- [ ] 6.2 On the user's go: archive (`openspec archive make-install-scripts-idempotent --yes`); show the new `AGENTS.md` safety rule wording and write it after the user's go (full apply allowed after a reviewed dry run); tick item 2 of the "Planned order of changes" list in `TODO.md`; set row 4 of the change map in `docs/audits/2026-10-30-environment.md` to done with the archive date
- [ ] 6.3 Rebase on `main`, `openspec validate --all --strict`, report to the orchestrator

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
