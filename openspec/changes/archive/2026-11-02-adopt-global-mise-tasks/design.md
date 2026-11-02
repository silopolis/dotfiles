## Context

- The six files were written in the Neovim repository's session S2 and placed untracked in `dot_config/mise/`, then applied with `chezmoi apply --exclude=scripts ~/.config/mise/lib ~/.config/mise/tasks`; on 2026-11-02 `chezmoi diff` on those targets is empty and `mise tasks ls --global` lists the five tasks.
- mise reads global file tasks from `~/.config/mise/tasks/`; a directory gives the task its group (`tasks/scm/worktree/new` is `scm:worktree:new`); `lib/` is not a task directory, so the helper is not listed.
- chezmoi's `executable_` prefix gives the tasks their mode; `scm:worktree:done` finds its sibling `rm` by its target name, or by its source name when run from the source directory.
- mise does not export `MISE_CONFIG_DIR` to tasks, so the helper is sourced from `$HOME/.config/mise/lib/scm.sh`, which is `XDG_CONFIG_HOME/mise` on this machine.
- Review on 2026-11-02, in a scratch repository with a bare origin under `/tmp/opencode`:
  - shellcheck 0.11.0 `-x` and `bash -n` are clean; no home path, user name, host or credential in the files;
  - `done --all-merged` removed a worktree created a moment before with no commit: a branch without commits is an ancestor of `origin/main`, so it looks merged;
  - `done <target>` refused a branch whose content reached `main` through a squash merge, since its tip is not an ancestor of `origin/main`.
- On 2026-11-02 every repository under `~/Work` has `origin/HEAD` pointing to `main`.
- The Neovim repository keeps its own project hooks (`scm:worktree:hook:*`); they are not part of this repository.

## Goals / Non-Goals

**Goals:**

- The tasks are tracked here, deployed by chezmoi, and stay generic (no repository-specific behaviour, nothing machine-specific).
- Cleanup removes only worktrees whose work has landed, including squash and rebase merges, and never a fresh one.
- The files are committed before `adopt-chezmoiroot`, so its rename-only check holds.

**Non-Goals:**

- Detecting the default branch: `origin/main` stays fixed, as every current repository uses it.
- An `XDG_CONFIG_HOME` fallback for the helper path (same directory on this machine).
- Declaring `jq` through mise (it comes from apt; package ownership is `rationalize-package-ownership`).
- A global default for the mise var `scm_worktrees_prefix` (it can go in `~/.config/mise/conf.d/` later).
- Shell functions for worktrees (`port-omalap-shell-aliases`, which gets a note to wrap these tasks or skip).

## Decisions

### Adopt as received, then fix in a separate commit

The six files are committed exactly as the sender left them, then the fixes come as a second commit.
The diff of the fix stays reviewable on its own, and the sender can compare its copy with the first commit.
Alternative considered: one commit with the fixed files; rejected because it hides what the review changed.

### Record the start commit of each branch

`scm:worktree:new` writes the commit the branch starts from to `scm-base` in the worktree's git admin directory, next to the `herdr-tab` file it already writes there; `git worktree remove` deletes both.
A branch has commits of its own when `git rev-list --count <base>..<branch>` is above 0.
Without that file (a worktree made by another tool or by hand), the oldest reflog entry of the branch is used when its message starts with `branch: Created from`; otherwise the answer is unknown.
Alternative considered: the reflog alone; rejected as the only source because reflog entries expire (90 days by default) while worktrees can live longer.
Alternative considered: comparing the branch tip with `origin/main`; rejected because a fast-forward merge and a fresh branch look the same in the graph.

### What cleanup does with each answer

- `done --all-merged`: no commits of its own, or unknown, means skip, with the reason printed; skipping is the safe direction.
- `done <target>`: no commits of its own means refuse and point to `scm:worktree:rm`, since there is nothing to clean as merged; unknown means the target named by the user goes on to the merge check.
- `rm` does not look at it: removing a clean fresh worktree on purpose is what `rm` is for.

### One merge test, shared by rm and done

A helper in `scm.sh` answers whether a branch is merged:

1. its tip is an ancestor of `origin/main`;
2. else `gh pr list --head <branch> --base main --state merged --json number,headRefOid` (run in the main checkout, with a timeout) returns a pull request whose `headRefOid` is the local tip.

The head commit must match, so commits added locally after the merge keep the branch unmerged, and a pull request from a fork that reuses the branch name does not count.
`rm` keeps its extra local test (an ancestor of the main checkout's `HEAD`).
When `gh` is missing or fails (offline, not logged in), only the git test applies, and the refusal says the pull request lookup was not available.
Alternative considered: `done` passing `--force` to `rm` after its own test; rejected because `--force` also discards dirty worktrees.
Alternative considered: a single `gh pr list` of every merged pull request per repository; rejected because a list limit can miss old ones, while one query per branch is exact and cleanup handles a handful of branches.

## Risks / Trade-offs

- [Risk] `rm` and `done` delete worktree directories and local branches. → Unchanged guards: a dirty worktree or an unmerged branch is refused without `--force`; the remote branch is never touched; the new rules only make `done` stricter (own commits) or accept a merge that GitHub records for the exact local tip.
- [Risk] A merged pull request is later reverted on `main`; the branch still counts as merged. → The worktree is clean and its head commit stays in the pull request on GitHub; only the local branch and the worktree go.
- [Risk] `gh` answers slowly or hangs. → The same 15 s timeout as `scm:worktree:ls`; a timeout counts as no answer.
- [Risk] The fixes diverge from the sender's copy. → From this change on, this repository owns the tasks; the reply to the sender names the change, and its two commits show what changed.
- [Risk] `mise trust` and `mise trust --untrust` write to `~/.local/state/mise`. → Inside `$HOME`; untrust runs before the directory goes, so no stale entry remains (checked in the scratch run).
- [Trade-off] The checks in scratch repositories use a fake `gh` on `PATH`, so the GitHub path is tested against the documented JSON shape, not against GitHub itself.

## Migration Plan

1. Commit the six files as received; apply nothing (the targets already match).
2. Fix, test in scratch repositories, apply the two targets alone with `--exclude=scripts`, commit.
3. Rollback: `git revert` the fix commit and apply the targets again; to drop the tasks entirely, revert both commits and delete `~/.config/mise/lib/scm.sh` and `~/.config/mise/tasks/{scm,agent}` with the user's go, since removing a source file does not delete its target.

## Open Questions

None.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
