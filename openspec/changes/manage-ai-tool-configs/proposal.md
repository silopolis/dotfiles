## Why

AI coding tools are now central to daily work (opencode, Claude Code, goose, shared agent skills), and their configuration (models, permissions, agents, commands, plugins) is unmanaged, mixed with sessions, credentials and caches in the same folders (audit finding F36).
cem's opencode domain handles histories and databases; this repository should hold the declarative part.

One of those tools already misleads agents: the rtk output filter (`~/.config/rtk/config.toml`, plus its opencode plugin `rtk.ts`) rewrites `git commit` into `rtk git commit` in every agent shell.
Observed on 2026-10-31 with the commit hook of `harden-sensitive-targets`: a commit that passes prints only `ok <short sha>`, so which hook steps ran and what they reported is invisible; a commit the hook refuses shows the full hook output.
An agent therefore cannot tell from a passing commit whether the hook ran at all.
Neither rtk file is under management today.

## What Changes

- Manage the declarative configuration only: opencode `opencode.json`, `tui.json`, personal agents and commands; Claude Code settings; goose config; shared skills under `~/.agents/skills` where they are not links to other repositories.
- Exclude credentials, sessions, databases, logs and caches explicitly (`.chezmoiignore`).
- Keep provider keys out of files: config files reference environment variables or a secret loader (see `fast-correct-shell-startup`).
- Decide how third-party bundles installed into these folders (plugins, command packs) are reproduced: externals, the tool's own installer, or a cem task.
- Manage the rtk configuration and its opencode plugin so that `git commit` (and `git push`, to be checked) is no longer rewritten and the hook output stays visible; the mechanism is rtk's `[hooks] exclude_commands` list, to be confirmed when the tasks are written.
  The file also holds machine state (telemetry consent and its date) which must stay out of the source: use a `modify_` script or a template that sets only the managed keys.
- Signal darse, whose template ships the hk hooks and whose fleet runs agents through rtk: a Lane A record `darse:T-065`, registered on 2026-10-31 from this change (`dispatch_origin` points at this directory), asks darse to record the visibility problem in its agent guidance and, as a second finding, the hook enforcement gap of `enforce-hook-with-system-git`.
  It sits on the darse branch `task/T-065-signal_rtk_hook_output` (commit `83e4cae`, validate green, not pushed) until darse merges it into its `dev`.
  The return signal is that record's `status` and `Resolution` in darse; read it back when this change is worked.

## Capabilities

### New Capabilities

- `ai-tool-configs`: which AI tool settings are declared and what is kept out.

### Modified Capabilities

None.

## Impact

- New targets under `~/.config/opencode`, `~/.claude` or `~/.config/claude`, `~/.config/goose`, `~/.agents`, `~/.config/rtk`.
- Behaviour change for agent shells: `git commit` runs unwrapped, so its hook output is printed in full (more tokens per commit, by design).
- cem checklist 5.5 (AI login files) is about credentials and stays out of scope.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
