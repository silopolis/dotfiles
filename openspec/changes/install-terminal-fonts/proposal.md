## Why

kitty, alacritty and qterminal are configured for `VictorMono NF`, and lazygit and lsd expect Nerd Font icons, but no Nerd Font is installed, so terminals fall back to a plain monospace font and icons render as boxes.
The migration also listed fonts to install (audit finding F17; cem checklist 6.3: Cascadia Mono NF, JetBrains Mono NF, iA Writer, Libertinus).

## What Changes

- Decide the terminal font (keep VictorMono NF or switch to one of the checklist fonts) and align every terminal config with it.
- Install the chosen Nerd Fonts and the checklist fonts in a declared, reproducible way, with the font cache refreshed when they change.

## Capabilities

### New Capabilities

- `terminal-fonts`: which fonts the environment provides and how terminals use them.

### Modified Capabilities

None.

## Impact

- `.chezmoiexternals/` (font archives) or a package manager entry; a `run_onchange_after_` font cache script.
- `dot_config/kitty/private_kitty.conf`, `dot_config/alacritty/font.toml`, `dot_config/qterminal.org/qterminal.ini.tmpl` if the font changes.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
