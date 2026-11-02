# global-mise-tasks Specification

## Purpose

The global mise tasks this repository deploys for any git repository: creating, removing, cleaning and listing worktrees (`scm:worktree:*`), and dispatching an agent into another repository's herdr workspace (`agent:dispatch`), with their safety rules, project hooks and settings.

Unless stated otherwise, scenarios run in a scratch repository whose `origin` is a bare repository on branch `main`, both under `/tmp/opencode`, with `WORKTREES_ROOT` pointing inside the same scratch directory and `HERDR_ENV` unset.

## Requirements

### Requirement: Global tasks are deployed and listed

The repository SHALL deploy the helper `~/.config/mise/lib/scm.sh` and the global file tasks `scm:worktree:new`, `scm:worktree:rm`, `scm:worktree:done`, `scm:worktree:ls` (aliases `scm:wt:new`, `scm:wt:rm`, `scm:wt:done`, `scm:wt:ls`) and `agent:dispatch`, the tasks executable.

#### Scenario: Tasks are listed

- **WHEN** `mise tasks ls --global` runs from a directory with no project config
- **THEN** it lists `agent:dispatch`, `scm:worktree:done`, `scm:worktree:ls`, `scm:worktree:new` and `scm:worktree:rm`

#### Scenario: Aliases resolve

- **WHEN** `mise run scm:wt:ls --no-pr` runs in the scratch repository
- **THEN** it exits 0 and prints the same table as `mise run scm:worktree:ls --no-pr`

#### Scenario: Targets match the source

- **WHEN** `chezmoi diff --exclude=externals,scripts ~/.config/mise/lib ~/.config/mise/tasks` runs
- **THEN** it prints nothing, and `stat -c '%a' ~/.config/mise/tasks/scm/worktree/*` shows an executable mode for each task

### Requirement: Tasks are generic and clean

The helper and tasks SHALL pass `shellcheck -x` and SHALL hold no home path, user name, host name or credential, since they ship in a public repository.

#### Scenario: shellcheck is clean

- **WHEN** `shellcheck -x` runs on `dot_config/mise/lib/scm.sh` and every file under `dot_config/mise/tasks/`
- **THEN** it exits 0

#### Scenario: Nothing machine-specific

- **WHEN** `rg -n -e "$HOME" -e "$USER" dot_config/mise/lib dot_config/mise/tasks` runs
- **THEN** it prints nothing

### Requirement: Creating a worktree

`scm:worktree:new <type>/<stem>` SHALL create the branch from `--base` (default `origin/main`) in a worktree at `<root>/<prefix>-<stem>`, where `<root>` is `WORKTREES_ROOT` (default `~/Work/trees`) and `<prefix>` comes from `--prefix`, then `WORKTREES_PREFIX`, then the mise var `scm_worktrees_prefix` (with `{repo}` and `{dir}` expanded), then the origin repository name.
It SHALL refuse, creating nothing, when the branch exists locally or on origin, when the path exists, or when the repository defines its own `worktree:new` or `worktree:rm` task and `--generic` is not given.
It SHALL trust the new worktree with `mise trust` only when the source checkout is trusted, and SHALL record the commit the branch starts from.

#### Scenario: Happy path

- **WHEN** `mise run scm:worktree:new feat/demo --prefix demo` runs
- **THEN** it exits 0, prints `$WORKTREES_ROOT/demo-demo`, `git worktree list` shows that path on branch `feat/demo`, and `cat "$(git -C "$WORKTREES_ROOT/demo-demo" rev-parse --absolute-git-dir)/scm-base"` prints the commit of `origin/main`

#### Scenario: Duplicate branch is refused

- **WHEN** the same command runs a second time
- **THEN** it exits 1 with an error naming the existing branch, and `git worktree list | wc -l` is unchanged

#### Scenario: Repository with its own worktree task

- **WHEN** the scratch repository has a trusted `mise.toml` defining a task `worktree:new` and `mise run scm:worktree:new feat/other` runs
- **THEN** it exits 1 and tells to use that task or pass `--generic`

### Requirement: Source checkout integrity

`scm:worktree:new`, `scm:worktree:rm` and `scm:worktree:done` SHALL check that the source checkout has no `core.worktree` setting, before and after their git steps, and when it has one SHALL report an incident and exit with status 3 without unsetting it.

#### Scenario: core.worktree is reported, not fixed

- **WHEN** `git config core.worktree /tmp` is set in the scratch repository's main checkout and `mise run scm:worktree:new feat/x` runs there
- **THEN** it exits 3 with a message starting with `INCIDENT: core.worktree`, creates no branch, and `git config --file .git/config --get core.worktree` still prints `/tmp`

### Requirement: Merge test

A branch SHALL count as merged when its tip is an ancestor of `origin/main`, or when `gh` reports a merged pull request from that branch into `main` whose head commit equals the local tip.
`scm:worktree:rm` SHALL also accept a tip that is an ancestor of the main checkout's `HEAD`.
When `gh` is missing or fails, only the git tests SHALL apply.

#### Scenario: Squash-merged branch

- **WHEN** a worktree branch with one commit is squash-merged into `main` and pushed, a fake `gh` first on `PATH` answers `pr list` with `[{"number":7,"headRefOid":"<branch tip>"}]`, and `mise run scm:worktree:done <stem>` runs
- **THEN** it exits 0 and the worktree and its local branch are gone

#### Scenario: Commits after the merge keep the branch

- **WHEN** the same setup has one more local commit on the branch, so the fake answer's `headRefOid` is no longer the tip, and `mise run scm:worktree:done <stem>` runs
- **THEN** it exits 1 and the worktree is still listed by `git worktree list`

#### Scenario: No gh

- **WHEN** the squash-merged setup runs with a fake `gh` that exits 1
- **THEN** `mise run scm:worktree:done <stem>` exits 1 and its message says the pull request lookup was not available

### Requirement: Removing a worktree

`scm:worktree:rm <target>` SHALL refuse a worktree with uncommitted or untracked files, or an unmerged branch, unless `--force` is given; it SHALL run the project hook `scm:worktree:hook:post-remove` when defined, untrust the worktree, remove it and its local branch, and never touch the remote branch.

#### Scenario: Dirty worktree is refused

- **WHEN** a file is added in a worktree and `mise run scm:worktree:rm <stem>` runs
- **THEN** it exits 1 and the worktree still exists

#### Scenario: Remote branch is kept

- **WHEN** a worktree branch is pushed, merged into `main`, and `mise run scm:worktree:rm <stem>` runs
- **THEN** it exits 0, the local branch is gone, and `git ls-remote --heads origin <branch>` still prints it

### Requirement: Cleaning merged worktrees

`scm:worktree:done` SHALL remove only worktrees whose branch is merged and has commits of its own since its recorded start commit (else since the creation entry of its reflog).
`--all-merged` SHALL skip, with the reason printed, every worktree whose branch has no commits of its own, whose start is unknown, that is dirty, or that is not merged.
`done <target>` on a branch with no commits of its own SHALL refuse and point to `scm:worktree:rm`.

#### Scenario: Fresh worktree survives --all-merged

- **WHEN** `mise run scm:worktree:new feat/fresh` runs, then `mise run scm:worktree:done --all-merged`
- **THEN** the second command exits 0, prints a skip line for the fresh worktree saying it has no commits of its own, and the worktree is still listed by `git worktree list`

#### Scenario: Merged worktree is cleaned by --all-merged

- **WHEN** a worktree branch with one commit is merged into `main` (fast-forward), pushed, and `mise run scm:worktree:done --all-merged` runs
- **THEN** it exits 0, reports one cleaned, and the worktree is gone

#### Scenario: Explicit target without own commits

- **WHEN** `mise run scm:worktree:done fresh` runs on the fresh worktree
- **THEN** it exits 1 and its message names `scm:worktree:rm`

### Requirement: Listing worktrees

`scm:worktree:ls` SHALL print one row per worktree of the current repository (with `--all`, of every repository with a worktree under the worktrees root) with branch, ahead and behind counts against `origin/main`, dirty state, pull request, herdr tab and agent, and SHALL print JSON with `--json`.

#### Scenario: JSON listing

- **WHEN** one worktree exists and `mise run scm:worktree:ls --no-pr --json` runs
- **THEN** `jq length` on its output prints 2 (the main checkout and the worktree)

### Requirement: Dispatching an agent

`agent:dispatch` SHALL refuse an agent name that does not match `[a-z][a-z0-9_-]{0,31}`, a brief path that is not absolute or does not exist, a missing target directory, and an existing agent name; when the agent cannot start, it SHALL close the tab it created.

#### Scenario: Relative brief is refused

- **WHEN** `mise run agent:dispatch --workspace x --cwd /tmp --name test-agent --brief brief.md` runs
- **THEN** it exits 1 with an error saying the brief must be an absolute path, and no herdr tab is created

### Requirement: Project hooks

The tasks SHALL run the project tasks `scm:worktree:hook:post-create` (inside the new worktree, with `WT_PATH`, `WT_BRANCH`, `WT_NAME`, `WT_STEM`, `WT_REPO`, `WT_ENV_FILE`), `scm:worktree:hook:post-remove` (with `WT_REASON` and `WT_TAB` as well) and `scm:worktree:hook:incident`, when the project defines them, and SHALL do nothing otherwise.

#### Scenario: post-create hook runs

- **WHEN** the scratch repository has a trusted `mise.toml`, committed and pushed to `main`, with a task `scm:worktree:hook:post-create` that writes `$WT_STEM` to a file in `/tmp/opencode`, and `mise run scm:worktree:new feat/hooked` runs
- **THEN** that file contains `hooked`

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->

