## 1. Private decrypted targets (F10)

- [x] 1.1 List encrypted sources without `private_` (`git ls-files | grep encrypted_ | grep -v private_`) and their deployed modes (`chezmoi managed --include=encrypted --path-style=absolute | xargs stat -c '%a %n'`)
- [x] 1.2 `git mv` each one to `encrypted_private_<name>.age`; review `chezmoi diff --exclude=externals,scripts <target>` (mode change only)
- [x] 1.3 Apply each target alone (`chezmoi apply --exclude=scripts <target>`), then check (`stat -c '%a' <target>` prints 600)
- [x] 1.4 Propose commit `fix(chezmoi:secrets): deploy every encrypted file as private`

## 2. History scan (F12)

- [x] 2.1 Install gitleaks for the scan (`mise use gitleaks@8.30.1` in the repository, which creates `mise.toml`; `mise trust`) and, in the same step, list `mise.toml` and `hk.pkl` in the temporary repository-files block of `.chezmoiignore` so chezmoi never sees them as targets (`chezmoi managed | grep -cE '^(mise\.toml|hk\.pkl)$'` prints 0)
- [x] 2.2 Scan the full history read-only (`gitleaks git --redact --no-banner --report-path /tmp/opencode/gitleaks-history.json`; exit code noted)
- [x] 2.3 Show the user the redacted summary (rule, file, commit; never the value); for each finding decide: false positive (allowlist entry in `.gitleaks.toml` with a comment) or real secret (stop, rotate first, open a separate change)
- [x] 2.4 Re-run the scan until it exits 0 (`gitleaks git --redact --no-banner; echo $?`)

## 3. Commit-time hook (F12)

- [x] 3.1 Pin hk in `mise.toml` (`mise use hk@2.10.0`); check (`mise ls --current`)
- [x] 3.2 Write `hk.pkl` (amends hk 2.10.0 `Config.pkl`; top-level `steps` `gitleaks` and `detect_private_key`; a `pre-commit` hook overriding `gitleaks` with `scan = "staged"`) (`hk validate`; `hk check --all` exits 0)
- [x] 3.3 Check chezmoi manages none of the new files (`chezmoi managed | grep -cE '^(mise\.toml|hk\.pkl|\.gitleaks\.toml)$'` prints 0)
- [x] 3.4 Install the hook (`hk install --mise`); in a scratch clone (`git clone . /tmp/opencode/dotfiles-hooktest`, copy the uncommitted `mise.toml`, `hk.pkl` and `.gitleaks.toml` if present, trust only that path with `MISE_TRUSTED_CONFIG_PATHS`) prove three cases: a staged token-shaped string generated on the spot is refused (`hk run pre-commit` fails and names the file); a staged private-key header is refused; `git commit --only -- <file>` with an unrelated unstaged edit succeeds and keeps the edit; delete the scratch clone (`test ! -e /tmp/opencode/dotfiles-hooktest`)
- [x] 3.5 Propose commit `feat(chezmoi:secrets): scan commits for secrets with gitleaks through hk`

## 4. One chezmoi (F11)

- [x] 4.1 Check nothing calls the local copy by path (`rg -n 'local/bin/chezmoi' .` finds only this change's own files) and that `chezmoi managed` does not list `.local/bin/chezmoi`
- [x] 4.2 With the user's go (given on 2026-10-31): `rm ~/.local/bin/chezmoi`; `command brew upgrade chezmoi` (`which -a chezmoi | sort -u | wc -l` prints 1; `chezmoi --version` shows 2.73.3)
- [x] 4.3 Record that a minimal non-interactive environment cannot find chezmoi, before and after (`env -i HOME=$HOME PATH=/usr/bin:/bin bash -lc 'command -v chezmoi'` prints nothing), and document the needed `PATH` in `AGENTS.md` (`grep -n shellenv AGENTS.md`)
- [x] 4.4 `chezmoi doctor` shows `latest-version ok`; `chezmoi status` unchanged apart from intended entries (`diff /tmp/opencode/chezmoi-status.before <(chezmoi status --exclude=externals,scripts)`)
- [x] 4.5 Propose commit `docs(chezmoi:docs): note the PATH chezmoi needs in minimal shells`

## 5. Neovim copy (F05)

- [x] 5.1 Report to the user, without touching the repository, whether `~/.config/nvim` has a remote and what is unpushed or uncommitted (`git -C ~/.config/nvim remote -v`; `git -C ~/.config/nvim status -sb`)

## 6. Close

- [x] 6.1 `openspec validate harden-sensitive-targets --strict`; `/opsx-verify harden-sensitive-targets`
- [x] 6.2 Archive (`openspec archive harden-sensitive-targets --yes`)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
