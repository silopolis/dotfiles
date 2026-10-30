## Why

Tools come from five managers with overlaps (the same tool from brew and mise), stale versions (48 unreferenced mise installs), undeclared installs (pipx, a brew cask), a pinned and outdated `bin`, and a pending plan to move from brew to mise.
The rule "mise, then brew, then apt, then vendor repository, then Flatpak; GitHub `.deb` through bin" is agreed but not applied (audit findings F16, F28; cem checklist 4.5, 6.1, 6.6, "Later steps: brew to mise").

## What Changes

- An ownership table: for each tool, one owning manager following the priority rule, with the reason when the rule is not followed.
- Duplicates removed from the non-owning manager (each removal approved).
- Stale mise versions pruned; pipx list made to match what is installed (declare or remove).
- Omarchy launchers missing here become mise entries (checklist 4.5).
- GitHub `.deb` packages through bin: a folder outside `PATH`, installation on update in `sysupgrade.sh`, bin's config under chezmoi (checklist 6.1).
- The `bin` external refreshed or replaced by a managed install.
- The Omarchy package list mapped to this machine's managers (checklist 6.6).
- A drift report command listing, per manager, what is installed but undeclared and declared but missing.

## Capabilities

### New Capabilities

- `package-ownership`: one declared owner per tool, and a way to see drift.

### Modified Capabilities

None.

## Impact

- `dot_config/brewfile/Brewfile`, `dot_config/mise/config.toml`, `dot_config/pipx/packages.json`, `.chezmoidata/packages.yaml`, `.chezmoiexternals/bin.toml.tmpl`, `dot_local/sbin/executable_sysupgrade.sh`, new `dot_config/bin/config.json`.
- Uninstalls (each approved) and installs on this machine.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
