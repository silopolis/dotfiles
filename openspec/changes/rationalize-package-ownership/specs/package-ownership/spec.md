## ADDED Requirements

### Requirement: One owner per tool

Each command-line tool SHALL be installed by exactly one manager, chosen by the priority rule (mise, brew, apt, vendor APT repository, Flatpak; GitHub `.deb` through bin), with a recorded reason for any exception.

#### Scenario: Single resolution

- **WHEN** `which -a <tool> | sort -u` runs for each tool in the ownership table
- **THEN** it prints one path, inside the owning manager's directory

### Requirement: Declared equals installed

Every manager's installed set SHALL match its declaration file.

#### Scenario: Drift report is empty

- **WHEN** the drift report command runs
- **THEN** it lists no undeclared install and no missing declaration for brew, mise, pipx, krew and bin

#### Scenario: No stale mise versions

- **WHEN** `mise prune --dry-run` runs
- **THEN** it lists nothing

### Requirement: GitHub .deb packages through bin

Applications released as `.deb` on GitHub SHALL be fetched by bin into a folder outside `PATH` and installed or upgraded by `sysupgrade.sh` when newer than the installed version.

#### Scenario: Upgrade path

- **WHEN** `sysupgrade.sh` runs after bin fetched a newer `.deb`
- **THEN** the package is upgraded with apt, and running it again does nothing

#### Scenario: bin configuration managed

- **WHEN** `chezmoi managed | grep -c '^\.config/bin/config\.json$'` runs
- **THEN** it prints 1

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
