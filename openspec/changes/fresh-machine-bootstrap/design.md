## Context

- `scripts/install.sh` was fixed in `adopt-chezmoiroot` (installer from `get.chezmoi.io`, `--source` is the repository root); it was downloading from `git.io` and passing `--source=<directory of the script>`, which is `scripts/`.
- `dot_local/sbin/executable_syssetup.sh`: `[ $(type curl &>/dev/null) ]` is always false (lines 8, 14), so curl is never installed and chezmoi's branches are swapped; line 6 fails under `set -u` without an argument.
- `.chezmoitemplates/os.toml.tmpl` computes `$osid`, WSL and Steam Deck flags but emits nothing; `profile.toml.tmpl` declares unused booleans.
- Literal paths: `dot_config/git/gitconfig:45,48` (`gh` credential helper), `dot_config/tmux/tmux.conf:199` (TPM), `dot_config/symlink_Joplin` and `symlink_joplin-desktop` (absolute targets under a cloud-synced folder), `dot_config/shell/aliases:293-294` (terraform completion), `dot_config/shell/rc.d/110-pkg_brew.sh:2,17`.
- Neovim lives in `~/.config/nvim` (LazyVim, OpenSpec), private remote created on 2026-10-30.
- cem `T-012` plans profiles (desktop, mobile) next to machine and distro, read by `cem settings` (`DR-005`).
- The age identity needs a passphrase at first apply; a container test cannot have it.

## Goals / Non-Goals

**Goals:**

- `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply silopolis` (or `scripts/install.sh` from a clone) works on a clean Debian-family system.
- Templates read machine facts from data, not from literals.

**Non-Goals:**

- Non-Debian distros beyond guards (Arch or Omarchy restore is cem `T-011`).
- Choosing the package manager per tool (change `rationalize-package-ownership`).

## Decisions

### Data schema (first cut, refined with cem `T-012`)

```toml
[data.os]       # id = "kali", like = ["debian"], wsl = false
[data.machine]  # type = "laptop", cpu = { cores = 6, threads = 12 }
[data]          # profile = "mobile"  (promptChoiceOnce: desktop, mobile, server, ephemeral)
[data.brew]     # prefix = "/home/linuxbrew/.linuxbrew"
```

### Neovim external

The external, its `<host>/<owner>/<repo>` data and its offline guard (a clone or a GitHub CLI login file must exist) are defined in `fix-chezmoi-config-template`.
This change only builds on it:

- skip it for profiles that do not need Neovim, if cem `T-012` says so;
- optional extra data keys (`nvim.branch`, `nvim.protocol` for SSH) if they prove useful;
- prove in the container that a machine without a GitHub login bootstraps and skips it.

### Container test

A `podman` (or `docker`) Debian or Kali image, running the bootstrap with `--exclude=encrypted` and a non-interactive profile; success is a zero exit and an empty `chezmoi status --exclude=encrypted`.
Brew in a container is slow, so a first stage may run the package scripts in dry-run mode, but not through `CHEZMOI_SCRIPTS_DRY_RUN=1 chezmoi apply`: chezmoi records a `run_onchange_` script as run once it exits 0, so a later real apply in the same guest would skip it.
A first stage that wants the dry run renders the scripts and runs them under the variable outside `chezmoi apply`, as the harness of `make-install-scripts-idempotent` does, or starts from a throwaway state.

## Risks / Trade-offs

- [Risk] Templating plain files changes their output subtly. → `chezmoi diff` must be empty on this laptop after each conversion.
- [Risk] A private-repository external fails during `apply` and aborts it. → The guard from `fix-chezmoi-config-template` skips it without a clone or a login file; test in a container without GitHub authentication.
- [Risk] Profile values chosen here conflict with cem `T-012`. → Keep the schema minimal and record it in cem before implementing.

## Open Questions

- Profile names and how many (cem `T-012`).
- Keep `syssetup.sh` (system bootstrap with apt) or fold it into `scripts/install.sh`?
- Does the btrfs and snapper part of the apt prerequisites belong to a `btrfs` machine flag?
- Which extra Neovim values (branch, SSH transport) deserve a prompt, and is the external skipped for some profiles?

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
