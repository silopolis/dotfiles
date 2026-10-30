## 1. Before

- [ ] 1.1 Save the current config and effective settings (`cp ~/.config/chezmoi/chezmoi.toml /tmp/opencode/chezmoi.toml.before`; `chezmoi dump-config --format=json > /tmp/opencode/dump-config.before.json`)
- [ ] 1.2 Decrypt check baseline: pick one encrypted target (`chezmoi managed --include=encrypted | head -1`) and confirm `chezmoi cat ~/<it> >/dev/null` exits 0

## 2. Template

- [ ] 2.1 Move `pager` and `color` above the includes and add `encryption = "age"` and `umask = 0o027` there (paths under `home/` after `adopt-chezmoiroot`)
- [ ] 2.2 Add the `[age]` table with the identity path and the recipient copied from the current config
- [ ] 2.3 `[diff]`: replace `diff.exclude = ["externals"]` with `exclude = ["externals"]`
- [ ] 2.4 `[git]`: remove the `commitMessageTemplate` prompt line
- [ ] 2.5 Render non-interactively and parse (`chezmoi execute-template --init --promptString email=x,gitemail=x,firstname=x,name=x < home/.chezmoi.toml.tmpl | python3 -c 'import sys,tomllib; d=tomllib.loads(sys.stdin.read()); print(d["encryption"], oct(d["umask"]), d["pager"], d["diff"]["exclude"], sorted(d["data"]["github"]))'`)

## 3. Remove the frozen config

- [ ] 3.1 `git rm -r home/dot_config/chezmoi`; check the target is left alone (`chezmoi apply --dry-run --verbose ~/.config/chezmoi 2>&1 | grep -c remove` prints 0)
- [ ] 3.2 Regenerate in a terminal (`chezmoi init`); diff (`diff /tmp/opencode/chezmoi.toml.before ~/.config/chezmoi/chezmoi.toml`): expected data changes are machine type and cpu counts only, plus the new keys
- [ ] 3.3 Effective settings (`chezmoi dump-config --format=json | jq -c '{u: .umask, p: .pager, d: .diff.exclude, e: .encryption}'`)
- [ ] 3.4 Decryption still works (task 1.2 command); `chezmoi doctor` shows no `suspicious-entries` warning
- [ ] 3.5 Propose commit `fix(chezmoi:config): configure encryption, umask and diff in the template`

## 4. Brew hook mode (F41)

- [ ] 4.1 In `home/dot_config/shell/rc.d/110-pkg_brew.sh`, after `chezmoi re-add "$target"`, add `chezmoi apply --exclude=scripts "$target"` (`zsh -n` and `bash -n` on the file)
- [ ] 4.2 Apply the rc file alone (`chezmoi apply --exclude=scripts ~/.config/shell/rc.d/110-pkg_brew.sh`); on the next brew change, check `chezmoi status ~/.config/brewfile/Brewfile` is empty
- [ ] 4.3 Propose commit `fix(pkg:brew): re-apply the Brewfile after re-adding it`

## 5. Close

- [ ] 5.1 Record in this change's notes the count of targets whose mode the next full apply will change (`chezmoi status | grep -c '^.M'`), for `reconcile-drift-and-supervised-apply`
- [ ] 5.2 `openspec validate fix-chezmoi-config-template --strict`; `/opsx-verify fix-chezmoi-config-template`
- [ ] 5.3 Archive (`openspec archive fix-chezmoi-config-template --yes`)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
