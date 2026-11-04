# Observations: launching an agent by hand into its own worktree and workspace

Input for the design of `add-agent-launch-tasks`, and for a signal to the fleet's study of multi-agent orchestration.
The first launch is done by hand, on 2026-11-04, for the agent that builds `add-repo-roadmap`: one worktree, one herdr workspace built out of it, one agent in plan mode, one first prompt.
Each step below is logged with its command, its result and any friction, so that the tasks automate what really happened and not what was expected.

## Known before the launch

- herdr 0.9.5 has `herdr worktree list|create|open|remove`; `list` gives, for each worktree of a repository, its branch, its path and the workspace open on it.
- No global task creates a workspace; `agent:dispatch` and `scm:worktree:new --tab` need one that exists.
- The Neovim configuration repository runs its sessions as tabs of one workspace and does not use `herdr worktree create`, because it opens a whole workspace.
- The first prompt is lost when sent while the opencode TUI is still blank (about 10 s after `agent start` returns), and a prompt ending in `@file` opens the autocomplete, which takes the Enter.
- The read-only guard asks for approval on every `mise run` in plan mode.

## Questions this launch answers

- Does `herdr worktree open --path <worktree>` create a usable workspace for a worktree that `scm:worktree:new` made, and what label and focus does it give?
- Does the new session start with the project's tracked `.opencode/` commands and skills, and does its dependency directory (not tracked) get installed by itself?
- Is the worktree trusted by mise from its first command, and does the commit hook run there?
- How long does the TUI take to draw in a fresh worktree, and does the first prompt arrive once?
- What does the agent need from the orchestrator that a brief cannot carry?

## Log

<!-- Entries: time, step, command, result, friction. -->

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
