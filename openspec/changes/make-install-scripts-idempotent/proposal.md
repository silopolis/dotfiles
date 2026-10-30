## Why

The install scripts are the reason a full `chezmoi apply` has been off limits since 2026-10-26: `05-install` would lower the system open-files limit, uninstall undeclared brew packages, compile YouCompleteMe, prompt for GitHub login and reinstall a retired extension, all because a package list changed.
Other scripts never re-run when their inputs change, or redo work on every run.
Scripts must become safe to run at any time before the supervised apply (audit findings F01, F02, F24 for scripts, F27).

## What Changes

- **BREAKING (behaviour)**: `run_onchange_before_05-install.sh.tmpl` is split into focused after-scripts, one per manager, each triggered by its own input: brew (Brewfile), mise (`config.toml`), pipx (`packages.json`), krew (`packages.yaml`), vim plugins (`vimrc`).
- No script uninstalls anything: `brew file clean` is replaced by a dry-run report of what is undeclared.
- The open-files limit comes from data, is written only when the file differs, and is never lowered.
- `gh auth login` and the gh-copilot install are dropped; YouCompleteMe is built only on request and only when missing.
- The apt prerequisites script is guarded to the Debian family, installs only missing packages, and calls sudo only then; its list moves to `.chezmoidata/packages.yaml`.
- Broken trigger lines (`\{\{ ... \}\}`) become real hashes; the bat cache script also hashes its themes.
- The VSCodium script skips `.vsix` files whose extension is installed.
- Scripts share a small helper (logging, dry-run mode, sudo guard) and contain no user-specific paths.

## Capabilities

### New Capabilities

- `install-scripts`: what chezmoi's scripts may do, when they run, and how they are checked.

### Modified Capabilities

None.

## Impact

- `.chezmoiscripts/`: one script removed, several added or renamed; every script's content changes, so each runs once on the next apply (designed to be a no-op on a provisioned machine).
- `.chezmoidata/packages.yaml`: apt list and limits data.
- New `.chezmoitemplates/script-lib.sh`.
- Package sets and installed software are unchanged by this change.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
