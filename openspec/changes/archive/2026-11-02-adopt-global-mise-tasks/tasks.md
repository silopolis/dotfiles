## 1. Plan

- [x] 1.1 Write the proposal, design, spec and tasks; add a note to `port-omalap-shell-aliases` that its worktree functions wrap these tasks or are skipped; add the change to the audit change map (`openspec validate --all --strict`)
- [x] 1.2 Propose commit `docs(chezmoi:spec): add the adopt-global-mise-tasks change` (`git show --stat HEAD` lists only `openspec/` and `docs/audits/` files)

## 2. Adopt as received

- [x] 2.1 Record the received files before any edit (`sha256sum dot_config/mise/lib/scm.sh dot_config/mise/tasks/*/executable_* dot_config/mise/tasks/scm/worktree/executable_* > /tmp/opencode/adopt-global-mise-tasks.received`) and check the targets match them (`chezmoi diff --exclude=externals,scripts ~/.config/mise/lib ~/.config/mise/tasks` prints nothing)
- [x] 2.2 Review checks: shellcheck clean (`shellcheck -x dot_config/mise/lib/scm.sh dot_config/mise/tasks/*/executable_* dot_config/mise/tasks/scm/worktree/executable_*`), nothing machine-specific (`rg -n -e "$HOME" -e "$USER" dot_config/mise/lib dot_config/mise/tasks` prints nothing), five tasks listed (`mise tasks ls --global`)
- [x] 2.3 Propose commit `feat(dev:git): add global mise tasks for git worktrees and agent dispatch` with the six files unchanged (`sha256sum -c /tmp/opencode/adopt-global-mise-tasks.received`; `git show --stat HEAD` lists exactly the six files)

## 3. Fix cleanup

- [x] 3.1 `scm:worktree:new` writes the start commit to `scm-base` in the worktree's git admin directory (scratch run: `cat "$(git -C <worktree> rev-parse --absolute-git-dir)/scm-base"` prints the base commit)
- [x] 3.2 `scm.sh` gains the start-commit lookup (file, else the reflog creation entry), the own-commits test and the shared merge test (git ancestor, else a merged pull request with the same head commit through `gh`, 15 s timeout) (`shellcheck -x dot_config/mise/lib/scm.sh`)
- [x] 3.3 `scm:worktree:rm` uses the shared merge test and keeps its local `HEAD` test (`shellcheck -x dot_config/mise/tasks/scm/worktree/executable_rm`)
- [x] 3.4 `scm:worktree:done` requires commits of its own and uses the shared merge test; `--all-merged` prints a skip reason for each worktree it leaves (`shellcheck -x dot_config/mise/tasks/scm/worktree/executable_done`)
- [x] 3.5 Run every scenario of `specs/global-mise-tasks/spec.md` in scratch repositories under `/tmp/opencode`, with a fake `gh` first on `PATH` for the pull request cases, then delete them (each scenario passes; `test ! -e /tmp/opencode/wt-check`)
- [x] 3.6 Apply the two targets alone (`chezmoi apply --exclude=scripts ~/.config/mise/lib ~/.config/mise/tasks`), then `chezmoi diff --exclude=externals,scripts ~/.config/mise/lib ~/.config/mise/tasks` prints nothing and `mise tasks ls --global` still lists five tasks
- [x] 3.7 Propose commit `fix(dev:git): clean only worktrees whose own commits are merged` (`git show --stat HEAD` lists only `dot_config/mise/` files)

## 4. Close

- [x] 4.1 Reply to the sender in this agent's tab (herdr agent `chezmoi-wtasks`) with the change id and a summary of the two fixes (`herdr agent read chezmoi-wtasks` shows the id)
- [x] 4.2 `openspec validate adopt-global-mise-tasks --strict`; `/opsx-verify adopt-global-mise-tasks`
- [x] 4.3 Archive (`openspec archive adopt-global-mise-tasks --yes`) and propose commit `docs(chezmoi:spec): archive adopt-global-mise-tasks`; no cem checklist line exists for this change (`rg -n 'adopt-global-mise-tasks' ~/Work/cles-en-main/migrations/2026-10-omalap-to-ulap01/checklist.md` prints nothing)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
