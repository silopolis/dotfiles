## Why

AI coding tools are now central to daily work (opencode, Claude Code, goose, shared agent skills), and their configuration (models, permissions, agents, commands, plugins) is unmanaged, mixed with sessions, credentials and caches in the same folders (audit finding F36).
cem's opencode domain handles histories and databases; this repository should hold the declarative part.

## What Changes

- Manage the declarative configuration only: opencode `opencode.json`, `tui.json`, personal agents and commands; Claude Code settings; goose config; shared skills under `~/.agents/skills` where they are not links to other repositories.
- Exclude credentials, sessions, databases, logs and caches explicitly (`.chezmoiignore`).
- Keep provider keys out of files: config files reference environment variables or a secret loader (see `fast-correct-shell-startup`).
- Decide how third-party bundles installed into these folders (plugins, command packs) are reproduced: externals, the tool's own installer, or a cem task.

## Capabilities

### New Capabilities

- `ai-tool-configs`: which AI tool settings are declared and what is kept out.

### Modified Capabilities

None.

## Impact

- New targets under `~/.config/opencode`, `~/.claude` or `~/.config/claude`, `~/.config/goose`, `~/.agents`.
- cem checklist 5.5 (AI login files) is about credentials and stays out of scope.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
