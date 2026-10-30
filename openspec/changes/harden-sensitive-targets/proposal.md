## Why

The repository is public and holds age-encrypted secrets, yet nothing scans for leaks, at least one decrypted secret file is deployed readable by other users, and two chezmoi binaries of different versions compete on `PATH`.
These are the cheapest risks to remove and they come first (audit `docs/audits/2026-10-30-environment.md`, findings F10, F11, F12; F05 checked).

## What Changes

- Every `encrypted_` source file also carries `private_`, so its target is 0600 (F10).
- A one-off read-only secret scan of the whole git history; findings are triaged with the user before anything else happens (F12).
- A commit-time secret scan: gitleaks run by hk as a pre-commit hook, both pinned in a repository `mise.toml` (F12).
- One chezmoi binary: the stale `~/.local/bin/chezmoi` is removed and the brew one upgraded (F11).
- Check that the Neovim repository now has a remote and that its work is pushed (F05; the external comes with `fresh-machine-bootstrap`).

## Capabilities

### New Capabilities

- `secret-hygiene`: how secrets are stored, deployed and kept out of the public history.

### Modified Capabilities

None.

## Impact

- Source renames under `dot_config/` for the affected encrypted files; their targets get mode 0600.
- New repository files `mise.toml` and `hk.pkl` (plus `.gitleaks.toml` if an allowlist is needed), listed in the temporary `.chezmoiignore` block until `adopt-chezmoiroot`.
- `~/.local/bin/chezmoi` deleted (needs the user's go); brew `chezmoi` upgraded.
- No change to secret values; no history rewrite in this change (if the scan finds a real secret, rotation and any rewrite become their own change).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
