## Why

After a year away from this machine, the repository had no record of its own state and no way to plan work across sessions: a stub README, an outdated TODO, and only one agent guide (for tmux).
The consolidation that follows (about eighteen changes) has to be done in fresh sessions, one at a time, without losing context.

## What Changes

- Add the baseline audit `docs/audits/2026-10-30-environment.md`, written for a public repository, with numbered findings (`F01` to `F41`), decisions and a change map.
- Initialize OpenSpec for opencode (`openspec/`, `.opencode/command/opsx-*.md`, `.opencode/skills/openspec-*`), as in the Neovim repository.
- Fill `openspec/config.yaml` with repository context and per-artifact rules (public writing, verification commands, dry run before apply, commit validation).
- Add a root `AGENTS.md`: where things live, commands, safety rules, public-writing rules, conventions, workflow.
- Keep repository files out of the target state: temporary `.chezmoiignore` entries for `AGENTS.md`, `docs` and `openspec` (removed by `adopt-chezmoiroot`); ignore opencode's plugin SDK files in `.gitignore`.
- Scaffold the consolidation changes listed in the audit's change map.

## Capabilities

### New Capabilities

- `spec-workflow`: how work on this repository is planned, recorded and checked (audit baseline, OpenSpec changes, agent guide, public-writing rule).

### Modified Capabilities

None.

## Impact

- New repository files only: `AGENTS.md`, `docs/`, `openspec/`, `.opencode/`.
- `.chezmoiignore` and `.gitignore` gain entries; `chezmoi managed` and `chezmoi status` are unchanged.
- No target, script or package changes.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
