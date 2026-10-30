## Why

Since 2026-10-26, files have been applied one by one because a full apply was unsafe.
Once the config template and scripts are fixed, the remaining drift must be resolved and one supervised full apply run, so that `chezmoi apply` becomes routine again and `chezmoi status` means something (audit findings F13, F14, F15; cem checklist "Later steps: one supervised full chezmoi apply", and 6.4 "the extension script runs once").

## What Changes

- lazygit: bring the live config (already migrated by lazygit 0.65 to its new schema) back into the source (F14).
- VSCodium: the source directory becomes `private_VSCodium`, keeping the live 0700 (F13).
- Deployed-only files inside managed folders (F15):
  - the libvirt default-URI snippet is adopted into the source as an `rc.d` file following the naming scheme;
  - the stale duplicate `PATH` snippet is deleted;
  - `.bak` and `.original` copies are archived outside the home config, then deleted.
- One supervised full apply: dry run captured, reviewed with the user (mode changes from umask 027, content changes, scripts), then applied.
- `AGENTS.md` safety rule relaxed: full apply allowed after a reviewed dry run.

## Capabilities

### New Capabilities

- `drift-control`: source and live state agree, and the drift that remains is visible and explained.

### Modified Capabilities

None.

## Impact

- Modes of most managed files change to 0640 or 0750 (umask 027).
- Every new script from `make-install-scripts-idempotent` runs once (expected no-ops).
- New source file under `dot_config/shell/rc.d/`; one live file deleted; two archived.
- cem checklist lines ticked.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
