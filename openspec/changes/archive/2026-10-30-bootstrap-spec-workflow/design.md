## Context

The repository is the chezmoi source state of the user's workstations and is public on GitHub.
Its companion project cem is private today but will be published, so nothing in either may depend on being private.
The Neovim configuration already uses OpenSpec with opencode, and the user wants the same method here.

## Goals / Non-Goals

**Goals:**

- One baseline document that any fresh session can read to understand the repository and its problems.
- One OpenSpec change per unit of work, each pointing to the findings it addresses.
- Agent rules that make unsafe operations (full apply, sudo, deletions, secret handling, commits) explicit.

**Non-Goals:**

- Fixing any finding (each has its own change).
- Moving the source state into `home/` (change `adopt-chezmoiroot`).
- Choosing other spec tooling (spec-kit, Superpowers, ECC): not needed now.

## Decisions

### Audit inside this repository, not in cem

The audit lives in `docs/audits/` here, next to the changes that use it, so a session needs only this repository.
cem keeps pointers (migration checklist, tasks `T-005` and `T-012`).
Alternative considered: a report in cem's `migrations/.../reports/`; rejected once both repositories were to be treated as public, since the only reason was privacy.

### Findings are numbered and cited

Changes cite `Fnn` identifiers instead of copying text, so the audit stays the single source and changes stay short.
Line numbers are given against commit `191ee9e`; sessions re-check them before editing.

### Temporary ignore entries

Until `adopt-chezmoiroot`, chezmoi treats every non-dot file at the root as a target, so `AGENTS.md`, `docs` and `openspec` are listed in `.chezmoiignore`.
`.opencode/` starts with a dot and is ignored by chezmoi already; opencode's plugin SDK files there are ignored by git.

### Detail level of scaffolded changes

The near-term changes get proposal, design, specs and tasks.
Later changes get proposal and specs (plus a short design and draft tasks for the medium-term ones), refined at the start of their own session, because their facts will have moved by then.

## Risks / Trade-offs

- [Risk] The audit goes stale as changes land. → Each change records what it fixed; the audit is dated and not edited after the fact, except for broken references.
- [Risk] Public text leaks a private detail. → Rule in `AGENTS.md` and `openspec/config.yaml`; a pattern check before each commit (task 4.2); secret scanning arrives with `harden-sensitive-targets`.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
