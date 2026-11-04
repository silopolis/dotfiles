## MODIFIED Requirements

### Requirement: Dispatching an agent

`agent:dispatch` SHALL refuse an agent name that does not match `[a-z][a-z0-9_-]{0,31}`, a brief path that is not absolute or does not exist, a missing target directory, and an existing agent name; it SHALL open the workspace of the target directory by the rules of `workspace:open` and deliver the first prompt through the launch library; it SHALL exit 1 when the prompt is not delivered, with the next step for the outcome; and when the agent cannot start, it SHALL close the tab it created.

#### Scenario: Relative brief is refused

- **WHEN** `mise run agent:dispatch --workspace x --cwd /tmp --name test-agent --brief brief.md` runs
- **THEN** it exits 1 with an error saying the brief must be an absolute path, and no herdr tab is created

#### Scenario: Dispatch with the text stuck in the input

- **WHEN** `mise run agent:dispatch` runs with the fake herdr leaving the text in the input and never starting the agent
- **THEN** it exits 1 after 1 paste, and its message tells to press Enter in the agent's tab and does not tell to send the prompt again

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
