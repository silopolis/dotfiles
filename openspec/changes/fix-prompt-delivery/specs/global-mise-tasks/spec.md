## ADDED Requirements

In the scenarios below, "the fake herdr" is `tests/global-mise-tasks/fake-herdr`, first on `PATH`.
"Pastes" is the number of times it put the prompt text into the input box.
Direct cases source the helper with `sleep` replaced by a no-op and call `scm_prompt_agent test-agent "Read and execute the brief at /tmp/opencode/brief.md"`.

### Requirement: First prompt is delivered once

`scm_prompt_agent`, used by `scm:worktree:new --prompt` and `agent:dispatch`, SHALL deliver the first prompt as follows:

- before the first submission, wait up to 15 s for the agent to be `idle`, where a failed wait is not fatal, then pause 1 s;
- submit with `herdr agent prompt --wait --until working`;
- after any unconfirmed submission, inspect before doing anything else:
  - agent status `working` or `done` means delivered;
  - status `blocked` stops;
  - otherwise read the visible screen; the prompt is on screen when its first 24 non-whitespace characters appear in the screen text, with frame characters (U+2500 to U+259F) and all whitespace removed from both;
- while the prompt is on screen, press Enter at most twice and never submit the text again;
- submit again only when the prompt is not on screen, at most 3 submissions in all.

It SHALL set `SCM_PROMPT_OUTCOME` to `working`, `unsent`, `lost`, `blocked` or `unreadable`.
It SHALL return 0 only for `working`.
Whenever it stops without delivery, it SHALL print the outcome and the last 15 non-blank lines of the screen on stderr.

#### Scenario: First submission works

- **WHEN** the fake herdr accepts the first submission
- **THEN** the helper returns 0 with outcome `working`, after 1 submission, 0 Enter presses and 1 paste, and the fake herdr's log shows `agent wait --until idle` before `agent prompt`

#### Scenario: A lost prompt is submitted again

- **WHEN** the fake herdr loses the first submission (stall, nothing in the input)
- **THEN** the helper returns 0 with outcome `working`, after 2 submissions and 1 paste

#### Scenario: Text left in the input gets Enter, not a second paste

- **WHEN** the fake herdr leaves the text in the input after the submission and takes the first Enter
- **THEN** the helper returns 0 with outcome `working`, after 1 submission, 1 Enter press and 1 paste

#### Scenario: A second Enter when the first is not taken

- **WHEN** the fake herdr leaves the text in the input and takes only the second Enter
- **THEN** the helper returns 0 with outcome `working`, after 2 Enter presses and 1 paste

#### Scenario: Enter never taken

- **WHEN** the fake herdr leaves the text in the input and never starts the agent
- **THEN** the helper returns non-zero with outcome `unsent`, after 1 submission, 2 Enter presses and 1 paste, and stderr holds the last screen lines

#### Scenario: Wrapped text is still found

- **WHEN** the fake herdr leaves the text in the input, wrapped at 10 columns so that words are cut
- **THEN** the helper presses Enter and does not paste a second time

#### Scenario: Lost every time

- **WHEN** the fake herdr loses every submission
- **THEN** the helper returns non-zero with outcome `lost`, after 3 submissions, 0 Enter presses and 0 pastes

#### Scenario: Blocked agent

- **WHEN** the fake herdr answers `agent_blocked` to the submission
- **THEN** the helper returns non-zero with outcome `blocked`, after 1 submission, with no Enter press and 0 pastes

#### Scenario: Stall reported for an agent that took the prompt

- **WHEN** the fake herdr answers `timeout` while the agent's status is `working`, or `agent_prompt_stalled` while its status is `done`
- **THEN** the helper returns 0 with outcome `working` and 1 paste

#### Scenario: Unreadable screen

- **WHEN** the fake herdr stalls and `agent read` fails
- **THEN** the helper returns non-zero with outcome `unreadable`, with no Enter press and no second submission

#### Scenario: Failed idle wait is not fatal

- **WHEN** the fake herdr fails the idle wait and accepts the submission
- **THEN** the helper returns 0 with outcome `working`

### Requirement: Callers report the delivery outcome

`scm:worktree:new --json` SHALL print exactly one line holding one JSON object with `path`, `branch`, `name`, `tab`, `pane`, `agent` and `prompt`, where `prompt` is the helper's outcome, or `none` when no prompt was sent.
When the prompt is not delivered, `scm:worktree:new` SHALL still exit 0 and SHALL warn with the next step for the outcome.
`agent:dispatch` SHALL exit 1 when the prompt is not delivered, with the next step for the outcome, and `agent:dispatch --json` SHALL print one line.

#### Scenario: No prompt

- **WHEN** `mise run scm:worktree:new feat/j --json` runs in a scratch repository
- **THEN** its stdout is one line, and `jq -r .prompt` on it prints `none`

#### Scenario: Prompt through a new tab

- **WHEN** `mise run scm:worktree:new feat/k --tab --workspace w --agent-kind opencode --prompt "<text> @AGENTS.md" --json` runs with the fake herdr leaving the text in the input and taking the first Enter
- **THEN** its stdout is one line, `jq -r .prompt` prints `working`, and the fake herdr counted 1 paste

#### Scenario: Dispatch with the text stuck in the input

- **WHEN** `mise run agent:dispatch` runs with the fake herdr leaving the text in the input and never starting the agent
- **THEN** it exits 1 after 1 paste, and its message tells to press Enter in the agent's tab and does not tell to send the prompt again

### Requirement: herdr calls are bounded

Every herdr call of `scm_prompt_agent` SHALL run under a timeout: the call's own wait plus 10 s, or 15 s for calls that do not wait.
A call that times out SHALL count as failed with the code `timeout`.

#### Scenario: A hung screen read

- **WHEN** the fake herdr stalls the submission and `agent read` hangs, with the read timeout set to 2 s by the harness
- **THEN** the helper returns non-zero with outcome `unreadable` within 10 s, after 1 paste

### Requirement: Prompt help warns about file references

The help of `scm:worktree:new --prompt` SHALL say that a text ending in a file reference such as `@file` opens the TUI's autocomplete, which may swallow the Enter.

#### Scenario: Help text

- **WHEN** `mise run scm:worktree:new --help` runs
- **THEN** its output contains `@file`

### Requirement: Delivery harness is kept in the repository

The repository SHALL keep the harness `tests/global-mise-tasks/prompt-delivery.sh` and the fake herdr.
The harness SHALL exit 0 only when every delivery scenario passes, and SHALL NOT be a chezmoi target.

#### Scenario: Harness passes

- **WHEN** `tests/global-mise-tasks/prompt-delivery.sh` runs at the repository root
- **THEN** it exits 0, prints one result line per scenario, and leaves nothing under `/tmp/opencode/` (`test ! -e` on its scratch directory)

#### Scenario: Not a target

- **WHEN** `chezmoi managed` runs
- **THEN** no line starts with `tests`

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
