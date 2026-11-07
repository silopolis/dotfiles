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

- [x] 3.1 Fix `scripts/install.sh` (`get.chezmoi.io`, source is the repository root); done in `adopt-chezmoiroot`, the end-to-end proof stays with group 4
- [ ] 3.2 Fix or remove `executable_syssetup.sh`
- [ ] 3.3 Document the bootstrap command in `README.md`

## 4. Neovim external (defined in `fix-chezmoi-config-template`)

- [ ] 4.1 Decide with cem `T-012` whether the external is skipped for some profiles, and if so add the condition to `.chezmoiexternals/nvim.toml.tmpl` (`chezmoi --override-data '{"profile":"<name>"}' managed | grep -c '^\.config/nvim$'` prints 0)
- [ ] 4.2 Decide whether the branch and an SSH transport get data keys (`nvim.branch`, `nvim.protocol`); if yes, add the questions and use them in the external (`chezmoi execute-template < .chezmoiexternals/nvim.toml.tmpl`)
- [ ] 4.3 Prove the skip path with no GitHub login in the container (bootstrap exits 0; `chezmoi managed | grep -c '^\.config/nvim$'` prints 0); once `add-private-store-external` is applied, the private store external is skipped too (`chezmoi managed | grep -c '^\.local/share/chezmoi-private$'` prints 0)

## 5. Test

- [ ] 5.1 Container bootstrap with encrypted targets excluded; record the command and duration in `docs/`
- [ ] 5.2 Close: validate, verify, archive; update cem `T-012`

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
