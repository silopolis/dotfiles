## Why

The README is a stub, `TODO.md` lists items that are done or obsolete, and the tmux `AGENTS.md` is deployed into `~/.config/tmux` and no longer matches the config it describes (audit finding F34).
Once the consolidation changes have landed, a reader (the user on a new machine, an agent, or a visitor of the public repository) should understand what this repository is and how to use it from the README alone.

## What Changes

- Rewrite `README.md`: purpose, relation to cem, bootstrap command, layout, how changes are made (OpenSpec, `AGENTS.md`), license.
- Retire `TODO.md`: open items become OpenSpec changes or cem backlog entries, then the file is removed.
- Move the tmux agent guide out of the target state (into `docs/` or merged into `AGENTS.md`) and align it with `tmux.conf`; same check for any other deployed README.
- Add a short `docs/` index (audits, how-to for bootstrap and supervised apply).

## Capabilities

### New Capabilities

- `repo-docs`: what the repository documents and where.

### Modified Capabilities

None.

## Impact

- Documentation only; deployed `README.md` and `AGENTS.md` copies under `~/.config` removed (with the user's go).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
