## ADDED Requirements

### Requirement: No leftover files in the source state

The source state SHALL contain no backup, swap or generated leftover files.

#### Scenario: Leftover patterns

- **WHEN** `git ls-files home/ | grep -E '\.(bak|orig|original|swp)$|tmuxline\.conf$'` runs
- **THEN** it prints nothing

### Requirement: Configs only for tools in use

Every managed application config SHALL belong to a tool installed on the machine, or be guarded by a template condition.

#### Scenario: Tool present

- **WHEN** each managed application config directory is mapped to its tool and `command -v <tool>` runs
- **THEN** every tool resolves, or the target is skipped by `.chezmoiignore` on machines without it

### Requirement: Correct theme names

Theme targets SHALL use the upstream spelling (`catppuccin`).

#### Scenario: No misspelling

- **WHEN** `chezmoi managed | grep -iE 'catpuccin|catppucin'` runs
- **THEN** it prints nothing

### Requirement: Terminal remote control restricted

Terminal remote control SHALL only be reachable through an explicit socket, not by any process inside the terminal.

#### Scenario: kitty setting

- **WHEN** the deployed kitty config is searched for `allow_remote_control`
- **THEN** it is set to `socket-only` (or `no`) and `listen_on` names a socket

### Requirement: Portable git configuration

The git configuration SHALL not depend on absolute tool paths or on macOS commands.

#### Scenario: No absolute helper path

- **WHEN** `git config --global --get-all credential.https://github.com.helper` runs
- **THEN** no value contains an absolute path to a package manager prefix

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
