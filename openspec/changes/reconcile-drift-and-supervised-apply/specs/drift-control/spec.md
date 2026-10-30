## ADDED Requirements

### Requirement: Source and live state agree

After a full apply, chezmoi SHALL report no pending change.

#### Scenario: Empty status

- **WHEN** `chezmoi status` runs after the supervised apply
- **THEN** it prints nothing

#### Scenario: Idempotent apply

- **WHEN** `chezmoi apply --dry-run --verbose` runs right after an apply
- **THEN** it reports no file change and no script to run

### Requirement: Application-migrated configs are current in the source

When an application rewrites its managed config to a newer schema, the source SHALL carry that schema, so applying and launching the application leave the file unchanged.

#### Scenario: lazygit round trip

- **WHEN** the lazygit config is applied and lazygit is started and closed
- **THEN** `chezmoi status ~/.config/lazygit/config.yml` prints nothing

### Requirement: Private application directories

Directories where applications keep credentials or session data SHALL be deployed private (0700).

#### Scenario: VSCodium directory

- **WHEN** `stat -c '%a' ~/.config/VSCodium` runs after the apply
- **THEN** it prints 700

### Requirement: No unexplained files in managed shell folders

Managed shell folders SHALL hold only managed files, or files ignored on purpose.

#### Scenario: Unmanaged shell files

- **WHEN** `chezmoi unmanaged ~/.config/shell ~/.config/bash ~/.config/zsh` runs
- **THEN** it prints nothing, or only entries also matched by `.chezmoiignore`

#### Scenario: No duplicate user bin entries

- **WHEN** a new interactive shell prints `echo "$PATH" | tr ':' '\n' | grep -c "^$HOME/.local/bin$"`
- **THEN** it prints 1

### Requirement: Supervised full apply

A full apply SHALL be preceded by a dry run whose mode changes, content changes and scripts are reviewed with the user.

#### Scenario: Review artefacts exist

- **WHEN** the full apply is about to run
- **THEN** the dry-run output and the grouped review (mode-only count, content changes, scripts, externals) have been shown to the user and approved

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
