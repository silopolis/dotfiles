## ADDED Requirements

### Requirement: Declared KDE settings converge

Each declared KDE setting SHALL hold its declared value after `chezmoi apply`, whatever the file contained before.

#### Scenario: Read back a declared key

- **WHEN** `kreadconfig6 --file kdeglobals --group General --key TerminalApplication` runs after apply
- **THEN** it prints the declared value

### Requirement: Undeclared keys are left alone

Applying KDE settings SHALL not remove or change keys that are not declared.

#### Scenario: Unrelated key survives

- **WHEN** a key absent from the declaration exists in a managed KDE file and `chezmoi apply` runs
- **THEN** the key and its value are unchanged

### Requirement: Quiet status despite KDE rewrites

KDE rewriting its files without changing declared values SHALL not produce `chezmoi status` entries.

#### Scenario: After a Plasma session

- **WHEN** the user logs out and in, changes an undeclared setting, and `chezmoi status` runs
- **THEN** no KDE file is listed

### Requirement: Machine-specific state excluded

Monitor layout and panel layout SHALL not be shared between machines unless templated per machine.

#### Scenario: Not managed

- **WHEN** `chezmoi managed | grep -E 'kwinoutputconfig|plasma-org.kde.plasma.desktop-appletsrc'` runs
- **THEN** it prints nothing, or only per-machine templates

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
