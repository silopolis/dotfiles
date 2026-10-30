## ADDED Requirements

### Requirement: Ported aliases and functions

The aliases and functions listed in cem checklist 4.1 SHALL be available in interactive bash and zsh, with this machine's existing definition kept on a name clash.

#### Scenario: Aliases defined in both shells

- **WHEN** `alias c t g ll` runs in a new interactive zsh and in a new interactive bash
- **THEN** each name is defined in both

#### Scenario: Clash rule

- **WHEN** `alias n` runs in a new shell
- **THEN** it prints the definition that existed on this machine before the port

### Requirement: Aliases do not break or shadow by accident

Every alias and function SHALL refer to an available command or be guarded by `command -v`, and SHALL not hide a system command unless a comment says so.

#### Scenario: Broken entries removed

- **WHEN** each alias target command is checked with `command -v` in a new shell
- **THEN** every unguarded alias resolves

#### Scenario: Shadowing is intended

- **WHEN** a defined alias name also resolves to a binary in `PATH`
- **THEN** the alias definition carries a comment explaining why it shadows it

### Requirement: Shell syntax

Alias and function files SHALL pass both shells' syntax checks.

#### Scenario: Syntax checks

- **WHEN** `zsh -n` and `bash -n` run on every changed alias and function file
- **THEN** both exit 0

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
