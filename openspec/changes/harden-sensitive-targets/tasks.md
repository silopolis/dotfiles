## 1. Private decrypted targets (F10)

- [ ] 1.1 List encrypted sources without `private_` (`git ls-files | grep encrypted_ | grep -v private_`) and their deployed modes (`chezmoi managed --include=encrypted --path-style=absolute | xargs stat -c '%a %n'`)
- [ ] 1.2 `git mv` each one to `encrypted_private_<name>.age`; review `chezmoi diff --exclude=externals,scripts <target>` (mode change only)
- [ ] 1.3 Apply each target alone (`chezmoi apply --exclude=scripts <target>`), then check (`stat -c '%a' <target>` prints 600)
- [ ] 1.4 Propose commit `fix(chezmoi:secrets): deploy every encrypted file as private`

## 2. History scan (F12)

- [ ] 2.1 Install gitleaks for the scan (`mise use gitleaks@8.30.1` in the repository, which creates `mise.toml`; `mise trust`)
- [ ] 2.2 Scan the full history read-only (`gitleaks git --redact --no-banner --report-path /tmp/opencode/gitleaks-history.json`; exit code noted)
- [ ] 2.3 Show the user the redacted summary (rule, file, commit; never the value); for each finding decide: false positive (allowlist entry in `.gitleaks.toml` with a comment) or real secret (stop, rotate first, open a separate change)
- [ ] 2.4 Re-run the scan until it exits 0 (`gitleaks git --redact --no-banner; echo $?`)

## 3. Commit-time hook (F12)

- [ ] 3.1 Pin hk in `mise.toml` (`mise use hk@1.56.1`); check (`mise ls --current`)
- [ ] 3.2 Write `hk.pkl` (amends hk 1.56.1 `Config.pkl`; steps `gitleaks`, `detect_private_key`; hooks `pre-commit`, `check`), modelled on cem's `hk.pkl` (`hk validate` or `hk check --all`)
- [ ] 3.3 Add `mise.toml`, `hk.pkl` to the temporary repository-files block of `.chezmoiignore` (`chezmoi managed | grep -cE '^(mise\.toml|hk\.pkl)$'` prints 0)
- [ ] 3.4 Install the hook (`hk install`); prove it refuses a secret in a scratch clone (`git clone . /tmp/opencode/dotfiles-hooktest`, stage a token-shaped test string, `hk run pre-commit` fails); delete the scratch clone
- [ ] 3.5 Propose commit `feat(chezmoi:secrets): scan commits for secrets with gitleaks through hk`

## 4. One chezmoi (F11)

- [ ] 4.1 Check nothing calls the local copy by path (`rg -n 'local/bin/chezmoi' .`) and that `chezmoi managed` does not list `.local/bin/chezmoi`
- [ ] 4.2 With the user's go: `rm ~/.local/bin/chezmoi`; `brew upgrade chezmoi` (`which -a chezmoi`; `chezmoi --version`)
- [ ] 4.3 Check a minimal non-interactive environment still finds chezmoi or document the needed `PATH` in `AGENTS.md` (`env -i HOME=$HOME PATH=/usr/bin:/bin bash -lc 'command -v chezmoi'`)
- [ ] 4.4 `chezmoi doctor` shows `latest-version ok`; `chezmoi status` unchanged apart from intended entries

## 5. Neovim copy (F05)

- [ ] 5.1 Check `git -C ~/.config/nvim remote -v` lists a private remote and `git -C ~/.config/nvim status -sb` shows nothing ahead; otherwise tell the user

## 6. Close

- [ ] 6.1 `openspec validate harden-sensitive-targets --strict`; `/opsx-verify harden-sensitive-targets`
- [ ] 6.2 Archive (`openspec archive harden-sensitive-targets --yes`)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
