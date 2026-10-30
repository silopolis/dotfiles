## ADDED Requirements

### Requirement: Application state is ignored on purpose

Application state folders and files under `~/.config` SHALL be matched by commented `.chezmoiignore` patterns.

#### Scenario: Short unmanaged report

- **WHEN** `chezmoi unmanaged ~/.config | wc -l` runs
- **THEN** it prints at most 30, and each listed entry is a reviewed candidate for management

### Requirement: Ignore patterns are effective

Every pattern in `.chezmoiignore` SHALL match at least one target path or document why it exists.

#### Scenario: No dead patterns

- **WHEN** each pattern of `.chezmoiignore` is checked against the home directory and the source state
- **THEN** every pattern matches something or carries a comment explaining it

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
