## ADDED Requirements

### Requirement: Login state stays out of the repository

The GitHub CLI login state (`~/.config/gh/hosts.yml`) SHALL never be a managed target and never be a tracked file.

#### Scenario: Not managed

- **WHEN** `chezmoi managed | grep -c 'gh/hosts.yml'` runs
- **THEN** it prints 0

#### Scenario: Not tracked

- **WHEN** `git ls-files | grep -c 'hosts.yml'` runs
- **THEN** it prints 0

### Requirement: Settings are declared and private

`~/.config/gh/config.yml` SHALL be deployed from the source state with mode 0600.

#### Scenario: Settings mode

- **WHEN** `stat -c '%a' ~/.config/gh/config.yml` runs after apply
- **THEN** it prints 600

### Requirement: Extensions are declared

The GitHub CLI extensions in use SHALL be declared in chezmoi data and installed from that declaration.

#### Scenario: Installed set matches the declaration

- **WHEN** `gh extension list` runs after apply
- **THEN** every extension it lists is declared in `.chezmoidata/packages.yaml` (under `home/` after `adopt-chezmoiroot`) and no declared extension is missing

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
