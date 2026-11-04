## MODIFIED Requirements

### Requirement: Global tasks are deployed and listed

The repository SHALL deploy the helper `~/.config/mise/lib/scm.sh` and the global file tasks `scm:worktree:new`, `scm:worktree:rm`, `scm:worktree:done`, `scm:worktree:ls` (aliases `scm:wt:new`, `scm:wt:rm`, `scm:wt:done`, `scm:wt:ls`), `agent:dispatch` and `openspec:roadmap`, the tasks executable.

#### Scenario: Tasks are listed

- **WHEN** `mise tasks ls --global` runs from a directory with no project config
- **THEN** it lists `agent:dispatch`, `openspec:roadmap`, `scm:worktree:done`, `scm:worktree:ls`, `scm:worktree:new` and `scm:worktree:rm`

#### Scenario: Aliases resolve

- **WHEN** `mise run scm:wt:ls --no-pr` runs in the scratch repository
- **THEN** it exits 0 and prints the same table as `mise run scm:worktree:ls --no-pr`

#### Scenario: Targets match the source

- **WHEN** `chezmoi diff --exclude=externals,scripts ~/.config/mise/lib ~/.config/mise/tasks` runs
- **THEN** it prints nothing, and `stat -c '%a' ~/.config/mise/tasks/scm/worktree/* ~/.config/mise/tasks/openspec/*` shows an executable mode for each task

### Requirement: Tasks are generic and clean

The helper and tasks SHALL be checked by their language: shell files pass `shellcheck -x`; Python files compile with `python3 -m py_compile`, use only the standard library, and have unit tests that pass; all of them SHALL hold no home path, user name, host name or credential, since they ship in a public repository.

#### Scenario: shellcheck is clean

- **WHEN** `shellcheck -x` runs on `dot_config/mise/lib/scm.sh` and on every shell file under `dot_config/mise/tasks/`
- **THEN** it exits 0

#### Scenario: Python compiles and its tests pass

- **WHEN** `python3 -m py_compile` runs on every Python file under `dot_config/mise/lib/` and `dot_config/mise/tasks/`, then `python3 -m unittest discover -s tests/global-mise-tasks` runs
- **THEN** both exit 0

#### Scenario: Nothing machine-specific

- **WHEN** `rg -n -e "$HOME" -e "$USER" dot_config/mise/lib dot_config/mise/tasks` runs
- **THEN** it prints nothing

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
