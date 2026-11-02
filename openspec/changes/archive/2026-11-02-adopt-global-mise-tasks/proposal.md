## Why

Git worktrees are the unit of parallel agent work on this machine, yet no global tool creates, lists or cleans them, and each repository either scripts its own or does it by hand.
The Neovim repository's session S2 (change `setup-session-workflow`) wrote generic global mise tasks for that, tested them, and left them untracked in this working tree with a request to adopt them through this repository's process.
chezmoi already deploys them (the working tree is the source state), so until they are committed they are managed but untracked, and the rename-only check of `adopt-chezmoiroot` (task 2.1) would fail on them.
Review found two cleanup defects worth fixing before they become habits: `scm:worktree:done --all-merged` removes a fresh worktree whose branch has no commits yet (and closes its herdr tab), and `done` refuses a branch whose pull request was squash-merged.
Source: request of 2026-11-02; the mise config is a managed application config (audit `docs/audits/2026-10-30-environment.md`, section 2.7); new row in the change map (section 6).

## What Changes

- Adopt, as received, the shared helper `dot_config/mise/lib/scm.sh` and five global file tasks under `dot_config/mise/tasks/`: `scm:worktree:new`, `rm`, `done`, `ls` (aliases `scm:wt:*`) and `agent:dispatch`.
- `scm:worktree:new` records the commit a branch starts from, so later steps know whether the branch has commits of its own.
- `scm:worktree:done` cleans only branches that have commits of their own; `--all-merged` skips the others and says why, and `done <target>` on such a branch points to `scm:worktree:rm`.
- A branch counts as merged when its tip is in `origin/main`, or when GitHub reports a merged pull request from that branch into `main` whose head commit is the local tip (squash and rebase merges); `rm` and `done` share that test.
- `port-omalap-shell-aliases` gets a note: its planned git worktree functions become thin wrappers over these tasks, or are skipped.
- Nothing else in `~/.config/mise` changes; no global mise var is defined.

## Capabilities

### New Capabilities

- `global-mise-tasks`: the global mise tasks this repository deploys (`scm:worktree:*`, `agent:dispatch`), their safety rules, project hooks, settings and dependencies.

### Modified Capabilities

None.

## Impact

- New source files `dot_config/mise/lib/scm.sh` and `dot_config/mise/tasks/{scm/worktree/executable_{new,rm,done,ls},agent/executable_dispatch}` (under `home/` after `adopt-chezmoiroot`; they hold no source-path literal).
- Targets `~/.config/mise/lib/scm.sh` and `~/.config/mise/tasks/`, applied alone with `--exclude=scripts`.
- Dependencies: `usage` and `herdr` (already in the global mise config), `git`, `jq` (from apt, undeclared: left to `rationalize-package-ownership`), and optionally `gh`.
- Overlap: `port-omalap-shell-aliases` (worktree functions, cem checklist 4.1).
- The sender, the Neovim repository, reads the change id back from the herdr agent `chezmoi-wtasks` and records it in its roadmap.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
