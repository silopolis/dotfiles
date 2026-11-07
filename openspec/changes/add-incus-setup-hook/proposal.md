## Why

`add-incus-host-setup` gives every machine a task that installs and initialises Incus safely, but nothing runs it on its own: a restored or new machine only gets Incus when someone remembers to run the task.
Production desktop, laptop and server profiles are meant to have Incus, so chezmoi needs to run the task on the machines that opt in, and to do nothing elsewhere.
This is split from the setup change because it depends on two changes that come earlier in the audit's order (`make-install-scripts-idempotent`, `fix-chezmoi-config-template`), and keeping it separate lets the setup change be archived as soon as the laptop is set up.
Source: split out of `add-machine-lifecycle-test-infra` on 2026-11-07; audit `docs/audits/2026-10-30-environment.md`, section 5 (no full apply before the install scripts are idempotent).

## What Changes

- A data flag `features.incus`, default `false`, in a new `home/.chezmoidata/features.yaml`; a machine opts in through its own chezmoi data, which `fix-chezmoi-config-template` records at `chezmoi init` (`promptBoolOnce`, default no).
- A chezmoi after-script `home/.chezmoiscripts/run_onchange_after_15-incus.sh.tmpl` that renders empty while the flag is false, so it is not a pending script, and runs the deployed task `sys:virt:incus:setup` when the flag is true; it re-runs when the task's content changes.
- The hook never adds users to groups and never picks the admin group: it runs the task with its own defaults.

## Capabilities

### New Capabilities

- `incus-setup-hook`: when chezmoi runs the Incus setup task, and what it never does.

### Modified Capabilities

None.

## Impact

- Depends on `add-incus-host-setup` (the task), `fix-chezmoi-config-template` (the flag prompt, and the config that carries the flag) and `make-install-scripts-idempotent` (the script conventions, numbering and dry-run mode, and the rule that no full apply happens before it is archived).
- New files `home/.chezmoidata/features.yaml` and `home/.chezmoiscripts/run_onchange_after_15-incus.sh.tmpl`.
- The first apply on a machine that opted in runs `sudo` through the task; the task is a no-op when the host is ready, and the review rule of `AGENTS.md` (a reviewed dry run before an apply) applies.
- Turning the flag on by default for the production profiles is a later change with profile data (`fresh-machine-bootstrap`, cem task `T-012`).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
