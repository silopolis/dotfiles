## Why

`scm_prompt_agent`, the helper of the global mise tasks that sends a new agent its first prompt, treats every stalled or timed-out `herdr agent prompt --wait` as a lost prompt and pastes the same text again, up to six times.
herdr's own help says a stall does not prove that nothing was delivered.
In the Neovim repository's sessions, a prompt ending in a file reference (`@file`) opened the opencode autocomplete popup, which took the Enter; the helper then filled the input box with copies of the prompt.
Any slow TUI can cause the same thing, and both callers are affected: `agent:dispatch` and `scm:worktree:new --prompt`.
A real-TUI test by the sender showed a second way to lose the first prompt: herdr reports the agent ready and idle as soon as `agent start` returns, but opencode draws nothing for about 10 s, and every prompt sent in that window is lost.
`scm:worktree:new --json` also prints its JSON over several lines and says nothing about the prompt, so a caller that reads the last line gets `}` and cannot tell whether the agent got its prompt.
With an unknown `--workspace`, `scm:worktree:new --tab` dies with `herdr workspace '' not found`, after creating the worktree.
Source: request of the Neovim repository (session S19), 2026-11-03, following `adopt-global-mise-tasks`; the mise config is a managed application config (audit `docs/audits/2026-10-30-environment.md`, section 2.7; change map row 22).

## What Changes

- Before the first submission, the helper waits up to 15 s for the agent to be idle (a failure is not fatal).
  It then reads the visible screen every second, up to 60 times, until the TUI is drawn (at least 5 lines with something besides frame characters), and pauses for 1 s; a screen that never draws does not stop the submission.
- After a submission that herdr does not confirm, the helper inspects the agent before any retry:
  - status `working` or `done`: delivered;
  - `blocked`: stop;
  - prompt still on screen: press Enter, at most twice, and never paste it again;
  - prompt not on screen: submit again, at most 5 submissions in all (a lost prompt is safe to resend);
  - screen cannot be read: stop.
- When the helper stops, it returns non-zero, prints the outcome and the last 15 lines of the screen on stderr, and leaves the outcome for its caller: `working`, `unsent`, `lost`, `blocked` or `unreadable`.
- Every herdr call runs under a timeout.
- Each caller's message names the next step for that outcome; `agent:dispatch` no longer says "send the prompt by hand" when the text may already be in the input.
- `scm:worktree:new --json` prints one line and adds `"prompt"`, which is one of those outcomes or `none`; `agent:dispatch --json` also prints one line.
- The help of `--prompt` warns that a text ending in a file reference such as `@file` opens the TUI's autocomplete and may swallow the Enter.
- `scm:worktree:new --tab` resolves `--workspace` before it creates anything, and an unknown workspace is named in the error.
- A committed test harness with a fake `herdr` checks the delivery cases by counting how many times the text reached the input.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `global-mise-tasks`: new requirements for first prompt delivery, for the outcome reported by the callers, for bounded herdr calls, for the `--prompt` help and for the `--workspace` check.

## Impact

- `dot_config/mise/lib/scm.sh` (`scm_prompt_agent` and new helpers), `dot_config/mise/tasks/scm/worktree/executable_new`, `dot_config/mise/tasks/agent/executable_dispatch` (under `home/` after `adopt-chezmoiroot`).
- New repository directory `tests/global-mise-tasks/`, not a chezmoi target: listed in the temporary `.chezmoiignore` block, and in `adopt-chezmoiroot` task 3.2, while that change is not applied.
- The return status contract stays: 0 delivered, non-zero not delivered, message on stderr.
  The first prompt takes longer: about 10 s while opencode draws, plus 1 s.
- `--json` of both tasks stays one JSON object, now compact.
- The Neovim repository's `session:start` delivers its first prompt with its own helper; it can switch back to `--prompt` once this change is applied.
- Live check, with the user's go: one throwaway opencode agent in a herdr tab of the chezmoi workspace, removed afterwards.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
