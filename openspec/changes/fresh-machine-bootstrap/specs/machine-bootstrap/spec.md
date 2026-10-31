## ADDED Requirements

### Requirement: One-command bootstrap

A clean Debian-family system SHALL reach a working environment from a single documented command, without editing any file by hand.

#### Scenario: Container bootstrap

- **WHEN** the documented bootstrap command runs in a clean Debian-family container with encrypted targets excluded
- **THEN** it exits 0 and `chezmoi status --exclude=encrypted` prints nothing afterwards

#### Scenario: Bootstrap script from a clone

- **WHEN** `scripts/install.sh` runs from a fresh clone
- **THEN** chezmoi is initialized with that clone as its working tree and `chezmoi source-path` ends with `/home`

### Requirement: User and prefix independence

Managed files SHALL not contain the user's home path or the Homebrew prefix as literals; they come from `.chezmoi.homeDir` and data.

#### Scenario: No literal paths in targets' sources

- **WHEN** `rg -n '/home/(tarax|linuxbrew)' home/ --glob '!*.age'` runs
- **THEN** it prints nothing outside `.chezmoidata/`

#### Scenario: Same output on this laptop

- **WHEN** a plain file is turned into a template to remove a literal path
- **THEN** `chezmoi diff` for its target is empty on this laptop

### Requirement: Bootstrap does not depend on GitHub access

A machine without a GitHub login SHALL still bootstrap; the Neovim external (defined by the `neovim-config` capability) is skipped.

#### Scenario: No GitHub login

- **WHEN** the bootstrap runs in a clean container where `~/.config/gh/hosts.yml` does not exist
- **THEN** it exits 0 and `chezmoi managed | grep -c '^\.config/nvim$'` prints 0

### Requirement: git identity from data

The git user name and email SHALL come from chezmoi data.

#### Scenario: Rendered identity

- **WHEN** `git config --global user.email` runs
- **THEN** it prints the value of `chezmoi data` key `gitemail`

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
