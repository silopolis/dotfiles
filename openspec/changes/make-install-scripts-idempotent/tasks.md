## 1. Preparation

Every chezmoi command in this worktree takes `-S <worktree>` (`chezmoi -S <worktree> source-path` prints `<worktree>/home`); `<worktree>` is `~/Work/trees/dotfiles-install-scripts-idempotent`.

- [x] 1.1 Re-read the current scripts and note line numbers; confirm live limits (done in the 2026-11-12 review: line numbers hold, `cat /etc/security/limits.d/ulimit.conf` prints soft 32768 and hard 65536)
- [x] 1.2 Write the test harness in `/tmp/opencode/scripts-test/` (mode 0700), outside the repository:
  - a render loop: every script through `chezmoi -S <worktree> execute-template`, output next to the harness;
  - isolated mode: stubs first on `PATH` (`sudo`, `apt-get`, `dpkg-query`, `brew`, `pipx`, `mise`, `kubectl`, `codium`, `vim`, `gh`, `rustup`, `bat`, `unzip`) that log their arguments and answer from fixtures, a scratch `HOME`, standard input from `/dev/null`;
  - live read-only mode: the same stubs forward only an allow-list of read-only calls to the real tools (`dpkg-query -W`, `brew list`, `brew file clean --dry-run`, `brew file install --dry-run`, `pipx list`, `kubectl krew list`, `kubectl krew version`, `codium --list-extensions`, `rustup default` with no argument, `gh auth status`, `mise install --dry-run-code`), refuse and log everything else, `sudo` only logs and exits 1; `brew file edit` and `brew file cat` are not on the list; the `kubectl-krew` plugin and `python3` (for brew-file itself) are stubbed and forwarded for their read-only forms; `HOMEBREW_PREFIX` is always set, to the real prefix in live mode and to a scratch one in isolated mode, because `brew shellenv` would put the real brew ahead of the stubs
  ; isolated mode runs on a curated `PATH` (stubs plus basic utilities), so `-a <tool>` really removes a tool, and its scripts are rendered with a scratch `tools.search.override`, because a script prepends the directories of `tools.search` to its `PATH` (`run.sh` refuses an isolated script that lists a real directory); `all.sh` runs every case, the shim cleanup checks and the render checks (`ls -ld /tmp/opencode/scripts-test` shows mode 0700; a refused call is logged)

## 2. Documents, helper and data

- [x] 2.1 `TODO.md`: call the entries items, not lines, in the "Planned order of changes" section; wording only, no reordering (`rg -n '\blines? [0-9]' TODO.md` prints nothing)
- [x] 2.2 `TODO.md`: add a "Follow-ups from changes" section with two entries, the soft open-files limit of the desktop session and the per-system review of the krew plugins (`rg -n 'Follow-ups from changes' TODO.md`)
- [x] 2.3 Add `home/.chezmoitemplates/script-lib.sh` (strict mode, `log`, `warn`, `have`, `run`, `as_root`, `load_brew`, `report_undeclared`, the dry-run variable, the `CHEZMOI=1` warning) (`bash -n` and `shellcheck -s bash` on a rendered script that includes it)
- [x] 2.4 `home/.chezmoidata/packages.yaml`: `packages.linux.apt` (from `00-pre-requesites`), `system.limits.nofile` (32768/65536), `vim.ycm_build: false`, `brew.prefix` (`/home/linuxbrew/.linuxbrew`); drop the empty `dpkgs` key; the krew lists land with the krew script (4.4), so that the script it replaces keeps its list until then (`chezmoi -S <worktree> data --format=json | jq -c '.packages, .system, .vim, .brew'`)
- [x] 2.5 Regenerate `home/dot_config/pipx/packages.json` from `pipx list --json` with the filter of the design (path fields emptied, `source_interpreter` null), 4-space indent, in its own commit (`jq '.venvs | length'` prints 28; `jq '[.. | strings | select(startswith("/"))] | length'` prints 0; the installed minus declared and declared minus installed lists are both empty; pipx's own parser builds the same 28 package specs from it as from the full export)
- [x] 2.6 Declare the tools the scripts use: `jq = "latest"` and `kubectl = "latest"` in `home/dot_config/mise/config.toml`, `brew vim` in `home/dot_config/brewfile/Brewfile` (`rg -n '^(jq|kubectl) = ' home/dot_config/mise/config.toml`; `rg -nx 'brew vim' home/dot_config/brewfile/Brewfile`; `mise install --dry-run-code` against a scratch copy of the config names only `jq`)
- [x] 2.7 `home/dot_config/vim/vimrc`: `set nocompatible` on the first line, the later one removed (`vim -Es -n -u home/dot_config/vim/vimrc -i NONE -c 'if execute("command PluginInstall") !~ "vundle#installer#new" | cquit 2 | endif' -c qall` exits 0)
- [x] 2.8 Add the `tools-present` template and the `need` helper; use them in `11-mise`, `12-pipx`, `13-krew` and `21-vim-plugins` (render checks: the text flips when a tool file appears or goes, ignores a non-executable file, and is identical under three different `PATH`s; a mutant with `lookPath` fails the `PATH` checks)
- [x] 2.9 Make the searched directories configurable: `home/.chezmoidata/tools.yaml` (`tools.search.dirs`, `extra`, `override`), the `tools-dirs` and `tools-use` templates, `use_tool_dirs` in the helper (replacing `load_mise`), validation at render time (render checks: default list, `extra` with duplicates and dot segments, `override`, ten bad entries, config over data file, a tool found only in an added directory, the helper's `PATH` result; mutants that ignore the list, append instead of prepend, or accept relative entries each fail their check)
- [x] 2.10 `home/.chezmoi.toml.tmpl`: copy `tools.search.extra` and `tools.search.override` into `[data.tools.search]` (`chezmoi execute-template --init` keeps given values, writes empty lists otherwise, prompts for nothing, and the two existing spec scenarios of `chezmoi-config` still hold); `chezmoi init` is not run in this change

## 3. Before scripts

- [x] 3.1 Replace `00-pre-requesites` with `run_onchange_before_00-prerequisites.sh.tmpl`: Debian-family guard, list from data, `dpkg-query` check, `as_root apt-get` only for missing packages (harness, live mode: no sudo call; isolated mode with one package missing: one `apt-get install` of that package; `--override-data` with a Fedora `osRelease`: the render is empty)
- [x] 3.2 Rename the decrypt script to `run_onchange_before_01-decrypt-private-key.sh.tmpl`, `$HOME` instead of the literal path, the binary from `CHEZMOI_EXECUTABLE` (`chezmoi` on `PATH` by hand), written owner-only (`rg -n '/home/[a-z]+/' home/.chezmoiscripts` prints nothing; harness: identity present, nothing called; identity absent, scratch `HOME`, one `chezmoi age decrypt` call)
- [x] 3.3 Add `run_onchange_before_02-system-limits.sh.tmpl`: write only on difference, never lower (harness, live mode: no sudo call; override to a lower value: a warning and no sudo call; override to a higher value: one `install` call through the sudo stub)

## 4. After scripts

- [x] 4.1 `run_onchange_after_10-brew.sh.tmpl`: Brewfile hash, Homebrew and brew-file bootstrap when missing, `brew file install` on `~/.config/brewfile/Brewfile`, undeclared report (formulae and taps from `brew file clean --dry-run`, casks from `brew list --cask`), rustup guard, gh auth warning; darwin branch with the `brew bundle` call moved from `10-install-packages` (harness: dry-run mode prints its commands; live mode, with `brew file install --dry-run` standing in for the install: nothing to install, refused log empty, `whosthere` reported as an undeclared cask and still installed; isolated mode with a fixture listing an undeclared formula and tap: both named)
- [x] 4.2 `run_onchange_after_11-mise.sh.tmpl`: install, then `mise reshim` as the shim cleanup (harness: live mode against the deployed config, `mise install --dry-run-code` exits 0 and `mise reshim` is swapped for `mise --version`; isolated mode: `mise reshim` is called after `mise install --yes`, printed in dry-run mode; `reshim-sandbox.sh` with the real mise binary in a scratch data directory: stale shim removed, missing added, non-shim file and installed tool untouched, second run identical; `reshim-preview.sh`: a real reshim would change nothing on this laptop, and a planted stale shim in the copy is reported)
- [x] 4.3 `run_onchange_after_12-pipx.sh.tmpl`: filtered spec of missing venvs, undeclared report, a header comment naming the refresh command of the design (harness, live mode: no `install-all` call; isolated mode with one venv missing: the filtered file holds that venv with its full metadata; one undeclared venv named)
- [x] 4.4 `packages.common.krews`, `packages.linux.krews` (colorize-managed-fields, neat, node-shell), `packages.darwin.krews` (empty, with a review comment) in `packages.yaml`, and `run_onchange_after_13-krew.sh.tmpl` replacing `before_10-install-packages` (`git rm` the old script): combined list, installs missing plugins, undeclared report (harness, live mode: no `krew install` call; isolated mode with a plugin missing; render with the darwin override names the shared plugins only)
- [x] 4.5 `20-vscodium-extensions`: helper, `codium` presence line, quoted extension array, `.vsix` guard on the `publisher.name` read from `package.json` with a file-name fallback, lower-case comparison, a failed listing stops the script; fix the file name in the comment of `home/.chezmoidata/vscodium.yaml` (`modify_settings.json`, no `.tmpl`) (harness: 14 isolated cases with real `.vsix` archives, live mode with the real codium, unzip and jq makes no `--install-extension` call; a mutant without the guard reinstalls the `.vsix` in the three already-installed cases; `flip-codium` and `path-20` render checks)
- [x] 4.6 `run_onchange_after_21-vim-plugins.sh.tmpl` with the `vim.ycm_build` guard (harness, isolated mode: one `vim` call, no `install.py` call; with `ycm_build` true and the core library missing: the build is logged; `vim -N -Es -n -u ~/.vimrc -i NONE` answers `exists(':PluginInstall')` with 2; without `-N` the vimrc fails under Ex mode)
- [x] 4.7 Rename the bat script to `run_onchange_after_90-bat-cache.sh.tmpl` with real hashes of `dot_config/bat/config` and `.chezmoiexternals/bat.toml.tmpl`, the `bat` presence line and the helper (render checks on a scratch copy of the source: an edit of the config or of the externals file changes the output, an unrelated edit does not; mutants without either hash line fail the check; harness: isolated calls, dry run, `bat` absent; live mode builds a real cache from the real config directory into a scratch target and leaves the real cache directory as it was)
- [x] 4.8 `git rm` `run_onchange_before_05-install.sh.tmpl`

## 5. Checks

- [x] 5.1 Every rendered script passes `shellcheck -s bash` and the helper passes `bash -n` (`all.sh` runs both on the 10 real and the 10 scratch renders: 20 static checks, all pass)
- [x] 5.2 No escaped action and no literal path (`grep -rn '\\{\\{' home/.chezmoiscripts/` prints nothing; `rg -n '/home/[a-z]+/|\.local/share/chezmoi' home/.chezmoiscripts/` prints nothing)
- [x] 5.3 Full harness run, both modes: every script exits 0 with standard input from `/dev/null`, the sudo log and the refused-command log are empty in live mode (`/tmp/opencode/scripts-test/all.sh`: 155 checks pass on 2026-11-12, including the second-run, trigger-matrix, Debian-guard, krew-list and literal-path checks that `/opsx-verify` found missing from the harness; two deliberate breakages of the pipx and brew scripts make the matching checks fail)
- [x] 5.4 `chezmoi -S <worktree> status --include=scripts` and `chezmoi -S <worktree> apply --dry-run --verbose --include=scripts` (a dry run only, never a real apply) list exactly ten scripts as pending: `00-prerequisites`, `01-decrypt-private-key`, `02-system-limits`, `10-brew`, `11-mise`, `12-pipx`, `13-krew`, `20-vscodium-extensions`, `21-vim-plugins`, `90-bat-cache`; none ran; the state keeps five stale keys of removed or renamed scripts (`00-pre-requesites`, `05-install`, `10-install-packages`, `bat-cache-build`, `decrypt-private-key`), harmless and not deleted; for `reconcile-drift-and-supervised-apply`, every one of the ten is expected to be a no-op, except that `11-mise` runs `mise reshim` (no change expected here) and `90-bat-cache` builds the empty bat cache for the first time
- [x] 5.5 Document `CHEZMOI_SCRIPTS_DRY_RUN`, its caveat under `chezmoi apply`, the harness, the refresh command of `packages.json`, and the local `tools.search` settings in `AGENTS.md` (Commands) (`rg -n 'CHEZMOI_SCRIPTS_DRY_RUN|pipx list --json|tools.search' AGENTS.md`)
- [x] 5.6 Propose commits, one per group, each after the user validates its message (the plan grew from 10 to 15 commits with the declarations, the config template, the user's later requests and the verification fixes):
  - `docs(chezmoi:spec): refresh make-install-scripts-idempotent against the tree`
  - `docs(chezmoi:docs): call TODO entries items instead of lines`
  - `docs(chezmoi:docs): add the session limit and krew follow-ups to TODO`
  - `feat(chezmoi:scripts): add a shared script helper and package data`
  - `chore(pkg:pipx): sync packages.json with installed venvs, drop recorded paths`
  - `fix(chezmoi:scripts): make before scripts idempotent and guarded`
  - `feat(pkg:mise): declare jq and kubectl, which the install scripts use`
  - `feat(pkg:brew): declare vim, now installed only as a dependency`
  - `fix(editor:vim): set nocompatible before Vundle loads`
  - `feat(chezmoi:config): keep local tools.search settings across init`
  - `refactor(chezmoi:scripts): split the install script per package manager`
  - `fix(chezmoi:scripts): skip vsix files whose extension is installed`
  - `fix(chezmoi:scripts): hash real inputs in run_onchange scripts`
  - `docs(chezmoi:docs): document the script dry-run mode and harness`
  - `docs(chezmoi:spec): fix the verified scenarios and the commit list`

## 6. Close

- [x] 6.1 `openspec validate make-install-scripts-idempotent --strict`; `/opsx-verify make-install-scripts-idempotent`
- [ ] 6.2 On the user's go: archive (`openspec archive make-install-scripts-idempotent --yes`); show the new `AGENTS.md` safety rule wording and write it after the user's go (full apply allowed after a reviewed dry run); tick item 2 of the "Planned order of changes" list in `TODO.md`; set row 4 of the change map in `docs/audits/2026-10-30-environment.md` to done with the archive date
- [ ] 6.3 Rebase on `main`, `openspec validate --all --strict`, report to the orchestrator

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
