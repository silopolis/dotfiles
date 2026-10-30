## ADDED Requirements

### Requirement: Configured terminal fonts are installed

Every font family named in a managed terminal configuration SHALL be installed by this repository.

#### Scenario: Font resolves

- **WHEN** `fc-match "<family named in kitty.conf>"` runs
- **THEN** it returns that family, not a fallback

#### Scenario: Same family everywhere

- **WHEN** the font family settings of kitty, alacritty and qterminal are compared
- **THEN** they name the same family

### Requirement: Declared font set

The fonts of cem checklist 6.3 (or the replacements agreed in this change) SHALL be declared in the source state and installed on apply.

#### Scenario: Fonts present after apply

- **WHEN** `fc-list : family | sort -u` runs after `chezmoi apply`
- **THEN** it lists every declared family

#### Scenario: Font cache refreshed on change

- **WHEN** the declared font set changes and `chezmoi apply` runs
- **THEN** the font cache is rebuilt without manual action

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
