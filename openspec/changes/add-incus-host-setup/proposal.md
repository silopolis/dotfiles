## Why

Incus is meant to run on the production desktop, laptop and server profiles and on the machines that test this repository, so it needs a reproducible, safe installation that is part of the dotfiles and not a hand-typed list of commands.
Installing it touches the system (apt, a daemon, a network bridge, a group that grants access to it), and some machines will already run an Incus configured by someone else, so the install must detect what exists and never change it.
The test harness (`add-machine-lifecycle-test-infra`) only needs Incus to be installed; this change is useful on its own, whatever the harness spike decides.
Source: split out of `add-machine-lifecycle-test-infra` on 2026-11-07; audit `docs/audits/2026-10-30-environment.md`, finding F24 (machine-specific assumptions) and section 5 (no full apply on the laptop).

## What Changes

- A global mise task `sys:virt:incus:setup` (alias `sys:setup:virt:incus`), deployed with the other global tasks, that
  - reports every Incus it finds (clients and their source, package and its apt origin, daemon, LXD, storage pools, managed networks, group membership, Docker) and never installs over, upgrades, switches or re-initialises an existing one;
  - on a bare host installs the apt package, from the distribution or from the Zabbly repository on the releases it supports, initialises it with a storage driver that follows the filesystem (btrfs or dir), and adds the user to the restricted `incus` group;
  - offers `--check`, `--dry-run` and `--json`, and never calls `sudo` in the first two.
- Acceptance on the laptop, with the user's go: check, dry run, then the real install through the task, then two live checks that decide the defaults: guests reach the network while Docker runs, and a user in the restricted `incus` group (not `incus-admin`) can launch a container and a VM, snapshot and restore them.
- Tests of the task with stub commands, so that no real system is touched.

## Capabilities

### New Capabilities

- `incus-host-setup`: how Incus is detected, installed and initialised on a host, and what is guaranteed for an Incus that already exists.

### Modified Capabilities

- `global-mise-tasks`: the setup task is deployed and listed with its alias.

## Impact

- New deployed file `home/dot_config/mise/tasks/sys/virt/incus/executable_setup`, and tests under `tests/global-mise-tasks/` (not a chezmoi target).
- New host dependency; installing it uses sudo and writes outside `$HOME` (apt packages, for the Zabbly source the key and `.sources` file under `/etc/apt`, the group database); on the laptop it needs the user's go, check and dry run first.
- The restricted `incus` group is the default because `incus-admin` is root-equivalent, like the `docker` group.
- `global-mise-tasks` gains a requirement; `add-repo-roadmap` and `add-agent-launch-tasks` modify other requirements of the same spec, so archive order matters.
- The opt-in flag and the chezmoi hook are the separate change `add-incus-setup-hook`, which depends on this one.
- brew's `incus` client and the brew libvirt are handled by `remove-brew-libvirt`, done first so that the `incus` and `virsh` on `PATH` are the system ones.
- Input for `add-machine-lifecycle-test-infra` (its guests run on this Incus) and for the production profiles (`fresh-machine-bootstrap`, cem task `T-012`).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
