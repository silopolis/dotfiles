## ADDED Requirements

### Requirement: Customized TUI configs are managed

Every terminal tool whose configuration differs from its defaults SHALL have that configuration in the source state.

#### Scenario: Managed list covers the tools

- **WHEN** `chezmoi unmanaged ~/.config` runs
- **THEN** no directory of the tools in this change's list appears, except ignored state files

### Requirement: Tool rewrites do not cause drift

When a tool rewrites its own config at runtime, managing it SHALL not produce permanent `chezmoi status` entries.

#### Scenario: Use then status

- **WHEN** a managed tool is started, used and closed, then `chezmoi status` runs
- **THEN** its config is not listed

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
