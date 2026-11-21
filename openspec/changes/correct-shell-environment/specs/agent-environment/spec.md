## MODIFIED Requirements

### Requirement: A herdr-started agent holds none of them

An agent that herdr starts in a pane SHALL hold no secret-named variable, including when the shell of the pane has loaded the private environment file with `secrets load`.

#### Scenario: Live agent process

- **WHEN** a new tab is created in the workspace, `secrets load` is typed in the shell of its pane, `herdr agent start probe --kind opencode --pane <its pane>` runs after the target is deployed, and the count `tr '\0' '\n' < /proc/<pid>/environ | cut -d= -f1 | grep -Ec '<pattern>'` runs with the pid from `herdr pane process-info --pane <its pane>`
- **THEN** the count is `0`, and the same count for the shell of that pane is greater than `0` while the environment file sets variables

#### Scenario: opencode still works

- **WHEN** the same agent is running
- **THEN** `herdr agent get probe` reports it idle or working, `opencode models anthropic` run through the function prints at least one model id, and `opencode auth list` shows the stored providers

#### Scenario: The probe tab is removed

- **WHEN** the check is done and `herdr tab close <tab id>` runs
- **THEN** `herdr tab list --workspace <id>` shows only the tabs that existed before

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
