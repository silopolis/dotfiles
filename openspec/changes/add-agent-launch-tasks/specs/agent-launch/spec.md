## ADDED Requirements

In the scenarios below, "the fake herdr" is `tests/global-mise-tasks/fake_herdr.py`, a test double first on `PATH` that keeps its state in a scratch directory under `/tmp/opencode` and logs every call.
"Pastes" is the number of times it put the prompt text into the input box.
Direct cases call the library's delivery function with `sleep` replaced by a no-op and the text `Read and execute the brief at /tmp/opencode/brief.md` for an agent named `test-agent`.
Task scenarios run in a scratch git repository whose `origin` is a bare repository on branch `main`, both under `/tmp/opencode`, with `WORKTREES_ROOT` inside the same directory and `HERDR_ENV` unset.

### Requirement: First prompt is delivered once

The library's delivery function, used by `agent:launch`, `agent:dispatch` and `scm:worktree:new --prompt`, SHALL deliver the first prompt as follows:

- before the first submission, wait up to 15 s for the agent to be `idle`, where a failed wait is not fatal;
- then read the visible screen every second, up to 60 reads, until at least 5 lines hold something besides frame characters and whitespace, where a failed read counts as blank and a screen that never draws does not stop the submission; then pause 1 s;
- submit with `herdr agent prompt --wait --until working`;
- after any unconfirmed submission, inspect before doing anything else:
  - agent status `working` or `done` means delivered;
  - status `blocked` stops;
  - otherwise read the visible screen; the prompt is on screen when its first 24 non-whitespace characters appear in the screen text, with frame characters (U+2500 to U+259F) and all whitespace removed from both;
- while the prompt is on screen, press Enter at most twice and never submit the text again;
- submit again only when the prompt is not on screen, at most 5 submissions in all.

It SHALL return the outcome `working`, `unsent`, `lost`, `blocked` or `unreadable`; only `working` is a success.
Whenever it stops without delivery, it SHALL print the outcome and the last 15 non-blank lines of the screen on stderr.

#### Scenario: First submission works

- **WHEN** the fake herdr accepts the first submission
- **THEN** the outcome is `working`, after 1 submission, 0 Enter presses and 1 paste, and the fake herdr's log shows `agent wait --until idle`, then `agent read`, before `agent prompt`

#### Scenario: Waits for the TUI to draw

- **WHEN** the fake herdr shows a blank screen for the first 3 reads and loses any submission made while the screen is blank
- **THEN** the outcome is `working`, after 4 screen reads before the first submission, 1 submission and 1 paste

#### Scenario: Screen never draws

- **WHEN** the fake herdr keeps the screen blank and loses every submission
- **THEN** the function reads the screen 60 times before its first submission, submits anyway, and the outcome is `lost`, after 5 submissions and 0 pastes, and stderr says the screen never drew

#### Scenario: A lost prompt is submitted again

- **WHEN** the fake herdr loses the first submission (stall, nothing in the input)
- **THEN** the outcome is `working`, after 2 submissions and 1 paste

#### Scenario: Text left in the input gets Enter, not a second paste

- **WHEN** the fake herdr leaves the text in the input after the submission and takes the first Enter
- **THEN** the outcome is `working`, after 1 submission, 1 Enter press and 1 paste

#### Scenario: A second Enter when the first is not taken

- **WHEN** the fake herdr leaves the text in the input and takes only the second Enter
- **THEN** the outcome is `working`, after 2 Enter presses and 1 paste

#### Scenario: Enter never taken

- **WHEN** the fake herdr leaves the text in the input and never starts the agent
- **THEN** the outcome is `unsent`, after 1 submission, 2 Enter presses and 1 paste, and stderr holds the last screen lines

#### Scenario: Wrapped text is still found

- **WHEN** the fake herdr leaves the text in the input, wrapped at 10 columns so that words are cut
- **THEN** the function presses Enter and does not paste a second time

#### Scenario: Lost every time

- **WHEN** the fake herdr loses every submission while the screen is drawn
- **THEN** the outcome is `lost`, after 5 submissions, 0 Enter presses and 0 pastes

#### Scenario: Blocked agent

- **WHEN** the fake herdr answers `agent_blocked` to the submission
- **THEN** the outcome is `blocked`, after 1 submission, with no Enter press and 0 pastes

#### Scenario: Stall reported for an agent that took the prompt

- **WHEN** the fake herdr answers `timeout` while the agent's status is `working`, or `agent_prompt_stalled` while its status is `done`
- **THEN** the outcome is `working` and there was 1 paste

#### Scenario: Unreadable screen

- **WHEN** the fake herdr draws the screen, stalls the submission, and from then on fails `agent read`
- **THEN** the outcome is `unreadable`, with no Enter press and no second submission

#### Scenario: Failed idle wait is not fatal

- **WHEN** the fake herdr fails the idle wait and accepts the submission
- **THEN** the outcome is `working`

### Requirement: herdr calls are bounded

Every herdr call of the library SHALL run under a timeout: the call's own wait plus 10 s, or 15 s for calls that do not wait.
A call that times out SHALL count as failed with the code `timeout`.

#### Scenario: A hung screen read

- **WHEN** the fake herdr draws the screen, stalls the submission, and from then on hangs on `agent read`, with the read timeout set to 2 s by the test
- **THEN** the outcome is `unreadable` within 10 s, after 1 paste

### Requirement: A workspace is built out of a worktree

`workspace:open <branch|path>` SHALL find the worktree of the branch (or the given path) and the herdr workspaces open on that path, and SHALL end in one of: reuse the workspace open on the path; create a workspace with the path as its working directory and the worktree name as its label; refuse.
It SHALL refuse, creating nothing and naming what it found, when the branch exists with no checkout, when a workspace has the requested label with another path, when several workspaces are open on the path, or when the path is not a worktree of the repository.
It SHALL print one line holding one JSON object with `path`, `branch`, `workspace` and `action` (`reused` or `created`).

#### Scenario: Reuse

- **WHEN** a workspace is already open on the worktree of `feat/a` and `mise run workspace:open feat/a` runs
- **THEN** it exits 0 and prints one line, `jq -r .action` on it prints `reused`, and the fake herdr's log shows no workspace creation

#### Scenario: Create

- **WHEN** the worktree of `feat/b` has no workspace and `mise run workspace:open feat/b` runs
- **THEN** it exits 0, `jq -r .action` prints `created`, and the fake herdr's log shows one workspace creation with the worktree path as its working directory

#### Scenario: Same label, other path

- **WHEN** a workspace labelled like the worktree is open on another path
- **THEN** the task exits 1, its message names both paths, and the fake herdr's log shows no workspace creation

#### Scenario: Branch with no checkout

- **WHEN** the branch `feat/c` exists locally and is checked out nowhere, and `mise run workspace:open feat/c` runs
- **THEN** it exits 1, its message names the branch and says it has no checkout, and nothing is created

### Requirement: An agent is launched into a workspace

`agent:launch <branch>` SHALL create the worktree through `scm:worktree:new` when the branch is new, open its workspace as `workspace:open` does, start the agent (kind `opencode` by default, in plan mode unless told otherwise) in a pane of that workspace, deliver the first prompt as above, and print one line holding one JSON object with `path`, `branch`, `workspace`, `pane`, `agent`, `action` and `prompt`, where `prompt` is the delivery outcome or `none` when no prompt was given.
It SHALL exit 0 only when the agent was started and the prompt, if any, was delivered, and SHALL name the next step for each outcome that is not `working`.
It SHALL refuse before creating anything when the agent name does not match `[a-z][a-z0-9_-]{0,31}` or is taken.

#### Scenario: New branch end to end

- **WHEN** `mise run agent:launch feat/d --name test-agent --prompt "Read and execute the brief at /tmp/opencode/brief.md"` runs with the fake herdr accepting the first submission
- **THEN** it exits 0, prints one line, `jq -r .prompt` prints `working`, `git worktree list` shows the worktree on `feat/d`, the fake herdr's log shows one workspace creation, one `agent start` in plan mode and one paste

#### Scenario: Name taken

- **WHEN** the fake herdr already has an agent `test-agent` and `mise run agent:launch feat/e --name test-agent` runs
- **THEN** it exits 1, and `git worktree list` and `git branch --list feat/e` show nothing new

#### Scenario: Prompt not delivered

- **WHEN** the fake herdr leaves the text in the input and never starts the agent
- **THEN** the task exits 1 after 1 paste, `jq -r .prompt` on its stdout prints `unsent`, and its message tells to press Enter in the agent's pane and does not tell to send the prompt again

### Requirement: Callers report the delivery outcome

`scm:worktree:new --json` SHALL print exactly one line holding one JSON object with `path`, `branch`, `name`, `tab`, `pane`, `agent` and `prompt`, where `prompt` is the delivery outcome, or `none` when no prompt was sent.
When the prompt is not delivered, `scm:worktree:new` SHALL still exit 0 and SHALL warn with the next step for the outcome.
`agent:dispatch --json` SHALL print one line.

#### Scenario: No prompt

- **WHEN** `mise run scm:worktree:new feat/j --json` runs in a scratch repository
- **THEN** its stdout is one line, and `jq -r .prompt` on it prints `none`

#### Scenario: Prompt through a new tab

- **WHEN** `mise run scm:worktree:new feat/k --tab --workspace w --agent-kind opencode --prompt "<text> @AGENTS.md" --json` runs with the fake herdr leaving the text in the input and taking the first Enter
- **THEN** its stdout is one line, `jq -r .prompt` prints `working`, and the fake herdr counted 1 paste

### Requirement: Unknown workspace is refused before anything is created

`scm:worktree:new --tab` SHALL resolve `--workspace` (or `HERDR_WORKSPACE_ID`) before it creates the worktree, and SHALL name the value it was given when the workspace is not found or several workspaces share that label.

#### Scenario: Bad workspace

- **WHEN** `mise run scm:worktree:new feat/w --tab --workspace nope` runs in a scratch repository with the fake herdr, which knows no workspace `nope`
- **THEN** it exits 1, its message contains `herdr workspace 'nope' not found`, and `git worktree list` and `git branch --list feat/w` show nothing new

### Requirement: Prompt help warns about file references

The help of `scm:worktree:new --prompt`, `agent:launch --prompt` and `agent:dispatch` SHALL say that a text ending in a file reference such as `@file` opens the TUI's autocomplete, which may swallow the Enter.

#### Scenario: Help text

- **WHEN** `mise run scm:worktree:new --help`, `mise run agent:launch --help` and `mise run agent:dispatch --help` run
- **THEN** each output contains `@file`

### Requirement: Launch tasks are deployed and tested

The repository SHALL deploy `workspace:open` and `agent:launch` with the global tasks, and SHALL keep the fake herdr and the unit tests of the library in `tests/global-mise-tasks/`; the tests SHALL pass, SHALL leave nothing under `/tmp/opencode/`, and SHALL NOT be a chezmoi target.

#### Scenario: Tasks are listed

- **WHEN** `mise tasks ls --global` runs from a directory with no project config
- **THEN** it lists `workspace:open` and `agent:launch`

#### Scenario: Tests pass

- **WHEN** `python3 -m unittest discover -s tests/global-mise-tasks` runs at the repository root
- **THEN** it exits 0, and `test ! -e` on the tests' scratch directory under `/tmp/opencode` succeeds

#### Scenario: Not a target

- **WHEN** `chezmoi managed | grep -c '^tests'` runs
- **THEN** it prints 0

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
