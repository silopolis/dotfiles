## Why

There is no single place that shows this repository's work as a whole: what is done, what is in progress, what comes next and why in that order.
`openspec list` shows only the active changes with task counts, `openspec view` is a dashboard of the current specs and changes, and the archive is a folder of dated directories with no index.
The order and the priorities live in two hand-kept lists: the change map in section 6 of the audit (`docs/audits/2026-10-30-environment.md`), a dated baseline that stops at row 25, and the planned order in `TODO.md` (written 2026-11-07), which departs from the map on purpose and holds *planned* entries for changes that do not exist yet.
Changes created since the map was written (the Incus and test-infrastructure group, `remove-brew-libvirt`, the Kali VM stubs) appear only in `TODO.md`.
The fleet's roadmaps keep one record per item with its dependencies and status in the front matter, and the roadmap file is a projection of those records that tools write or check; the Neovim configuration repository's roadmap is hand-written and a task derives the state from git.
Here the records already exist: each OpenSpec change is one, but it carries no order, no dependency and no priority.
`TODO.md` keeps the same kind of list a second time, next to older bullets and a packaging backlog, and audit finding F34 asks to retire it.
Source: requests of the user on 2026-11-03 and 2026-11-04, audit finding F34, section 6 of the audit and the planned order in `TODO.md`.

## What Changes

- **Transitional.**
  This is a stand-in for the fleet's records system (bosco and greffe), which is not available yet and has no date.
  The vocabulary follows the fleet's, so that a later migration is mechanical: permanent `B-NNN` backlog ids, dependencies named by change id, status derived and never typed by hand.
  When the fleet's system is available, this change is superseded and `ROADMAP.md` is generated from its records instead.
- **Roadmap fields per change.**
  Every change, active or archived, carries a small record: dependencies, phase, priority, size, the finding or request it answers, one line on why it sits where it does.
  The design decides where the record lives (a file in the change folder, or extra keys in `.openspec.yaml`); OpenSpec ignores both and archiving moves the folder as a whole.
  A change that is planned but has no folder yet (the *planned* lines of `TODO.md`) is listed by id in the hand-kept part of `ROADMAP.md` with its dependencies, and `--check` accepts it until a folder with that id exists.
- **`ROADMAP.md` is mostly generated.**
  A root `ROADMAP.md` holds hand-written text (purpose, phase descriptions, backlog, decisions) and sections between markers that the task writes: the sequencing table in dependency order and the done list with archive dates.
  What is generated is only what is stable in a commit; the live state (in progress, task counts, startable, blocked) is never committed, because it depends on the checkout.
- **A global mise task `openspec:roadmap`, usable by any OpenSpec repository.**
  Python with the standard library only, deployed with the other global tasks, replacing the repo-local `roadmap` task of the Neovim configuration repository (its replacement is signalled at the end of this work, with a feature-by-feature parity table in the design).
  - `mise run openspec:roadmap` prints Done, In progress, Next and Blocked from the records, the archive, `openspec list --json` and git; it writes nothing.
  - `--write` regenerates the marked sections of `ROADMAP.md`.
  - `--check` fails when a marked section is out of date, a change has no roadmap fields, a row names no change, a dependency is unknown, or the dependencies form a cycle.
  - `--json` prints the same state for other tools.
- **Global task rule.**
  The `global-mise-tasks` requirement that every file under the tasks directory passes `shellcheck -x` becomes: shell files pass `shellcheck -x`, Python files compile and have unit tests.
  The change `add-agent-launch-tasks` depends on this amendment.
- **Adoption in this repository.**
  - Seed the roadmap fields from the planned order in `TODO.md` (its order, its *planned* lines, its packaging backlog and its older bullets as backlog items) and from the audit's change map (the finding or request each change answers); the generated table must list the changes in the order `TODO.md` gives.
    Then freeze the audit's section 6 with a pointer to `ROADMAP.md`, and remove `TODO.md`.
  - `ROADMAP.md` needs no ignore entry: since `adopt-chezmoiroot` the root files are outside the source state (spec `source-layout`); the task source is under `home/dot_config/mise/tasks/`.
  - `AGENTS.md` tells a fresh session to run `mise run openspec:roadmap` first, and states that a new change gets its roadmap fields in the same commit and that `--write` follows `openspec archive`.
  - Whether `--check` also runs as a commit hook step is left to the design (see `add-repo-quality-gates`).
- **Non-goals.**
  - Multi-agent orchestration (dispatch, lanes, one agent per change) is studied at fleet level and is not designed here; the roadmap fields only need to be able to carry what such a design later asks for.
  - The README and docs work stay in `refresh-repo-docs`; its bullet that retired `TODO.md` is removed, because this change retires it.

## Capabilities

### New Capabilities

- `openspec-repo-roadmap`: the roadmap fields of a change, the generated `ROADMAP.md`, and the read-only task that derives the state of every change from the records, the archive and git.

### Modified Capabilities

- `global-mise-tasks`: the `openspec:roadmap` task is deployed and listed; Python tasks are allowed, with their own checks.
- `spec-workflow`: this repository keeps a `ROADMAP.md`, tells sessions to read it first, and records each change's roadmap fields when the change is created.

## Impact

- New files: the task `home/dot_config/mise/tasks/openspec/executable_roadmap`, its library under `home/dot_config/mise/lib/`, unit tests in `tests/global-mise-tasks/` (outside the source state), `ROADMAP.md`, and a roadmap record in every existing change folder.
- Removed: `TODO.md`, once its content is in `ROADMAP.md`.
- Edited: the audit's section 6 (frozen, with a pointer), `AGENTS.md`, the proposal of `refresh-repo-docs` (its `TODO.md` bullet), and `openspec/specs/global-mise-tasks` and `openspec/specs/spec-workflow` through the deltas.
- Archive order: this change modifies the requirements "Global tasks are deployed and listed" and "Tasks are generic and clean" of `global-mise-tasks`; no other open change modifies them (`add-incus-host-setup` adds a requirement of its own and `add-agent-launch-tasks` modifies "Dispatching an agent"), so the order is free, but `openspec validate --all --strict` runs after each archive.
- Only the marked sections of `ROADMAP.md` are ever written, and only with `--write`; the viewer, `--check` and `--json` write nothing.
- The task is deployed as a single target with `chezmoi apply --exclude=scripts ~/.config/mise/tasks/openspec`, after the user's go.
- Other sessions work in the same repository at the same time: a change added by another session without its fields is reported by `--check`, which is the intended safety net.
- The Neovim configuration repository can drop its `roadmap` task and read the global task's `--json`; that is a signal at the end of this work, not part of it.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
