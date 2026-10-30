## Why

`chezmoi unmanaged ~/.config` lists more than 200 entries, most of them application state (Electron and Chromium profiles, sync clients, virtualization, VSCodium runtime files), so it cannot serve as a drift report (audit finding F36).
Once the valuable configs are managed (KDE, XDG, AI tools, TUIs), the rest should be ignored on purpose, leaving a short list worth reviewing.

## What Changes

- Add `.chezmoiignore` patterns, grouped by kind with a comment each, for application state that must never be managed.
- Remove the home-directory entries that are unrelated to the source (French user directories, `snap`, `kind`, ...) if they no longer serve a purpose, or keep them grouped and commented.
- Add a reviewable "unmanaged report" command (alias or cem task) showing what remains.

## Capabilities

### New Capabilities

- `app-state-exclusion`: what is deliberately not managed, and the report of what is left.

### Modified Capabilities

None.

## Impact

- `.chezmoiignore` only; no target changes.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
