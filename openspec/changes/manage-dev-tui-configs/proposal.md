## Why

Several terminal tools in daily use have hand-made configuration that is not managed (k9s, lazydocker, nnn, ranger, superfile, htop, glow, fastfetch, gh-dash, gitui), and the old laptop's versions of some (htop, glow, lazydocker, ranger) were flagged for reconciliation in cem (audit finding F36; cem task `T-009` known cases).

## What Changes

- For each tool: compare this machine's config with the archived one, decide the version to keep, and manage it (plain file, or `modify_` when the tool rewrites it).
- Skip tools whose config is only defaults.
- Apply the Catppuccin theme consistently where the tool supports it, through externals as for bat and btop.

## Capabilities

### New Capabilities

- `tui-configs`: terminal tool configurations under management.

### Modified Capabilities

None.

## Impact

- New targets under `~/.config/<tool>`; possible new externals for themes.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
