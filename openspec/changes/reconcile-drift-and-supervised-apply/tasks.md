## 1. Preconditions

- [ ] 1.1 `fix-chezmoi-config-template` and `make-install-scripts-idempotent` are archived (`openspec list` does not show them)
- [ ] 1.2 Fresh status and unmanaged lists (`chezmoi status`; `chezmoi unmanaged ~/.config/shell ~/.config/bash ~/.config/zsh`)

## 2. Drift

- [ ] 2.1 lazygit: review `chezmoi diff ~/.config/lazygit/config.yml`, then `chezmoi re-add ~/.config/lazygit/config.yml`; start and quit lazygit; `chezmoi status ~/.config/lazygit/config.yml` prints nothing
- [ ] 2.2 VSCodium: `git mv home/dot_config/VSCodium home/dot_config/private_VSCodium`; `chezmoi diff ~/.config/VSCodium` shows no mode change
- [ ] 2.3 Libvirt snippet: copy `~/.config/shell/rc.d/060-libvirt.sh` to `home/dot_config/shell/rc.d/060-env_libvirt.sh` (`chezmoi add` then `git mv` if needed); with the user's go delete the old live name; apply the new one alone (`chezmoi apply --exclude=scripts ~/.config/shell/rc.d/060-env_libvirt.sh`); new shell: `echo $LIBVIRT_DEFAULT_URI` unchanged
- [ ] 2.4 With the user's go: delete `~/.config/shell/rc.d/190-env_path_user.sh`; new shell: `~/.local/bin` appears once in `PATH`, other entries in the same order
- [ ] 2.5 Move `~/.config/bash/bashrc.original` and `~/.config/zsh/zshrc.bak` to `~/Archives/ulap01/` (`ls ~/Archives/ulap01/`)
- [ ] 2.6 `chezmoi unmanaged ~/.config/shell ~/.config/bash ~/.config/zsh` prints nothing (or only ignored entries)
- [ ] 2.7 Propose commits `fix(git:lazygit): adopt the lazygit 0.65 config schema`, `fix(editor:vscodium): keep the config directory private`, `feat(shell:env): manage the libvirt default connection`

## 3. Supervised apply

- [ ] 3.1 Dry run (`chezmoi apply --dry-run --verbose > /tmp/opencode/apply-dry-run.txt 2>&1`; `chezmoi status > /tmp/opencode/apply-status.txt`)
- [ ] 3.2 Grouped review for the user: mode-only count and the list of directories losing "other" access; every content change with its diff; every script with its expected effect (no-op); externals to refresh
- [ ] 3.3 With the user's approval and presence: `chezmoi apply`
- [ ] 3.4 `chezmoi status` prints nothing; `chezmoi apply --dry-run --verbose` shows nothing to do; `stat -c '%a' ~/.config/VSCodium` prints 700
- [ ] 3.5 New login and non-login shells start without errors (`zsh -i -c exit`; `zsh -l -i -c exit`); KDE session still fine after a log out and in

## 4. Close

- [ ] 4.1 `AGENTS.md`: full apply allowed after a dry run reviewed with the user
- [ ] 4.2 Tick in cem's checklist: "Later steps: one supervised full chezmoi apply" and 6.4 "the extension script runs once"
- [ ] 4.3 `openspec validate reconcile-drift-and-supervised-apply --strict`; `/opsx-verify reconcile-drift-and-supervised-apply`
- [ ] 4.4 Archive (`openspec archive reconcile-drift-and-supervised-apply --yes`)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
