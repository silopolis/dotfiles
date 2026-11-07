## Why

The harness is only worth having if it runs somewhere other than one laptop: a hosted CI runner catches regressions on every push and shows what a machine without any local history does.
The core change proves a Kali container boots on a hosted runner once, as a throwaway run; this change commits that workflow so that it keeps running, and makes it follow the target list so that it never drifts from it.
Source: split out of `add-machine-lifecycle-test-infra` on 2026-11-07; input for cem task `T-013` (CI pipelines).

## What Changes

- A workflow `.github/workflows/machine-smoke.yml`, run by `workflow_dispatch` and by pushes that touch `tests/machine/`, `home/dot_config/mise/tasks/sys/` or `home/`.
- Each run installs Incus with the setup task's source file (`--source zabbly-<channel>`), then runs the smoke stage on every target whose `ci` flag is true and on none whose flag is false.
- A matrix over the Zabbly channel: `lts-7.0`, the line Kali packages, is required; `stable` is informational and never fails the workflow, to show what is coming.
- The workflow uses no repository secret and holds nothing specific to one machine or user.

## Capabilities

### New Capabilities

- `machine-smoke-ci`: when and how the smoke stage runs on hosted runners, for which targets and which Incus channels.

### Modified Capabilities

None.

## Impact

- Depends on `add-machine-lifecycle-test-infra` (the harness and its targets), `add-incus-host-setup` (the task whose file the workflow runs) and, for VM targets, `add-kali-vm-target`.
- New file `.github/workflows/machine-smoke.yml`; the first push of it is a public action and needs the user's go.
- Hosted runners spend minutes; the `stable` leg doubles the cost for information only.
- cem `T-013` may replace it with the shared pipeline later.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
