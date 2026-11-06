## Why

GUI applications installed by mise from upstream tarballs, Obsidian first, come with no desktop entry: they are missing from the KDE application menu and launcher, and no handler is registered for their URL schemes.
The visible symptom is the Obsidian Web Clipper: Firefox answers "The address wasn't understood" on every `obsidian://` link, because `xdg-mime query default x-scheme-handler/obsidian` returns nothing.

The 2026-10-30 audit (`docs/audits/2026-10-30-environment.md`) has no finding for this gap; it was noticed after the audit.
It sits between section 2.4 (mise as the first install channel, `dot_config/mise/config.toml`) and finding F36 (valuable configuration not managed, section 2.8), and it depends on `manage-xdg-basics`, which comes from F36.

## What Changes

- Declare the GUI applications installed by mise that need desktop integration, as template data, with Obsidian as the first entry.
- Generate one desktop entry per declared application under `~/.local/share/applications/`, launching the binary through a path that survives mise upgrades and passing URLs and files to it.
- Install an icon for each declared application where the user icon theme can find it.
- Declare the URL schemes each application handles in its desktop entry (`x-scheme-handler/obsidian` for Obsidian).
- Add the matching default associations to `~/.config/mimeapps.list`, the file that `manage-xdg-basics` brings under management.
- Refresh the desktop database and the KDE service cache after a desktop entry changes, so the menu and the handlers are up to date without logging out.

## Capabilities

### New Capabilities

- `mise-app-desktop-entries`: desktop entries, icons and URL scheme handlers for GUI applications installed by mise.

### Modified Capabilities

None.
The `xdg-basics` capability, which will own `mimeapps.list`, is not archived yet; this change adds its associations to that file once `manage-xdg-basics` has landed.

## Impact

- Depends on `manage-xdg-basics` being applied and archived first, so that `mimeapps.list` has a single owner.
- New template data under `.chezmoidata/`, new templated targets under `dot_local/share/applications/` and `dot_local/share/icons/`, one new `run_onchange_after_` script.
- New lines in the managed `mimeapps.list`.
- Uses `update-desktop-database` (desktop-file-utils) and `kbuildsycoca6` (KDE), both already installed on the main machine; nothing needs sudo or writes outside `$HOME`.
- Firefox may ask once to confirm the new handler for `obsidian://` links.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
