## Context

- `scm_prompt_agent` (in `dot_config/mise/lib/scm.sh`, adopted with `adopt-global-mise-tasks`) runs `herdr agent prompt <name> <text> --wait --until working --timeout 20000`.
  On `agent_prompt_stalled` or a timeout, it sleeps 2 s and submits the same text again, up to six times.
- herdr 0.9.5, `herdr agent prompt --help`: a submission to a blocked agent is refused with `agent_blocked` before any input is sent.
  With `--wait`, an accepted submission must reach `working` or `blocked` within 5 s, or herdr answers `agent_prompt_stalled`; a caller timeout that expires first answers `timeout`.
  herdr's documentation adds that neither proves the prompt was not delivered.
- Other herdr commands used: `agent get` (`.result.agent.agent_status`: `idle`, `working`, `blocked`, `done`, `unknown`), `agent read --source visible` (plain text), `agent send-keys <name> enter`, `agent wait --until <state> --timeout <ms>`.
  On error they print `{"error":{"code":...}}` and exit 1, with `agent_not_found` for an unknown name.
  `agent read --source recent --lines <n>` fails with `agent_not_idle` while the agent works, whereas `--source visible` always answers (checked on 2026-11-03).
- The sender's real-TUI test (2026-11-03): herdr reports `interactive_ready: true` and `idle` as soon as `agent start` returns, but opencode draws nothing for about 10 s (blank visible screen; longer in a fresh worktree).
  Every prompt sent in that window is lost: three quick submissions in the first 20 s or so were all lost.
- `herdr agent prompt` pastes the text, then sends Enter.
  In the opencode TUI, a trailing `@file` opens the file autocomplete popup, which takes that Enter, so the text stays in the input.
  The Neovim repository saw this in nine sessions, once with a stray `@explore` completion in the input.
- The input box and history are drawn with box-drawing characters (U+2500 to U+259F), and long input wraps at the box width.
- Callers:
  - `agent:dispatch` sends `Read and execute the brief at <path>` and exits 1 when the helper fails, telling the user to send the prompt by hand;
  - `scm:worktree:new --prompt` warns and exits 0.
- `scm:worktree:new --json` and `agent:dispatch --json` print with `jq -n`, which spreads the object over several lines.
- `scm:worktree:new --tab` resolves the workspace after it has created the worktree, run the post-create hook and trusted the path.
  It does so with `workspace=$(scm_workspace_id "$workspace") || scm_die "herdr workspace '$workspace' not found"`; on failure the assignment has already emptied the variable, so the message names `''`.
  `agent:dispatch` names `--workspace` from the flag and is not affected.
- The sender wrote the same algorithm in Python (`workflow.delivery.deliver` in the Neovim repository, with a fake TUI in its unit tests).
  This design transcribes it, with the four deviations listed below, which the user approved on 2026-11-03.
  The sender then adopted deviations 1 and 2 and, after its real-TUI test, added a wait for the TUI to draw and raised the submission budget to 5 (brief updated the same day).
- The repository has no shell test harness; `adopt-global-mise-tasks` ran its checks from a scratch script and then deleted it.

## Goals / Non-Goals

**Goals:**

- When the text may already be on screen, it is never pasted again.
- Each failure gives an outcome the caller can act on, with the screen tail as evidence.
- Callers can parse the result of `scm:worktree:new --json` and see whether the prompt was delivered.
- A harness, kept in the repository, checks the delivery cases without herdr or an agent.

**Non-Goals:**

- Configurable limits and timeouts: a default setting and an override flag are a follow-up (see Open Questions).
- Prompts sent after the start: the helper serves only the first prompt of a new agent.
- Reporting the popup behaviour to herdr or opencode.
- Changing the prompt texts of the callers.

## Decisions

### Inspect before any retry

The helper follows the sender's algorithm:

1. `herdr agent wait <name> --until idle --timeout 15000`; a failure is not fatal.
2. Wait for the TUI to draw: read `herdr agent read <name> --source visible` every second, up to 60 reads, until at least 5 lines hold something besides frame characters and whitespace.
   A failed read counts as a blank screen.
   herdr's `idle` and `interactive_ready` come long before the TUI draws, and a prompt sent to a blank screen is lost.
   When the screen never draws, the helper submits anyway and lets the inspection decide; the stderr report then says the screen stayed blank.
   Then sleep 1 s, so that the input box is listening.
3. Submit: `herdr agent prompt <name> <text> --wait --until working --timeout 20000`.
   Success means delivered.
4. `agent_blocked`: stop with `blocked` (nothing was sent).
5. Any other failure, including unknown codes, goes through an inspection loop and never straight to a new submission.
   Each pass of the loop sleeps 1.5 s, then:
   - `agent get`: `working` or `done` means delivered; `blocked` stops with `blocked`;
   - `agent read --source visible`: when the screen cannot be read, stop with `unreadable`;
   - prompt not on screen: leave the loop and submit again, at most 5 submissions in all, after which the outcome is `lost`;
   - prompt on screen: when 2 Enter presses are already spent, stop with `unsent`; otherwise run `herdr agent send-keys <name> enter`, and when `herdr agent wait <name> --until working --timeout 8000` succeeds, the prompt is delivered.

A lost prompt is safe to send again, because its text is not on the screen; hence 5 submissions, the sender's figure after its test, instead of 3.
The limits (5 submissions, 2 Enter presses, 24-character marker, 60 screen reads 1 s apart, 5 drawn lines, waits of 15 s, 20 s and 8 s, pauses of 1 s and 1.5 s) are shell variables set at the top of the helper section, so the harness can shorten the pauses.
Alternative considered: trust `interactive_ready` or `idle` alone. Rejected: the sender's test shows both are true while the screen is still blank.
Alternative considered: a fixed delay of 10 to 20 s. Rejected: it is too long for a warm TUI and too short for a fresh worktree.
Alternative considered: always press Enter after a delay. Rejected because it hides lost prompts and could submit something half-typed in the input.
Alternative considered: Escape to close the popup before Enter. Rejected: it is TUI-specific, and in some TUIs Escape interrupts the agent.

### Marker without whitespace (deviation 1)

The prompt counts as on screen when its first 24 non-whitespace characters appear in the visible screen once frame characters and all whitespace are removed from both.
The sender collapses whitespace instead, so a word cut at the wrap column (`bri` / `ef`) misses the marker, and the helper concludes the prompt was lost and pastes it a second time.
Removing all whitespace makes the match independent of the wrap column.
The normalization runs in `jq` (codepoint-based whatever the locale; the audit's F21 shows the locale is not reliable here).

### `done` counts as delivered (deviation 2)

The new tab is created with `--no-focus`, so herdr shows an agent that finished its turn as `done`, not `idle`.
A quick answer between two polls would otherwise get two useless Enter presses and a false `unsent`.
The helper waits for `idle` before submitting, so a `done` status after the submission comes from the prompt just sent.

### Outcomes, and how callers get them (deviation 3)

The outcomes are `working` (taken up: seen working, or done), `unsent` (still in the input after the Enter budget), `lost` (submission budget spent, prompt never on screen), `blocked` and `unreadable`.
The sender's name for the last one was `unknown`; the user chose `unreadable`, which says what happened.
The helper sets `SCM_PROMPT_OUTCOME` and keeps its return contract (0 only for `working`).
Callers call it directly, never in `$(...)`, so the variable reaches them; the helper's comment says so.
`scm_prompt_next_step <outcome> <tab>` gives the next step for the caller's message:

- `unsent`: press Enter in the tab;
- `lost`: send the prompt again by hand;
- `blocked`: answer the dialog in the tab;
- `unreadable`: look at the tab before sending anything.

When the helper stops, it prints to stderr a line with the outcome and the counts (submissions, Enter presses, screen reads before the TUI drew, or that it never drew), then the last 15 non-blank lines of the screen; nothing else is pasted.

### Bounded herdr calls (deviation 4)

Every herdr call in the helper goes through `scm_herdr <seconds> <args...>`, which runs `timeout`.
Calls that wait get their wait time plus 10 s; the other calls get 15 s.
Exit status 124 counts as the error code `timeout`.
The error code comes from the JSON that herdr prints (`jq` over stdout and stderr together); when no code can be found, the call counts as `failed`.

### One-line JSON

`scm:worktree:new --json` uses `jq -nc` and adds `prompt`: one of the outcomes above, or `none` when no prompt was sent (no `--prompt`, or no agent).
`agent:dispatch --json` also switches to `jq -nc`, for the same parsers; it only prints on success, so it has no `prompt` field.
A parser of the whole output works with both forms.

### Help text

`--prompt` gets: `First prompt sent to the agent; a text ending in a file reference such as @file opens the TUI's autocomplete, which may swallow the Enter`.

### Workspace resolved before anything is created

With `--tab`, `scm:worktree:new` resolves the workspace together with its other refusals (duplicate branch or path), before `git worktree add`, into a separate variable, so that the message keeps the user's value: `herdr workspace 'nope' not found (or several share that label)`.
A wrong flag then leaves no worktree, branch or trust entry behind.
Alternative considered: fix only the message where the check is today. Rejected because the failure would still leave a worktree for a typo; the sender reported only the message.

### Test harness

- `tests/global-mise-tasks/fake-herdr` is a bash script, put first on `PATH` by the harness.
  It keeps its state in a directory (input box, history, status, counters) and takes the scenario from environment variables: blank screen for the first N reads (submissions while blank are lost, as in opencode) or forever, lose the first N submissions, leave the text in the input, the Nth Enter submits, never start, blocked, stall although working, done after a stall, unreadable screen, failing idle wait, input width.
  A drawn screen shows a few lines of TUI chrome, the history and the input.
  It answers `agent prompt`, `get`, `read`, `send-keys`, `wait`, `start`, `tab create`, `tab close`, `workspace list` and `notification show`, and logs every call.
  Its `read` wraps the input at the configured width, cutting words, behind a `┃` frame.
- `tests/global-mise-tasks/prompt-delivery.sh` sources the helper from the source tree, under `home/dot_config` or `dot_config`, so it works in both layouts.
  It replaces `sleep` with a no-op and runs each case against `scm_prompt_agent` directly.
  Then it runs `scm:worktree:new --tab --agent-kind ... --prompt ... --json` and `agent:dispatch` through `mise run`, with a scratch `MISE_CONFIG_DIR` built from the source.
  It asserts outcome, return status, submissions, Enter presses and, above all, pastes: never more than one paste while the text was on screen.
  Scratch files live under `/tmp/opencode/` and are removed on exit.
- The harness first runs against the current helper; it must fail on the paste count of the input-box cases, which shows the defect.
- Repository file, not a target: listed in the temporary `.chezmoiignore` block while `adopt-chezmoiroot` is not applied, and added to that change's task 3.2, which drops the block.

### Live check (user decision)

With the user's go at that step:

- Create a scratch repository under `/tmp/opencode/` with a bare origin and an `AGENTS.md`.
- Run `mise run scm:worktree:new feat/live --tab --workspace chezmoi --agent-kind opencode --agent-name chezmoi-live --prompt "Reply with the single word ok and do nothing else. @AGENTS.md" --json`.
- Expect `"prompt":"working"` and the marker exactly once on the agent's screen; note from the stderr trace how many screen reads passed before the TUI drew, to compare with the sender's 10 s.
- Finish with `mise run scm:worktree:rm live --force`, which closes the tab, then delete the scratch repository.

## Risks / Trade-offs

- [Risk] A quick answer puts the text in the history, not the input, and the helper reads it as waiting. → With `done` counted as delivered this is rare; otherwise Enter on an empty input does nothing, and the outcome is `unsent`, reported and never pasted again.
- [Risk] Enter while the popup is open picks a completion, like the stray `@explore`. → At most 2 Enter presses; the `unsent` message sends the user to the tab to check the input, and the help text warns against a trailing `@file`.
- [Risk] The Python and bash versions drift. → Each repository tests its own; the deviations are named here and in the reply to the sender.
- [Risk] herdr changes its error codes. → Unknown codes take the inspection path, never a blind resubmission.
- [Risk] A caller runs the helper in a subshell and loses the outcome. → Both callers call it directly, and the helper's comment warns about it.
- [Risk] The harness and the live check write outside `$HOME`, in `/tmp/opencode/` (scratch repositories, worktrees, fake herdr state). → One directory per run, removed on exit and checked with `test ! -e`; the live check removes its worktree with `scm:worktree:rm --force` and closes its tab, and its agent spends one short turn; opencode keeps a project record for the scratch path in its own database.
- [Risk] Another agent kind draws fewer than 5 lines, or shows 5 lines of splash screen before its input listens. → The first case costs 60 s and then submits anyway; in the second, a lost prompt is not on screen, so it is sent again within the budget of 5.
- [Trade-off] The first prompt waits for the TUI to draw (about 10 s for opencode) plus 1 s.
  The worst case is about 4 min: 15 s idle wait, 60 s of screen reads, then 5 submissions with their 20 s waits, inspection passes and two 8 s Enter waits.
  That is long, but bounded and visible on stderr, where the old helper pasted blindly.

## Migration Plan

1. Commit the harness and run it against the current helper (expected failures on the paste count).
2. Change the helper and the callers, run the harness until it passes, run `shellcheck -x`, apply `~/.config/mise/lib` and `~/.config/mise/tasks` alone with `--exclude=scripts`, then run the live check.
3. Rollback: `git revert` the fix commit and apply the two targets again; the harness then fails again, as expected.

## Open Questions

- Follow-up suggested by the user on 2026-11-03: a default setting for the timeouts and limits (for example a mise var or `conf.d` value) and an override flag on the callers.
  Recorded here and in the change map; not in this change.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
