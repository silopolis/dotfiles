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

### Requirement: Neovim configuration from its own repository

The Neovim configuration SHALL be cloned from its repository by a chezmoi external that never overwrites local work.

#### Scenario: Missing directory is cloned

- **WHEN** `~/.config/nvim` does not exist, GitHub authentication works, and `chezmoi apply` runs
- **THEN** the repository is cloned there

#### Scenario: Existing clone is left alone

- **WHEN** `~/.config/nvim` exists with local commits or uncommitted changes and `chezmoi apply` runs
- **THEN** its `git status` and `HEAD` are unchanged

#### Scenario: No GitHub access

- **WHEN** GitHub authentication is missing and `chezmoi apply` runs
- **THEN** the apply succeeds and reports that the Neovim external was skipped

### Requirement: git identity from data

The git user name and email SHALL come from chezmoi data.

#### Scenario: Rendered identity

- **WHEN** `git config --global user.email` runs
- **THEN** it prints the value of `chezmoi data` key `gitemail`

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
