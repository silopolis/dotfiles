# Brief: build the change add-repo-roadmap

Sent by the orchestrator agent `chezmoi-orch` (herdr workspace `chezmoi`) to the agent `chezmoi-roadmap`.
This file is an operational complement to the change, not a replacement: the proposal and the spec are the contract, this file says how to work.

## Where you work

- Repository: this one, in the worktree `~/Work/trees/chezmoi-add-repo-roadmap`, on branch `feat/add-repo-roadmap`, started from `main`.
- You are the only agent in this worktree.
  Another agent, `chezmoi-orch`, works in the main checkout and creates changes there; merge `main` into your branch before the final verification (see "Rules").
- You start in plan mode.
  Your first output is the design, shown in chat; the user reads it and switches you to build mode once approved.
  In plan mode the read-only guard asks for approval on every `mise run`; that is expected.

## Read first, in this order

1. `AGENTS.md` (safety rules, writing for a public repository, conventions).
2. `openspec/changes/add-repo-roadmap/` (proposal, specs for `openspec-repo-roadmap`, `global-mise-tasks` and `spec-workflow`) and `openspec list`.
3. Section 6 of `docs/audits/2026-10-30-environment.md` (the change map, rows 0 to 25: the seed for the roadmap fields) and finding F34.
4. `openspec/specs/global-mise-tasks/spec.md` and `dot_config/mise/tasks/` (how global tasks are written and tested here).
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
   - The layout of `ROADMAP.md`: what is hand-written, what is generated, the markers, and why the generated sections hold nothing that depends on the checkout.
   - The order rule for the sequencing table: dependency order first, then which tie-breaks (priority, phase, id), written down and deterministic.
   - How the generated state maps to what the Neovim repository's task prints.
     Give a feature-by-feature table of that task (view, `--check`, `--json`, worktrees and branches, GitHub, gates, `Touches` overlaps, live editor sync, metrics, herdr status) with one ruling each: core here, project hook, stays in the Neovim repository, or later.
     The aim is full parity; the table is where that is arbitrated, and the user decides on it.
   - The language rule for the tasks directory and the unit-test layout (`tests/global-mise-tasks/`), and whether ruff is added to the repository's `mise.toml`.
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
- `TODO.md` stays; its removal belongs to `refresh-repo-docs`.
- The change `add-agent-launch-tasks` (generic launch tasks, written by the orchestrator) depends on the language rule you write; do not touch its files.

## Rules

- Public repository: no secret values, no names of secret variables, no private hosts or IP addresses, no employer or client details, no private repository names.
  Name only darse, cem, bosco, greffe and the Neovim configuration repository; call any other "a fleet repository".
- Markdown: one sentence per line, no em or en dashes, no emoji, sentence-case headings, the vim modeline as the last line.
- Python: standard library only, tested, no home path or user name in any file.
- Commits: propose the message first (`type(domain:subject): imperative lowercase summary`, subject at most 80 characters), commit only after the user validates it, with `/home/linuxbrew/.linuxbrew/bin/git commit` so the hook output is visible.
  Never push.
- Merging back into `main` happens only on the user's go: merge `main` into your branch first, give every change created meanwhile its roadmap record, run `mise run openspec:roadmap --check`, then `mise run scm:worktree:done feat/add-repo-roadmap`.
- Anything that uses sudo, writes outside `$HOME`, uninstalls or deletes needs the user's explicit go.
- The seed is the audit's change map; once `ROADMAP.md` exists, do not edit that table again except to freeze it.

## Reporting

- Report to the orchestrator with one short line each time, using `herdr agent prompt chezmoi-orch "<one line>"`, at five points: reading done, design ready, apply done, verify result, blocked (say on what).
- Keep a list of every friction you meet with the tooling (a lost or duplicated prompt, a slow start, a permission prompt that blocked work, a path or trust problem in the worktree, a command that behaved differently from its help); send it with the last report.
  The orchestrator studies this launch as a trial of one worktree and one workspace per piece of work.
- At the end, draft the replacement signal for the Neovim configuration repository (what the global task covers, what stays there, how to switch); the user decides if it is sent.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
