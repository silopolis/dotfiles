## ADDED Requirements

### Requirement: One roadmap file

The repository SHALL keep one hand-maintained `ROADMAP.md` at its root that lists every OpenSpec change, active or archived, exactly once, with its order, its dependencies and the reason for its place.

#### Scenario: Every change has a row

- **WHEN** `mise run roadmap --check` runs at the repository root
- **THEN** it exits 0 and reports no change without a row and no row without a change

#### Scenario: Backlog ids are permanent

- **WHEN** `ROADMAP.md` is searched for backlog entries (`B-NNN`)
- **THEN** each id appears once, and an entry that became a change is replaced by a pointer to that change, never renumbered

### Requirement: State is derived, not stored

The state of a change SHALL be derived from the archive, the active changes and git, never written in `ROADMAP.md`.

#### Scenario: Archiving moves a change to done

- **WHEN** a change is archived with `openspec archive` and `mise run roadmap` runs again, with no edit to `ROADMAP.md`
- **THEN** the change is listed under Done with its archive date

#### Scenario: No status column

- **WHEN** the header of the sequencing table in `ROADMAP.md` is read
- **THEN** it has no status column

### Requirement: Read-only view of past, present and future

`mise run roadmap` SHALL print the changes grouped as Done, In progress, Next and Blocked, and SHALL NOT write any file.

#### Scenario: Groups

- **WHEN** `mise run roadmap` runs on the repository
- **THEN** every archived change is under Done with its date, every active change with ticked tasks or an open branch is under In progress with its task counts, and every other active change is under Next when all its dependencies are done and under Blocked, naming what it waits for, otherwise

#### Scenario: Nothing is written

- **WHEN** `git status --short` is compared before and after `mise run roadmap` and `mise run roadmap --check`
- **THEN** it is identical, and no file under `openspec/` or `ROADMAP.md` has a newer modification time

### Requirement: The check catches a broken roadmap

`mise run roadmap --check` SHALL exit non-zero and name the problem when the roadmap and the changes disagree.

#### Scenario: Change without a row

- **WHEN** a scratch copy of the repository has a new change directory with no row and `--check` runs
- **THEN** it exits 1 and names the change

#### Scenario: Unknown dependency

- **WHEN** a scratch copy has a row whose dependency names no change and `--check` runs
- **THEN** it exits 1 and names the row and the unknown dependency

#### Scenario: Dependency cycle

- **WHEN** a scratch copy has two rows that depend on each other and `--check` runs
- **THEN** it exits 1 and names the cycle

### Requirement: Roadmap files are not targets

`ROADMAP.md` and the task directory SHALL never be deployed to the home directory.

#### Scenario: Managed list excludes them

- **WHEN** `chezmoi managed | grep -cE '^(ROADMAP\.md|\.mise)'` runs
- **THEN** it prints 0

### Requirement: A fresh session finds the roadmap

`AGENTS.md` SHALL tell a session to run `mise run roadmap` first and to add a change's `ROADMAP.md` row in the same commit that creates the change.

#### Scenario: Read-first pointer

- **WHEN** `grep -c 'mise run roadmap' AGENTS.md` runs
- **THEN** it prints at least 1

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
