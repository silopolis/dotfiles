## Why

There is no single place that shows this repository's work as a whole: what is done, what is in progress, what comes next and why in that order.
`openspec list` shows only the active changes with task counts, `openspec view` is a dashboard of the current specs and changes, and the archive is a folder of dated directories with no index.
The order and the priorities live in one hand-kept table, the change map in section 6 of the audit (`docs/audits/2026-10-30-environment.md`), which is a dated baseline and not meant to be maintained; its rows 21 to 23 were added by other sessions without the rest of the document following.
The sibling repositories (cem, darse and others) each keep a roadmap and the Neovim configuration repository has a task that reports the state of its roadmap, so the practice and the tooling already exist in the fleet.
`TODO.md` is out of date and is to be retired (audit finding F34, change `refresh-repo-docs`).
Source: request of the user on 2026-11-03, audit finding F34 and section 6 of `docs/audits/2026-10-30-environment.md`.

## What Changes

- A root `ROADMAP.md`, kept by hand: one sequencing table with the order, the dependencies and the reason for the order of each change, plus a backlog of ideas that are not changes yet (permanent `B-NNN` ids, never reassigned, as in darse).
  It takes over the role of the audit's change map; section 6 of the audit becomes a frozen snapshot that points to `ROADMAP.md`.
- No stored status: a change is done when its directory is in `openspec/changes/archive/`, in progress when it has ticked tasks or an open branch or worktree, startable when everything it depends on is done, blocked otherwise.
  This is the rule the Neovim configuration repository uses; here the active changes and their task counts come from `openspec list --json`.
- A repo-local mise task `roadmap` (file `.mise/tasks/roadmap`, standard library only), adapted from the Neovim configuration repository's `roadmap` task and read-only: it prints Done (with the archive date), In progress (task counts, worktree or branch), Next, and Blocked (with what it waits for).
- `mise run roadmap --check` fails when a change directory (active or archived) has no row, a row names no change, a change appears twice, a dependency is unknown, or the dependencies form a cycle.
- Wiring:
  - `ROADMAP.md` is listed in the temporary repository-files block of `.chezmoiignore` (removed by `adopt-chezmoiroot` with the rest); `.mise/` needs no entry, chezmoi ignores names starting with a dot.
  - `AGENTS.md` tells a fresh session to run `mise run roadmap` first, and states the rule that a new change gets its `ROADMAP.md` row in the same commit.
  - Whether `--check` also runs as a commit hook step is left to the design (see `add-repo-quality-gates`).
- Seed `ROADMAP.md` from the audit's change map (rows 0 to 24) and from `openspec list`, check each dependency against the proposals, and record the order decisions already taken (for example that `enforce-hook-with-system-git` is suggested before `adopt-chezmoiroot`).
- `TODO.md` is not retired here: its open items are moved into `ROADMAP.md`'s backlog or into changes, and the file removal stays in `refresh-repo-docs`.

## Capabilities

### New Capabilities

- `repo-roadmap`: the repository's roadmap file and the read-only task that derives the state of every change from the archive and the active changes.

### Modified Capabilities

None.

## Impact

- New files: `ROADMAP.md`, `.mise/tasks/roadmap`, and tests for the task (a scratch tree with fake changes).
- `.chezmoiignore` (one line), `AGENTS.md` (read-first and same-commit rule), the audit's section 6 (a pointer and row 24).
- The task writes nothing; it only reads `openspec/`, `ROADMAP.md` and git.
- After `adopt-chezmoiroot` the paths move with the rest of the repository files; the change map in the audit must not be edited again once `ROADMAP.md` exists.
- Other sessions work in the same repository at the same time: a change added by another session without its row is reported by `--check`, which is the intended safety net.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
