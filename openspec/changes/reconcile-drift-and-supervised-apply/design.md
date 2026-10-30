## Context

`chezmoi status` on 2026-10-30 (audit section 3):

- `R` for `05-install` and `20-vscodium-extensions` (replaced by the new script set of `make-install-scripts-idempotent`);
- `MM .config/lazygit/config.yml`: lazygit 0.65.0 rewrote the live file on 2026-10-30 to `git.diffRenderers` with `command` and `type: extDiff`; the source still has `git.pagers` with `externalDiffCommand`; `lazygit -c` prints the default `diffRenderers: []`, so the live file is the current schema;
- mode-only entries: `~/.config`, `~/.config/VSCodium` (0700 live), `~/.config/brewfile/Brewfile`, `~/.local/share/fonts`, `~/.local/share/icons`, three LXQt theme directories.

Deployed-only files (`chezmoi unmanaged ~/.config/shell ~/.config/bash ~/.config/zsh`):

- `shell/rc.d/060-libvirt.sh`: one export of the default libvirt URI (`qemu:///system`), never committed;
- `shell/rc.d/190-env_path_user.sh`: pre-rename copy of `050-env_path_user.sh` (commit `5857b60`), adds `~/.local/{bin,sbin}` a second time;
- `bash/bashrc.original`, `zsh/zshrc.bak`: distro and editor leftovers.

A first `.bashrc.original` was archived on 2026-10-26 to `~/Archives/ulap01/`.

## Goals / Non-Goals

**Goals:**

- `chezmoi status` empty after the apply.
- No unexplained file in managed shell folders.
- A repeatable review procedure for full applies.

**Non-Goals:**

- Shell behaviour changes (change `fast-correct-shell-startup`), except removing the duplicate `PATH` snippet, which is pure drift.
- Managing new applications.

## Decisions

### lazygit: re-add the live file

`chezmoi re-add ~/.config/lazygit/config.yml` after reviewing `chezmoi diff`; then launch lazygit once and check the file is unchanged, proving the schema is current.

### VSCodium directory is private

Rename `dot_config/VSCodium` to `dot_config/private_VSCodium`; Electron keeps cookies and tokens there and creates it 0700 itself.

### Libvirt snippet naming

Adopt it as `dot_config/shell/rc.d/060-env_libvirt.sh` (category `env`, like `010` to `050`), and delete the old live name in the same step so it is not loaded twice.

### Dry-run review format

```sh
chezmoi apply --dry-run --verbose > /tmp/opencode/apply-dry-run.txt 2>&1
chezmoi status > /tmp/opencode/apply-status.txt
```

The review groups the status into: mode-only (count), content changes (each shown), scripts to run (each named, with its expected effect), externals.
The user approves the review before the real apply.

## Risks / Trade-offs

- [Risk] A mode change makes something unreadable for another account (umask 027). → The review lists every directory whose mode drops "other" access; anything read by a service account is checked first.
- [Risk] A script does real work during the apply. → Every script was proved a no-op with the harness in `make-install-scripts-idempotent`; the apply runs in a terminal with the user present, and `chezmoi apply` stops at the first failing script.
- [Risk] Deleting `190-env_path_user.sh` changes `PATH` order. → It only duplicates entries already added by `050`; compare `echo $PATH | tr : '\n'` before and after in a new shell.

## Migration Plan

1. Fix lazygit, VSCodium, shell snippets; commit.
2. Dry run, review with the user.
3. `chezmoi apply` (the user present); then `chezmoi status` and a second dry run show nothing.

Rollback: modes and files are recorded in the dry-run output; contents come from git; archived files stay in `~/Archives/ulap01/`.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
