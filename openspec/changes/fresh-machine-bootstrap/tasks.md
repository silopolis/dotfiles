<!-- Draft tasks: refine at the start of the session (/opsx-continue fresh-machine-bootstrap), after re-checking the facts and agreeing the data schema with cem T-012. -->

## 1. Data

- [ ] 1.1 Agree the data schema (os, machine, profile, brew) with cem `T-012`; record it in this change's design
- [ ] 1.2 Turn `os.toml.tmpl` and `profile.toml.tmpl` into emitting includes, or delete them; remove unused prompts and `$username` (`chezmoi data --format=json | jq '.os, .profile, .brew'`)

## 2. Paths

- [ ] 2.1 gitconfig credential helper, tmux TPM path, terraform completion, brew rc: use `brew.prefix` (`chezmoi diff` empty for each)
- [ ] 2.2 Joplin symlinks: `.chezmoi.homeDir` (`chezmoi diff` empty)
- [ ] 2.3 git identity from data (`git config --global user.email`)
- [ ] 2.4 `rg -n '/home/(tarax|linuxbrew)' home/ --glob '!*.age'` prints nothing outside `.chezmoidata/`

## 3. Bootstrap scripts

- [ ] 3.1 Fix `scripts/install.sh` (`get.chezmoi.io`, source is the repository root)
- [ ] 3.2 Fix or remove `executable_syssetup.sh`
- [ ] 3.3 Document the bootstrap command in `README.md`

## 4. Neovim external

- [ ] 4.1 Add the guarded `git-repo` external with `refreshPeriod = "0"` (`chezmoi managed | grep -c '^\.config/nvim$'`)
- [ ] 4.2 Prove it leaves the existing clone alone (`git -C ~/.config/nvim status -sb` and `rev-parse HEAD` before and after `chezmoi apply --include=externals ~/.config/nvim`)
- [ ] 4.3 Prove the skip path with GitHub authentication unavailable

## 5. Test

- [ ] 5.1 Container bootstrap with encrypted targets excluded; record the command and duration in `docs/`
- [ ] 5.2 Close: validate, verify, archive; update cem `T-012`

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
