## ADDED Requirements

### Requirement: Every CI-capable target is proven on a hosted runner

The repository SHALL hold `.github/workflows/machine-smoke.yml`, triggered by `workflow_dispatch` and by pushes that touch `tests/machine/`, `home/dot_config/mise/tasks/sys/` or `home/`.
It SHALL run the setup task's source file with `--source zabbly-<channel>` before any `machine:run`, over a matrix of the channels `lts-7.0` and `stable`, and the `stable` leg SHALL NOT fail the workflow.
It SHALL run `machine:run <target> smoke` for every target with `ci = true` and for no target with `ci = false`.

#### Scenario: Triggers

- **WHEN** `yq -r '.on | keys | .[]' .github/workflows/machine-smoke.yml` runs
- **THEN** its output holds `push` and `workflow_dispatch`

#### Scenario: Path filters

- **WHEN** `yq -r '.on.push.paths[]' .github/workflows/machine-smoke.yml` runs
- **THEN** its output holds `tests/machine/**`, `home/dot_config/mise/tasks/sys/**` and `home/**`

#### Scenario: Channels

- **WHEN** `yq -r '[.jobs[].strategy.matrix.channel[]] | unique | .[]' .github/workflows/machine-smoke.yml` runs
- **THEN** its output is `lts-7.0` and `stable`

#### Scenario: Stable is informational

- **WHEN** `rg -n 'continue-on-error' .github/workflows/machine-smoke.yml` runs
- **THEN** every match names the `stable` channel

#### Scenario: Setup comes first

- **WHEN** `rg -n -e 'executable_setup' -e 'machine:run' .github/workflows/machine-smoke.yml | head -1` runs
- **THEN** the first line printed holds `executable_setup`

#### Scenario: Targets come from the list

- **WHEN** `rg -c 'machine:list --json' .github/workflows/machine-smoke.yml` runs
- **THEN** it prints at least 1, and no target name from `mise run machine:list --json | jq -r '.[].name'` appears in a `machine:run` line of the workflow

#### Scenario: Last hosted run passed

- **WHEN** `gh run list --workflow machine-smoke.yml --limit 1 --json conclusion --jq '.[0].conclusion'` runs after the first push of the workflow
- **THEN** it prints `success`

### Requirement: The workflow holds no secret and nothing personal

The workflow SHALL NOT reference a repository secret, and SHALL hold no home path, user name, host name or credential, since it ships in a public repository.

#### Scenario: Workflow uses no secret

- **WHEN** `rg -n 'secrets\.' .github/workflows/machine-smoke.yml` runs
- **THEN** it prints nothing

#### Scenario: Nothing machine-specific

- **WHEN** `rg -n -e "$HOME" -e "$USER" .github/workflows/machine-smoke.yml` runs
- **THEN** it prints nothing

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
