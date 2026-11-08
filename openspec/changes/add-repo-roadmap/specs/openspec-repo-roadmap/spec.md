## ADDED Requirements

Unless stated otherwise, scenarios run in a scratch OpenSpec repository under `/tmp/opencode` (a git repository with `openspec/changes/` holding a few changes, one archived, and a `ROADMAP.md` with markers), with no chezmoi and no herdr involved.

### Requirement: Every change carries roadmap fields

Every OpenSpec change, active or archived, SHALL carry a roadmap record with its dependencies (change ids), phase, priority, size, the finding or request it answers, and one line on why it sits where it does; the record SHALL survive archiving and SHALL NOT make `openspec validate --all --strict` fail.

#### Scenario: Change without a record

- **WHEN** the scratch repository gets a new change directory with no roadmap record and `mise run openspec:roadmap --check` runs
- **THEN** it exits 1 and names the change

#### Scenario: Record survives archiving

- **WHEN** `openspec archive <id> --yes` archives a change that has a record, and then `openspec validate --all --strict` and `mise run openspec:roadmap --check` run
- **THEN** the record is in the archived directory, validation passes, and the check reports no missing record

### Requirement: State is derived, never stored

The state of a change SHALL be derived from the archive, the active changes, their task counts and git (worktrees and branches), never written in a record or in `ROADMAP.md`.

#### Scenario: Groups

- **WHEN** `mise run openspec:roadmap` runs on the scratch repository
- **THEN** every archived change is under Done with its archive date, every active change with ticked tasks or an open worktree or branch is under In progress with its task counts, and every other active change is under Next when all its dependencies are done and under Blocked, naming what it waits for, otherwise

#### Scenario: Archiving moves a change to done

- **WHEN** a change is archived and `mise run openspec:roadmap` runs again, with no edit to any record
- **THEN** the change is listed under Done with the date of its archive directory

### Requirement: Reading writes nothing

`mise run openspec:roadmap` and `mise run openspec:roadmap --check` SHALL NOT write any file, and `--json` SHALL print the same state as one JSON object for other tools.

#### Scenario: No writes

- **WHEN** `git status --short` and the modification times of `ROADMAP.md` and every file under `openspec/` are compared before and after `mise run openspec:roadmap` and `mise run openspec:roadmap --check`
- **THEN** they are identical

#### Scenario: JSON state

- **WHEN** `mise run openspec:roadmap --json | jq -e '.changes | length'` runs
- **THEN** it prints the number of active plus archived changes, and each entry has its id, state, dependencies, phase, priority and size

### Requirement: Generated sections of ROADMAP.md

`ROADMAP.md` SHALL hold hand-written text and sections between `<!-- roadmap:begin NAME -->` and `<!-- roadmap:end NAME -->` markers that only `mise run openspec:roadmap --write` rewrites, with the sequencing table in dependency order and the done list with archive dates; no generated section SHALL hold a task count or the state of a checkout.

#### Scenario: Write is bounded and repeatable

- **WHEN** `mise run openspec:roadmap --write` runs twice in the scratch repository
- **THEN** the text outside the markers is byte-identical to before, the second run changes nothing, and `--check` then exits 0

#### Scenario: Archiving makes the file stale

- **WHEN** a change is archived and `mise run openspec:roadmap --check` runs before `--write`
- **THEN** it exits 1 and names the stale section, and after `--write` it exits 0

#### Scenario: No volatile state in the file

- **WHEN** `awk '/roadmap:begin/,/roadmap:end/' ROADMAP.md | grep -c -E '[0-9]+/[0-9]+'` runs on a scratch repository with a change at 2 of 5 tasks
- **THEN** it prints 0

### Requirement: The check catches a broken roadmap

`mise run openspec:roadmap --check` SHALL exit non-zero and name the problem when the roadmap, the records and the changes disagree.

#### Scenario: Unknown dependency

- **WHEN** a record names a dependency that is no change and `--check` runs
- **THEN** it exits 1 and names the change and the unknown dependency

#### Scenario: Dependency cycle

- **WHEN** two records depend on each other and `--check` runs
- **THEN** it exits 1 and names the cycle

#### Scenario: Backlog ids

- **WHEN** `ROADMAP.md` holds two backlog entries with the same `B-NNN` id, or an id that is not `B-` and three digits
- **THEN** `--check` exits 1 and names the entry

### Requirement: Planned changes are listed

`ROADMAP.md` SHALL be able to list a change that has no folder yet as planned, in its hand-kept part, with its dependencies and its place in the order; the task SHALL show it with the state `planned`, and `--check` SHALL accept it until a change with that id exists.

#### Scenario: Planned entry

- **WHEN** the scratch `ROADMAP.md` lists a planned id that depends on an existing change and no folder has that id, and `mise run openspec:roadmap` and `mise run openspec:roadmap --check` run
- **THEN** the plain run shows the id with the state `planned` after its dependency, and the check exits 0

#### Scenario: Planned entry that became a change

- **WHEN** a change folder is created with the id of a planned entry and `--check` runs
- **THEN** it exits 1 and names the id, until the planned entry is removed

### Requirement: Usable by any OpenSpec repository

The task SHALL depend on nothing of this repository except `openspec`, `git` and Python 3 with its standard library, and SHALL hold no path, user name or repository name of this repository.

#### Scenario: Runs in a foreign repository

- **WHEN** the scratch repository has no chezmoi source and no mise project configuration, and `mise run openspec:roadmap --check` runs from it
- **THEN** it exits 0 on a consistent roadmap and prints the groups on a plain run

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
