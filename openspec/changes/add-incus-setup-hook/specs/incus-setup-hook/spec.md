## ADDED Requirements

### Requirement: Incus is an opt-in feature

`home/.chezmoidata/features.yaml` SHALL set `features.incus` to `false`, and a machine SHALL opt in through its own chezmoi data.
The chezmoi script `home/.chezmoiscripts/run_onchange_after_15-incus.sh.tmpl` SHALL render empty while the flag is false, so that it is not a pending script, and SHALL run the deployed task `~/.config/mise/tasks/sys/virt/incus/setup` when the flag is true, without `--add-user` and with the task's own defaults.
Scenarios use an empty scratch config file, a scratch destination and a scratch persistent state, so that the real ones are never read or written.

#### Scenario: Off by default

- **WHEN** `chezmoi --source <repository> --config <empty file> --persistent-state <scratch state> data --format=json | jq '.features.incus'` runs
- **THEN** it prints `false`

#### Scenario: Opt in through data

- **WHEN** the same command runs with `--override-data '{"features":{"incus":true}}'`
- **THEN** it prints `true`

#### Scenario: No pending script while off

- **WHEN** `chezmoi --source <repository> --config <empty file> --destination <scratch dir> --persistent-state <scratch state> status | grep -c incus` runs
- **THEN** it prints 0, and with `--override-data '{"features":{"incus":true}}'` it prints 1

#### Scenario: Rendered script is clean

- **WHEN** the template is rendered with the flag on (`chezmoi execute-template` with the same options and override) and piped to `shellcheck -s bash -`
- **THEN** shellcheck exits 0 and the rendered text names `.config/mise/tasks/sys/virt/incus/setup`

#### Scenario: The hook does not widen access

- **WHEN** the template is rendered with the flag on and the output is searched with `grep -c -e '--add-user' -e 'incus-admin' -e '--group'`
- **THEN** it prints 0

#### Scenario: A task change re-triggers the hook

- **WHEN** one line is appended to the task `home/dot_config/mise/tasks/sys/virt/incus/executable_setup` in a scratch clone and the template is rendered there before and after, flag on
- **THEN** the two renderings differ

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
