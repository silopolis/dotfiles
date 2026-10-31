## Why

The repository is public and holds age-encrypted secrets, yet nothing scans for leaks, at least one decrypted secret file is deployed readable by other users, and two chezmoi binaries of different versions compete on `PATH`.
These are the cheapest risks to remove and they come first (audit `docs/audits/2026-10-30-environment.md`, findings F10, F11, F12; F05 checked).

## What Changes

- Every `encrypted_` source file also carries `private_`, so its target is 0600 (F10).
- A one-off read-only secret scan of the whole git history; findings are triaged with the user before anything else happens (F12).
- A commit-time secret scan: gitleaks run by hk 2.10.0 as a pre-commit hook on the staged content, both pinned in a repository `mise.toml` (F12).
- One chezmoi binary: the stale `~/.local/bin/chezmoi` is removed and the brew one upgraded (F11).
- A report on the Neovim repository: it now has a remote, and unpushed or uncommitted work is reported to the user, nothing is changed (F05; the external that clones it comes with `fix-chezmoi-config-template`).

## Capabilities

### New Capabilities

- `secret-hygiene`: how secrets are stored, deployed and kept out of the public history.

### Modified Capabilities

None.

## Impact

- Source renames under `dot_config/` for the affected encrypted files; their targets get mode 0600.
- New repository files `mise.toml` and `hk.pkl`, listed in the temporary `.chezmoiignore` block until `adopt-chezmoiroot`, and `.gitleaks.toml` if an allowlist is needed (a dot file, which chezmoi ignores by default).
- `~/.local/bin/chezmoi` deleted (needs the user's go, given on 2026-10-31); brew `chezmoi` upgraded.
- `AGENTS.md` gains one line on the `PATH` that minimal shells need to find chezmoi.
- No change to secret values; no history rewrite in this change (if the scan finds a real secret, rotation and any rewrite become their own change).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
