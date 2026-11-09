## Why

Starting an agent on a new piece of work is done by hand every time:

- a worktree,
- a herdr workspace,
- an agent in plan mode, and
- a first prompt sent after the TUI has drawn.

Nothing creates a herdr workspace: the global tasks only start an agent in a tab of a workspace that already exists.
The helper that sends the first prompt (`scm_prompt_agent`, used by `scm:worktree:new --prompt` and `agent:dispatch`) treats every stalled or timed-out `herdr agent prompt --wait` as a lost prompt and pastes the same text again, up to six times.
herdr's own help says a stall does not prove that nothing was delivered.
A prompt ending in a file reference (`@file`) opened OpenCode's autocomplete, which took the `Enter`, and the helper then filled the input box with copies.
herdr reports an agent ready and idle as soon as `agent start` returns, but OpenCode draws nothing for about 10 s, and every prompt sent in that window is lost.
`scm:worktree:new --json` prints its JSON over several lines and says nothing about the prompt, and with an unknown `--workspace` it dies after creating the worktree.
The Neovim configuration repository solved delivery in Python with a tested module (merged on its main branch, with a real-TUI check), runs its sessions with its own task, and keeps the `--prompt` return, the one-line JSON and the unknown workspace in its backlog.
herdr 0.9.5 now has worktree-backed workspaces (`herdr worktree list|create|open|remove`): its list gives, for each worktree, the branch, the path and the workspace open on it.
This change replaces `fix-prompt-delivery`, which only existed as planning (shell port of the delivery, same requirements), and goes further: workspace creation and a launch flow, generic for any repository.
Source: request of the Neovim configuration repository (session S19, 2026-11-03) for the delivery fixes; request of the user on 2026-11-04 for generic tasks that create workspaces and dispatch agents, and that the Neovim repository adopts; audit section 2.7.


## What Changes

- **Model.**
  A branch has one read-write checkout at a time (git enforces it), so a branch implies a path.
  A herdr workspace is built out of a worktree and is the home of the agents and sessions that work in it.
  Coordination across the project (orchestration, synchronization, messages between workspaces) stays one level up, in the workspace of the main checkout.
  Whether a workspace should also carry its own orchestration is not decided here.
- **Shared Python library** in the global mise lib directory, standard library only, ported from the Neovim repository's delivery module and its herdr wrapper, replacing `scm_prompt_agent`:
  - bounded herdr calls (a timeout on each, `timeout` as an error code);
  - the first prompt is delivered once: wait for idle, wait for the TUI to draw, submit with `--wait --until working`, inspect before any retry (`working` or `done` means delivered, `blocked` stops, the prompt still on screen gets `Enter` at most twice and is never pasted again, a prompt not on screen is submitted again, 5 submissions at most), outcome `working`, `unsent`, `lost`, `blocked` or `unreadable`;
  - lookups of the state of a branch, a worktree, a workspace and an agent name.
- **Two new global tasks** (names to confirm in the design):
  - `workspace:open <branch|path>` creates, or reuses, the herdr workspace of a worktree, and prints one JSON line.
  - `agent:launch <branch>` does the whole flow: creates the worktree when the branch is new (through `scm:worktree:new`), opens its workspace, starts the agent (default kind OpenCode, plan mode by default, optional model settings), delivers the first prompt, and prints one JSON line with the outcome.
- **Checks before anything is created.**
  Each case ends in reuse, create or refuse, and a refusal names what it found:

  - the branch exists, is checked out, and where;
  - a workspace is already open on that path (reuse);
  - a workspace has the requested label but another path, or several share the label (refuse);
  - the agent name is taken (refuse).
- **`agent:dispatch` and `scm:worktree:new --prompt`** keep their interfaces and use the library; both print one JSON line with the delivery outcome.
  `scm:worktree:new --tab` resolves `--workspace` before it creates anything and names the value it was given.
  The help of `--prompt` warns that a text ending in `@file` may swallow the Enter.
- **Tests.**
  Python unit tests with a fake `herdr` that counts how many times the text reached the input box (`tests/global-mise-tasks/`, at the repository root and so outside the source state: no ignore entry), plus a live check with one throwaway agent, with the user's go.
- **Replaces `fix-prompt-delivery`.**
  Every requirement of that change moves into the `agent-launch` capability, its directory is deleted (it holds planning only; git keeps the history), and its audit row is marked as superseded.
  Its closing duty moves here: when this change is applied, the Neovim repository is told, so that `session:start` can use the global tasks.
- **Depends on `add-repo-roadmap`** for the amended rule on Python in the global tasks directory (shell files pass `shellcheck -x`, Python files compile and have unit tests).
- **Observations.**
  The launch of the roadmap agent, done by hand with the model above, is logged in `observations.md` in this folder: it is the input for the design and for a signal to the fleet's study of multi-agent orchestration.
- **Non-goals.**
  - The architecture of multi-agent orchestration, and where a launcher belongs in the fleet's tooling (this repository or the fleet's tools).
    The tasks stay small so that they can move.
  - Any edit to the Neovim repository: it gets a signal to adopt the tasks, after this change is applied.
  - Choosing the agent's model: only passing settings through.


## Capabilities


### New Capabilities

- `agent-launch`: delivering a first prompt once, creating or reusing the workspace of a worktree, launching an agent into it, the refusals before creation, and the test harness.


### Modified Capabilities

- `global-mise-tasks`: `agent:dispatch` delivers through the library, reports the outcome, and opens the workspace by the same rules.


## Impact

- New: the Python library and the tasks `workspace:open` and `agent:launch` in `home/dot_config/mise/lib/` and `home/dot_config/mise/tasks/`, and `tests/global-mise-tasks/`.
- Changed: `scm.sh` (the prompt helper goes away), `scm:worktree:new` and `agent:dispatch`.
- Deleted: `openspec/changes/fix-prompt-delivery/` (done in the commit that created this change).
- Archive order: this change modifies only the requirement "Dispatching an agent" of `global-mise-tasks`, which no other open change touches (`add-repo-roadmap` modifies two other requirements and `add-incus-host-setup` adds one), so the archive order is free; the implementation order is not: the Python rule that `add-repo-roadmap` amends must exist before Python tasks are deployed, and `TODO.md` places this change after it.
- The return status contract of the callers stays: 0 delivered, non-zero not delivered, message on stderr; the first prompt takes longer, about 10 s while opencode draws, plus 1 s.
- Applying the targets is a single-target apply with `--exclude=scripts`, after the user's go; the live check starts one throwaway agent in a herdr workspace and removes it afterwards.
- Open questions for the design: the task names; what an existing branch with no checkout does (refuse or attach a worktree); whether the main checkout's workspace counts as a worktree workspace; how plan mode and model settings are passed; whether herdr's own `worktree open` is used or only its listing; the fate of the tab closing in `scm:worktree:done` when a workspace is the unit; a default setting for the delivery timeouts and limits (a mise var or `conf.d` value) with an override flag on the callers, suggested by the user on 2026-11-03 for the superseded change.


<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
