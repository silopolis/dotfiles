## Why

The repository only works on a machine that already went through it: the bootstrap scripts are broken, paths are tied to one user and to Homebrew's default prefix, and the distro and profile templates are never used.
cem will build on this layer to provision and restore machines, so a clean machine must reach a working environment from one command, with machine, distro and profile data available to templates (audit findings F04, F24, F25, F26, F38; cem task `T-012`).

## What Changes

- One bootstrap path: `scripts/install.sh` fixed (official `get.chezmoi.io` installer, correct `--source` with `.chezmoiroot`); `dot_local/sbin/executable_syssetup.sh` fixed or removed in its favour.
- Data computed once in `.chezmoi.toml.tmpl` and used by templates: `os.id`, `os.like`, `machine.type`, `machine.cpu`, `profile` (at least `desktop` and `mobile`, as planned in cem `T-012`), `brew.prefix`; the dead `os.toml.tmpl` and `profile.toml.tmpl` either become these includes or are deleted; unused prompts and variables removed.
- User and prefix independence: `/home/<user>` and `/home/linuxbrew` replaced by `.chezmoi.homeDir` and `brew.prefix` in templates (gitconfig credential helper, tmux TPM path, Joplin symlinks, aliases), turning those files into templates where needed.
- git identity from data instead of literals.
- Neovim: the external itself comes from `fix-chezmoi-config-template` (location from the `nvim.host`, `nvim.owner`, `nvim.repo` data); this change proves that a machine without GitHub access still bootstraps, and decides whether the external is skipped by profile and whether more values (branch, SSH transport) deserve a data key.
- A tested bootstrap: a Debian-family container (and later a VM) reaches a clean `chezmoi status` with encrypted targets excluded.

## Capabilities

### New Capabilities

- `machine-bootstrap`: what a clean machine needs and gets from this repository, and which data describes the machine.

### Modified Capabilities

- `chezmoi-config`: the template gains distro, profile and prefix data (after `fix-chezmoi-config-template` is archived).

## Impact

- Several plain files become `.tmpl` files; outputs on this laptop stay byte-identical (checked with `chezmoi diff`).
- The Neovim external (`.chezmoiexternals/nvim.toml.tmpl`) may gain a profile condition.
- Input for cem `T-012` (settings layers reading chezmoi data, `DR-005`).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
