## Why

The KDE Plasma setup (theme, shortcuts, window rules, input, power, Konsole, Dolphin, Kate) is tuned by hand and lives only on this laptop; a reinstall or a second machine would lose it.
KDE rewrites its config files constantly, so copying them whole into chezmoi would produce permanent drift (audit finding F36; cem checklist "Later steps: port Omarchy-style preferences into KDE", "KDE tiling").

## What Changes

- Choose the management technique for KDE settings (the design session compares them):
  - `modify_` templates that set only selected keys in each file;
  - `run_onchange_` scripts calling `kwriteconfig6` with values from `.chezmoidata/kde.yaml`;
  - whole-file management for the few files KDE does not rewrite.
- Bring under management the high-value, machine-independent settings: `kdeglobals` (colors, icons, terminal), `kglobalshortcutsrc`, `kwinrc` and `kwinrulesrc`, `kcminputrc` and touchpad, `konsolerc` and Konsole profiles, `dolphinrc`, `katerc`, `krunnerrc`, `plasmanotifyrc`, `kscreenlockerrc`, `powerdevilrc`, color schemes under `~/.local/share/color-schemes`.
- Leave machine-specific state out (monitor layout, panel layout), or template it per machine later.

## Capabilities

### New Capabilities

- `kde-desktop-config`: which KDE settings are declared, how they are applied, and how drift stays quiet.

### Modified Capabilities

None.

## Impact

- New data file and templates or scripts; no change to KDE until applied; settings may need a Plasma restart or a new session.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
