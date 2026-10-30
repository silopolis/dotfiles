## ADDED Requirements

### Requirement: README explains the repository

`README.md` SHALL state the repository's purpose, its relation to cem, the bootstrap command, the layout and how changes are made.

#### Scenario: Sections present

- **WHEN** `grep -c '^## ' README.md` runs
- **THEN** it prints at least 4, and the bootstrap command appears in a code block

### Requirement: No stale task list

Open work SHALL be tracked as OpenSpec changes or cem backlog entries, not in a free-form TODO file.

#### Scenario: TODO retired

- **WHEN** `git ls-files TODO.md` runs
- **THEN** it prints nothing

### Requirement: Repository documentation is not deployed

Documentation about the repository or its configs SHALL not be deployed into the home directory.

#### Scenario: No deployed docs

- **WHEN** `chezmoi managed | grep -iE '(README|AGENTS)\.md$'` runs
- **THEN** it prints nothing

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
