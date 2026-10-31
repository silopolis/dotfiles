## Why

Only one file of the GitHub CLI setup is under management: `~/.config/gh/config.yml`.
The rest is done by hand or by an interactive install script: the login (`gh auth login` inside `05-install`, audit finding F01), the extension list (the retired gh-copilot extension, F31) and the decision of what must never be tracked (the login state file in the same directory).
A new machine reaches a working `gh` only through manual steps, and the Neovim external planned in `fix-chezmoi-config-template` uses the presence of that login state file as its offline hint that GitHub access exists, so the file must stay unmanaged on purpose, not by omission.
Audit section 2.7 lists gh as managed, which is true of the settings only.

## What Changes

- Review `config.yml` (git protocol, editor, pager, aliases) and keep what is wanted; it stays a private file.
- Keep the login state out of the repository explicitly: an ignore entry so that a recursive `chezmoi add` of the directory cannot pick it up.
- Declare the extensions in use in chezmoi data and install them from one idempotent script step, replacing the install lines left in `05-install` by `make-install-scripts-idempotent`.
- Decide how a new machine logs in: a documented manual step, or a guarded step that runs only in a terminal and only when no login exists. No token is ever written to the repository.
- The `gh-dash` configuration stays in `manage-dev-tui-configs`; the retired gh-copilot extension and its config stay in `cleanup-dead-config`.

## Capabilities

### New Capabilities

- `gh-config`: GitHub CLI settings and extensions under management, login state excluded.

### Modified Capabilities

None.

## Impact

- `dot_config/gh/` (under `home/` after `adopt-chezmoiroot`), `.chezmoiignore`, `.chezmoidata/packages.yaml` and one install script step.
- Constraint for other changes: the login state file stays unmanaged and untracked, because the Neovim external guard reads it.
- Source: audit findings F01, F31 and the gh part of 2.7 (`docs/audits/2026-10-30-environment.md`); requested on 2026-10-31.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
