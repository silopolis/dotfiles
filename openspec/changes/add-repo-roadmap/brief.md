# Brief: build the change add-repo-roadmap

Written by the orchestrator agent of this repository, for the agent that builds this change (suggested name `chezmoi-roadmap`).
This file is an operational complement to the change, not a replacement: the proposal and the specs are the contract, this file says how to work.

## Where you work

- Repository: this one, in a worktree `~/Work/trees/chezmoi-add-repo-roadmap`, on branch `feat/add-repo-roadmap`, started from `main`.
  The orchestrator creates the worktree and its herdr workspace; if you find yourself in the main checkout, stop and say so.
- You are the only agent in that worktree.
  Other agents work in the main checkout and create changes there; merge `main` into your branch before the final verification (see "Rules").
- You start in plan mode.
  Your first output is the design, shown in chat; the user reads it and switches you to build mode once approved.
  In plan mode the read-only guard asks for approval on every `mise run`; that is expected.
- Everything chezmoi reads lives under `home/` since the change `adopt-chezmoiroot` (spec `source-layout`); the changes written before it use flat paths, prefix them with `home/`.

## Read first, in this order

1. `AGENTS.md` (safety rules, writing for a public repository, conventions).
2. `openspec/changes/add-repo-roadmap/` (proposal, specs for `openspec-repo-roadmap`, `global-mise-tasks` and `spec-workflow`) and `openspec list`.
3. The seed of the order: the "Planned order of changes" in `TODO.md` (written 2026-11-07, 25 lines, some *planned* with no change yet, plus the mise packaging backlog and older bullets).
   Then section 6 of `docs/audits/2026-10-30-environment.md` (the change map, rows 0 to 26: the finding or request each change answers) and finding F34.
4. `openspec/specs/global-mise-tasks/spec.md`, `openspec/specs/source-layout/spec.md` and `home/dot_config/mise/tasks/` (how global tasks are written and tested here), and the archived `adopt-chezmoiroot`.
5. Format references, read-only, copying nothing private:
   - The Neovim configuration repository: `~/.config/nvim/ROADMAP.md` (sessions table, one section per session), `~/.config/nvim/.mise/tasks/roadmap`, `~/.config/nvim/.mise/lib/workflow/roadmap.py` and `~/.config/nvim/tests/workflow/test_roadmap.py`.
     Its task is the one the global task is meant to replace.
   - darse: `~/Work/darse/spec/drs/DR-021-piloting_and_index_formats.md`, `~/Work/darse/project/roadmap.md`, `~/Work/darse/scripts/check/index.py`.
   - cem: `~/Work/cles-en-main/project/roadmap.md`.
   - The fleet piloting repository: its roadmap, its piloting contract (ordering rule, projection layouts, status values) and its orchestration study.
     The first prompt gives you the exact paths; they are not written here because that repository is not public.
     Do not name it, its identifiers or its paths in any committed file; refer to it as "the fleet piloting repository".
6. After reading, summarise in a few lines what each reference does that is useful here and what is not.

## What to do

1. `/opsx-continue add-repo-roadmap`: write `design.md`, then show it in chat before anything else.
   It must settle, with the reason for each choice:
   - Where the roadmap record of a change lives: a file in the change folder or extra keys in `.openspec.yaml`.
     OpenSpec 1.2.0 reads that file with a schema that ignores unknown keys, and archiving moves the folder as a whole; check both facts again on the installed version, and check that `openspec validate --all --strict` accepts the choice.
   - The record's fields, their names and allowed values, aligned with the fleet's vocabulary (dependencies, priority, phase, size, origin, reason), and how a record is created with a change (a template, or the task creating it).
   - How a *planned* change (no folder yet) is written, and what the hand-kept part of `ROADMAP.md` holds.
   - How the fields reproduce the order of `TODO.md`: it is a hand order that is not derivable from dependencies alone (the user's chosen order, then the Incus group before the supervised apply).
     The generated table must list the seeded changes in that order (spec `spec-workflow`, scenario "Seed keeps the planned order"); say which field carries it.
   - What happens to the rest of `TODO.md` (the mise packaging backlog, the older bullets, the "Later" line): backlog items with permanent `B-NNN` ids, or changes.
     `TODO.md` is removed by this change, and the bullet of `refresh-repo-docs` that retired it is already dropped.
   - The layout of `ROADMAP.md`: what is hand-written, what is generated, the markers, and why the generated sections hold nothing that depends on the checkout.
   - The order rule for the sequencing table: dependency order first, then which tie-breaks (priority, phase, id), written down and deterministic.
   - How the generated state maps to what the Neovim repository's task prints.
     Give a feature-by-feature table of that task (view, `--check`, `--json`, worktrees and branches, GitHub, gates, `Touches` overlaps, live editor sync, metrics, herdr status) with one ruling each: core here, project hook, stays in the Neovim repository, or later.
     The aim is full parity; the table is where that is arbitrated, and the user decides on it.
   - The language rule for the tasks directory and the unit-test layout (`tests/global-mise-tasks/`, outside the source state, so no ignore entry), and whether ruff is added to the repository's `mise.toml`.
   - Whether `--check` becomes a commit hook step now or in `add-repo-quality-gates`.
   - A short, generic paragraph on how the record's fields would map to a future records system (bosco and greffe), without designing it.
2. After the user approves the design: `/opsx-continue` for the tasks, then `/opsx-apply`, then `/opsx-verify`.
3. Archive (`/opsx-archive`) only on the user's go, after `mise run openspec:roadmap --write` has been run on the final tree.
4. Deploying the task to `~/.config/mise/tasks/openspec` is a single-target apply (`chezmoi apply --exclude=scripts ~/.config/mise/tasks/openspec`) and needs the user's go.
   Never run a full `chezmoi apply`.

## Non-goals

- Multi-agent orchestration (dispatch, lanes, one agent per change) is not designed here; the fleet studies it.
  Only make sure the record can later carry what such a design asks for.
- No bosco or greffe design, and no edit to other repositories: the Neovim repository gets a signal at the end, drafted by you and sent by the user's go through the orchestrator.
- The README and docs work stay in `refresh-repo-docs`.
- The change `add-agent-launch-tasks` (generic launch tasks, written by the orchestrator) depends on the language rule you write; do not touch its files.

## Rules

- Public repository: no secret values, no names of secret variables, no private hosts or IP addresses, no employer or client details, no private repository names.
  Name only darse, cem, bosco, greffe and the Neovim configuration repository; call any other "a fleet repository".
- Markdown: one sentence per line, no em or en dashes, no emoji, sentence-case headings, the vim modeline as the last line.
- Python: standard library only, tested, no home path or user name in any file.
- Commits: propose the message first (`type(domain:subject): imperative lowercase summary`, subject at most 80 characters), commit only after the user validates it, with `/home/linuxbrew/.linuxbrew/bin/git commit` so the hook output is visible.
  Never push.
- Merging back into `main` happens only on the user's go: merge `main` into your branch first, give every change created meanwhile its roadmap record and every new line of `TODO.md` its place, run `mise run openspec:roadmap --check`, then `mise run scm:worktree:done feat/add-repo-roadmap`.
- Anything that uses sudo, writes outside `$HOME`, uninstalls or deletes needs the user's explicit go; removing `TODO.md` is part of the approved change, but do it in its own commit.
- The seed is `TODO.md` and the audit's change map; once `ROADMAP.md` exists, do not edit that table again except to freeze it.

## Reporting

- Report with one short line each time, at five points: reading done, design ready, apply done, verify result, blocked (say on what).
  Send it with `herdr agent prompt chezmoi-orch "<one line>"` when `herdr agent get chezmoi-orch` succeeds; agent names do not always survive (see `openspec/changes/add-agent-launch-tasks/observations.md`), so when it fails, write the line in your own pane for the user.
- Keep a list of every friction you meet with the tooling (a lost or duplicated prompt, a slow start, a permission prompt that blocked work, a path or trust problem in the worktree, a command that behaved differently from its help); send it with the last report.
  The orchestrator studies this launch as a trial of one worktree and one workspace per piece of work.
- At the end, draft the replacement signal for the Neovim configuration repository (what the global task covers, what stays there, how to switch); the user decides if it is sent.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
