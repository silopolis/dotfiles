## Context

- The setup task (`add-incus-host-setup`) is a shell script that runs from a checkout with `--source zabbly-lts-7.0|zabbly-stable` on Ubuntu LTS runners; mise and chezmoi are not set up on a runner, so the workflow runs the file directly.
- Zabbly's repository offers `lts-7.0` and `stable` for Ubuntu 22.04, 24.04 and 26.04 LTS; Ubuntu's own `incus` package is on the 6.0 line (6.0.0 on 24.04, 6.0.5 on 26.04, seen 2026-11-07), while Kali packages 7.0.1.
- GitHub-hosted Linux runners expose KVM to the runner user after a udev rule (GitHub changelog, 2024-04-02); containers need no KVM.
- `continue-on-error` on a matrix leg keeps its failure from failing the workflow.
- The core change's first group runs the same steps once, as a throwaway workflow on a branch or a fork; this change turns that into the committed workflow.

## Goals / Non-Goals

**Goals:**

- Every push that touches the harness or the setup task runs the smoke stage on the hosted runner.
- The set of targets follows the target list's `ci` flags without a second list.
- A difference between the laptop's Incus line and the newest one is visible without failing anything.

**Non-Goals:**

- Lifecycle stages beyond smoke (each stage change adds its own job when it is worth the minutes).
- The shared pipeline of cem (`T-013`).
- Caching of images across runs, until the minutes become a problem.

## Decisions

### One workflow, a channel matrix

- Triggers: `workflow_dispatch` and pushes that touch `tests/machine/`, `home/dot_config/mise/tasks/sys/` or `home/`.
- Matrix `channel: [lts-7.0, stable]`; the `stable` leg has `continue-on-error: true` and is the only leg that has it.
- Each leg: check out, run `bash home/dot_config/mise/tasks/sys/virt/incus/executable_setup --source zabbly-<channel>`, install the harness (`mise`, `uv`), then `mise run machine:run <target> smoke` for each container target with `ci = true`.
- A second job, for `vm` targets with `ci = true`, enables KVM for the runner user first; it exists only once `add-kali-vm-target` has a target marked `ci = true`.

### Targets follow the list

The job reads the targets from `mise run machine:list --json | jq -r '.[] | select(.ci) | .name'` instead of naming them, so adding a target with `ci = true` adds a job step without editing the workflow, and a target with `ci = false` is never run.

### No secret, nothing personal

The workflow references no `secrets.` context and no user name or home path; the harness never copies key material into a guest, so a fork's runs behave the same.

## Risks / Trade-offs

- [Risk] The first push of the workflow publishes to the public repository. → Only with the user's go.
- [Risk] A runner lacks disk or time for a target. → The target's `ci` flag is set to `false` and the target list says why.
- [Risk] The `stable` leg breaks on a new Incus release and is ignored. → It is informational on purpose; a failing `stable` with a passing `lts-7.0` is read as a heads-up, not a defect.
- [Risk] Zabbly's repository or key changes. → The setup task verifies the key fingerprint and fails closed; the failure shows in the run.
- [Trade-off] Hosted-runner minutes in exchange for a regression signal on every push.

## Migration Plan

1. After the core and the setup change are applied, with the core's throwaway run as the reference.
2. Write the workflow, check it with `yq` and a scratch run of its commands, then push it with the user's go.
3. Record the duration of a green run in this design.

Rollback: delete the workflow file; nothing else depends on it.

## Open Questions

- How long does a green run take on each channel, and is it worth caching the Kali image?
- Does the VM job need a larger runner, or does the standard one have enough disk for the 25 GiB image conversion?

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
