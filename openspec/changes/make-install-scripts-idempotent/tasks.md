## 1. Preparation

- [ ] 1.1 Re-read the current scripts and note line numbers (`bat -n home/.chezmoiscripts/*`); confirm live limits (`cat /etc/security/limits.d/ulimit.conf`)
- [ ] 1.2 Write a test harness outside the repository: `/tmp/opencode/scripts-test/sudo` stub that logs its arguments to a file and exits 1; a loop that renders each script with `chezmoi execute-template < <script>` into `/tmp/opencode/scripts-test/` (`ls /tmp/opencode/scripts-test`)

## 2. Helper and data

- [ ] 2.1 Add `home/.chezmoitemplates/script-lib.sh` (`log`, `run`, `as_root`, `have`, strict mode, `CHEZMOI_SCRIPTS_DRY_RUN`) (`bash -n` on a rendered script that includes it)
- [ ] 2.2 `home/.chezmoidata/packages.yaml`: `packages.linux.apt` (from `00-pre-requesites`), `system.limits.nofile` (32768/65536), `vim.ycm_build: false`, `brew.prefix` (`/home/linuxbrew/.linuxbrew`); drop the empty `dpkgs` key (`chezmoi data --format=json | jq '.packages.linux.apt, .system, .vim, .brew'`)

## 3. Before scripts

- [ ] 3.1 Replace `00-pre-requesites` with `run_onchange_before_00-prerequisites.sh.tmpl`: Debian-family guard, list from data, `dpkg-query` check, `as_root apt-get` only for missing packages (harness: no sudo call)
- [ ] 3.2 Rename the decrypt script to `run_onchange_before_01-decrypt-private-key.sh.tmpl`, `$HOME` instead of the literal path (`rg -n '/home/tarax' home/.chezmoiscripts` prints nothing)
- [ ] 3.3 Add `run_onchange_before_02-system-limits.sh.tmpl` (write only on difference, never lower) (harness: no sudo call; then with a lower test value: warning, no write)

## 4. After scripts

- [ ] 4.1 `run_onchange_after_10-brew.sh.tmpl`: Brewfile hash, Homebrew and brew-file bootstrap when missing, `brew file install` on `~/.config/brewfile/Brewfile`, undeclared report through `brew file clean --dry-run`, rustup guard, gh auth warning (harness in dry-run mode, then for real: installs nothing; `whosthere` reported, still installed)
- [ ] 4.2 `run_onchange_after_11-mise.sh.tmpl` (`mise install --yes` reports nothing to install)
- [ ] 4.3 `run_onchange_after_12-pipx.sh.tmpl`: filtered spec of missing venvs (harness: nothing installed)
- [ ] 4.4 `run_onchange_after_13-krew.sh.tmpl` replacing `before_10-install-packages` (harness: nothing installed)
- [ ] 4.5 `20-vscodium-extensions`: `.vsix` guard; fix the file name in the comment of `home/.chezmoidata/vscodium.yaml:1` (harness: no `codium --install-extension` call)
- [ ] 4.6 `run_onchange_after_30-vim-plugins.sh.tmpl` with the `vim.ycm_build` guard (harness: Vundle reports nothing new; no YouCompleteMe build)
- [ ] 4.7 Rename the bat script to `run_onchange_after_90-bat-cache.sh.tmpl` with real hashes (change `dot_config/bat/config` in a scratch copy: rendered output changes)
- [ ] 4.8 `git rm` `run_onchange_before_05-install.sh.tmpl`

## 5. Checks

- [ ] 5.1 Every rendered script passes `shellcheck -s bash`
- [ ] 5.2 No escaped action and no literal path (`grep -rn '\\{\\{' home/.chezmoiscripts/`; `rg -n '/home/[a-z]+/|\.local/share/chezmoi' home/.chezmoiscripts/`)
- [ ] 5.3 Full harness run: every script exits 0 with stdin from `/dev/null`, the sudo stub log is empty
- [ ] 5.4 `chezmoi apply --dry-run --verbose 2>&1 | grep -c 'run_onchange'` lists exactly the new scripts as pending; record the list for `reconcile-drift-and-supervised-apply`
- [ ] 5.5 Document `CHEZMOI_SCRIPTS_DRY_RUN` and the harness in `AGENTS.md` (Commands)
- [ ] 5.6 Propose commits, one per group: `feat(chezmoi:scripts): add a shared script helper and package data`, `fix(chezmoi:scripts): make before scripts idempotent and guarded`, `refactor(chezmoi:scripts): split the install script per package manager`, `fix(chezmoi:scripts): hash real inputs in run_onchange scripts`

## 6. Close

- [ ] 6.1 `openspec validate make-install-scripts-idempotent --strict`; `/opsx-verify make-install-scripts-idempotent`
- [ ] 6.2 Archive (`openspec archive make-install-scripts-idempotent --yes`); update `AGENTS.md` safety rule (full apply allowed after a reviewed dry run)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
