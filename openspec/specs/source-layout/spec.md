# source-layout Specification

## Purpose
TBD - created by archiving change adopt-chezmoiroot. Update Purpose after archive.
## Requirements
### Requirement: Source state under home/

The chezmoi source state SHALL live in the `home/` directory of the repository, selected by a `.chezmoiroot` file at the repository root.

#### Scenario: Source directory

- **WHEN** `chezmoi source-path` runs
- **THEN** it prints the repository path followed by `/home`

#### Scenario: No source entries at the root

- **WHEN** `git ls-files | grep -vx '.chezmoiroot' | grep -E '^(dot_|symlink_|empty_|private_|executable_|\.chezmoi[a-z]+)'` runs at the repository root
- **THEN** it prints nothing (`.chezmoiroot` itself is the one special file that stays at the root)

### Requirement: Repository files stay outside the source state

Files that run the repository (agent guide, docs, specs, tool pins, hooks, bootstrap script, README) SHALL live outside `home/` and SHALL need no `.chezmoiignore` entry.

#### Scenario: No repository entries in the ignore file

- **WHEN** `grep -nE '^(AGENTS\.md|README\.md|TODO\.md|docs|openspec|scripts|mise\.toml|hk\.pkl)$' home/.chezmoiignore` runs
- **THEN** it prints nothing

#### Scenario: Repository files are not targets

- **WHEN** `chezmoi managed | grep -E '^(AGENTS\.md|README\.md|docs|openspec|scripts|mise\.toml|hk\.pkl)'` runs
- **THEN** it prints nothing

### Requirement: The layout move changes no target

Moving the source state SHALL leave the managed target list, the target state and the pending scripts unchanged.

#### Scenario: Before and after snapshots match

- **WHEN** `chezmoi managed`, `chezmoi status` and `chezmoi diff --exclude=externals` are captured before and after the move
- **THEN** each pair is identical, except script entries whose content changed only by a source path fix

### Requirement: No hard-coded source path

Templates and scripts SHALL reach source files through `.chezmoi.sourceDir` or relative `include` calls, never through a literal path.

#### Scenario: No literal source path

- **WHEN** `rg -n '\.local/share/chezmoi' home/` runs
- **THEN** it prints nothing

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->

