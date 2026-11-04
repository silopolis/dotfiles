## 1. Plan

- [x] 1.1 Write the proposal, design, delta spec and tasks; add row 22 to the audit change map (`openspec validate --all --strict`)
- [x] 1.2 Propose commit `docs(chezmoi:spec): add the fix-prompt-delivery change`; reply to the sender in this tab with the change id (`git show --stat HEAD` lists only `openspec/` and `docs/audits/` files)
- [x] 1.3 Amend the artifacts after the sender's real-TUI correction (wait for the TUI to draw, 5 submissions, `--workspace` resolved before anything is created); propose commit `docs(chezmoi:spec): wait for the TUI to draw in fix-prompt-delivery` and answer the sender (`openspec validate fix-prompt-delivery --strict`)

## 2. Harness first

- [ ] 2.1 Write `tests/global-mise-tasks/fake-herdr` (state directory, scenario variables, call log, paste counter, blank screen for N reads or forever with submissions lost while blank, input wrapped at a set width with cut words, a workspace list without `nope`) (`shellcheck tests/global-mise-tasks/fake-herdr`)
- [ ] 2.2 Write `tests/global-mise-tasks/prompt-delivery.sh`: finds the helper in `home/dot_config` or `dot_config`, replaces `sleep`, runs every direct scenario of the delta spec, then the `mise run` scenarios with a scratch `MISE_CONFIG_DIR`, and removes its scratch directory on exit (`shellcheck -x tests/global-mise-tasks/prompt-delivery.sh`)
- [ ] 2.3 Run it against the current helper: it exits non-zero, and the failing cases include the input-box ones on the paste count, the draw wait and the bad workspace (`tests/global-mise-tasks/prompt-delivery.sh; echo $?`)
- [ ] 2.4 Keep it out of chezmoi: while `adopt-chezmoiroot` is not applied, add `tests` to the temporary block of `.chezmoiignore` and to that change's task 3.2 (`chezmoi managed | grep -c '^tests'` prints 0)
- [ ] 2.5 Propose commit `test(dev:git): reproduce the duplicate first prompt with a fake herdr` (`git show --stat HEAD` lists `tests/`, `.chezmoiignore` and the `adopt-chezmoiroot` tasks file)

## 3. Helper

- [ ] 3.1 `scm.sh`: limit variables, `scm_herdr` (timeout, error code), agent status, screen read, drawn-screen test and whitespace-free marker check in `jq`, screen tail (`shellcheck -x dot_config/mise/lib/scm.sh`)
- [ ] 3.2 Rewrite `scm_prompt_agent` (idle wait, wait for the TUI to draw, pause, inspection loop with 5 submissions, outcome in `SCM_PROMPT_OUTCOME`, stderr report), add `scm_prompt_next_step`, and update the comment, including the warning about subshells (`shellcheck -x dot_config/mise/lib/scm.sh`)

## 4. Callers

- [ ] 4.1 `scm:worktree:new`: `--prompt` help text, workspace resolved with the other refusals into its own variable, warning with the next step, `jq -nc` with `prompt` (`shellcheck -x dot_config/mise/tasks/scm/worktree/executable_new`)
- [ ] 4.2 `agent:dispatch`: exit message with the next step for the outcome, `jq -nc` (`shellcheck -x dot_config/mise/tasks/agent/executable_dispatch`)
- [ ] 4.3 The harness passes (`tests/global-mise-tasks/prompt-delivery.sh` exits 0; `test ! -e` on its scratch directory)
- [ ] 4.4 Regression of the worktree tasks: create, list and remove a worktree in a scratch repository (`mise run scm:worktree:new feat/r --json | jq -e '.prompt == "none"'`; `mise run scm:worktree:rm r` exits 0)
- [ ] 4.5 Apply the targets alone (`chezmoi apply --exclude=scripts ~/.config/mise/lib ~/.config/mise/tasks`), then `chezmoi diff --exclude=externals,scripts ~/.config/mise/lib ~/.config/mise/tasks` prints nothing and `mise tasks ls --global` lists five tasks

## 5. Live check (user's go at this step)

- [ ] 5.1 Throwaway scratch repository under `/tmp/opencode/` with a bare origin and an `AGENTS.md`; `mise run scm:worktree:new feat/live --tab --workspace chezmoi --agent-kind opencode --agent-name chezmoi-live --prompt "Reply with the single word ok and do nothing else. @AGENTS.md" --json`; note the screen reads before the TUI drew (`jq -r .prompt` prints `working`)
- [ ] 5.2 The prompt is on the agent's screen once, and the number of reads before the TUI drew is recorded in the design's Context, next to the sender's 10 s (`herdr agent read chezmoi-live --source visible`, marker counted with the helper's normalization prints 1)
- [ ] 5.3 Clean up: `mise run scm:worktree:rm live --force` closes the tab, the scratch repository is deleted (`herdr agent get chezmoi-live` fails with `agent_not_found`; `test ! -e` on the scratch directory)
- [ ] 5.4 Propose commit `fix(dev:git): deliver the first prompt once and report its outcome` (`git show --stat HEAD` lists only `dot_config/mise/` files)

## 6. Close

- [ ] 6.1 Tell the Neovim repository that the change is applied, so that its `session:start` can go back to `--prompt`: the agent that received the brief (`chezmoi-wtasks`) is closed, so prompt the orchestrator named in its roadmap (`nvim-orch` on 2026-11-03), or ask the user when none runs (`herdr agent get nvim-orch` exits 0; `herdr agent read nvim-orch --source visible` shows the line)
- [ ] 6.2 `openspec validate fix-prompt-delivery --strict`; `/opsx-verify fix-prompt-delivery`
- [ ] 6.3 Archive (`openspec archive fix-prompt-delivery --yes`), mark row 22 of the change map as done, and propose commit `docs(chezmoi:spec): archive fix-prompt-delivery`; no cem checklist line exists for this change (`rg -n 'fix-prompt-delivery' ~/Work/cles-en-main/migrations/2026-10-omalap-to-ulap01/checklist.md` prints nothing)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
