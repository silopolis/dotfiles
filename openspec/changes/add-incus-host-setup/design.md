## Context

- Production desktop, laptop and server profiles are meant to get Incus (user, 2026-11-07), and the machines that test this repository run it too; the setup is production-grade tooling deployed with the dotfiles, not test code.
- A global mise task is the deployed form: `adopt-global-mise-tasks` deploys `~/.config/mise/tasks`, so every machine that has the dotfiles has the task, and CI runs the same file from its checkout.
- Host on 2026-11-07: Kali rolling, `/` on btrfs (subvolume `@`), KVM available, Docker and VirtualBox installed, 15 GB RAM with about 5 GB free in normal use; no Incus, LXD, snap, `/var/lib/incus` or Incus group; `incus` 7.0.1 is the Kali apt candidate.
- The `virsh` first on `PATH` comes from brew (change `remove-brew-libvirt` removes it); brew's `incus` (7.6) is the command-line client only, and the mise registry has no `incus`.
- Incus packaging, checked on 2026-11-07:
  - `incus` from apt depends on `qemu-system-x86`, `swtpm`, `virtiofsd` and `incus-agent` (`incus-base` alone is container-only).
  - Debian and Ubuntu package the LTS releases (Incus documentation); versions seen: Kali apt 7.0.1, Ubuntu 24.04 6.0.0, Ubuntu 26.04 6.0.5.
  - The Zabbly repository (the maintainer's own) offers `lts-6.0`, `lts-7.0`, `stable` and `daily` for Debian 12 and 13 and Ubuntu 22.04, 24.04 and 26.04 LTS.
  - Its Debian 13 `incus-base` depends on `libgpgme11t64` and `libnet1`, which Kali rolling no longer has (it has `libgpgme45` and `libnet9`), so it does not install on Kali.
  - Zabbly will not package Debian forky before its pre-release freeze (zabbly/incus#119, closed as not planned, "likely early 2027") nor non-LTS Ubuntu (zabbly/incus#101).
- Access, from the Incus documentation: `incus-admin` gives full access and is root-equivalent; `incus` gives access through a per-user socket to a confined project created for that user.
- Storage: `incus admin init --minimal` creates a `dir` pool, which the documentation calls slow, with no fast snapshots; `zfs` and `btrfs` are the recommended drivers; a preseed that conflicts with existing state rolls itself back.
- mise, checked on 2026.10.23 (installed): a task can have a list of aliases and pattern runs match aliases (`mise run -n 'scm:wt:l*'` finds `scm:worktree:ls`); `--tag` runs are documented for newer versions (2026.11.3 is available).
- Docker's firewall rules are the known clash with the Incus bridge (Incus documentation, firewall section).

## Goals / Non-Goals

**Goals:**

- One deployed task that reports what exists, never changes an existing Incus, and installs and initialises a bare host.
- Defaults that are safe: restricted group, storage driver that follows the filesystem, no change without a go.
- Acceptance on the laptop that decides the defaults before the change is archived.
- Tests with stub commands, so the logic is proved without touching a system.

**Non-Goals:**

- The chezmoi hook and the opt-in flag (change `add-incus-setup-hook`).
- The test harness and its guests (changes `add-machine-lifecycle-test-infra`, `add-kali-vm-target`).
- Removing brew's libvirt and banning brew's `incus` (change `remove-brew-libvirt`).
- Turning Incus on by default for the production profiles (`fresh-machine-bootstrap`, cem `T-012`).
- Managing Incus afterwards: projects, profiles, images, upgrades.
- RPM-based distributions (much later).

## Decisions

### One deployed task

- Name: `sys:virt:incus:setup` in `home/dot_config/mise/tasks/sys/virt/incus/executable_setup`.
  The `sys` domain is for host setup, `virt` gathers virtualization and containerization (room for `sys:virt:libvirt:*` and `sys:virt:podman:*` later), `incus` is the tool, `setup` the action; it follows the domain, object, action order of `scm:worktree:new`.
- Alias: `sys:setup:virt:incus`, action first, so that `mise tasks ls | grep sys:setup:` lists every setup and `mise run 'sys:setup:*'` runs them all.
  No third name.
- Tags `setup` and `virt` are added when the mise on the machines accepts them (`--tag` needs a version newer than 2026.10.23; checked in the tasks).
- A shell script, as the `global-mise-tasks` spec requires of deployed tasks (`shellcheck -x`); it uses `jq` only where the report is built, and says so when `jq` is missing.
- Options: `--check` (changes nothing, never calls `sudo`, exits 0 when the host is ready and 1 when not), `--dry-run` (prints each step it would take, never calls `sudo`), `--json` (the report as one JSON object), `--source distro|zabbly-lts-7.0|zabbly-stable` (default `distro`), `--min-version <x.y>` (default `7.0`), `--group incus|incus-admin` (default `incus`), `--add-user`.
- Nothing is written outside the steps below.

### What it detects

Every mode first prints the same report, and the real run acts only on it:

- Every `incus` on `PATH`: path, version and where it comes from (apt package, brew, mise, other); a client that is not `/usr/bin/incus` is flagged as shadowing.
- The apt package: installed version and its origin (distribution archive, Zabbly repository, or none for a manual build).
- The daemon: systemd unit state and the server version from `incus info`.
- LXD: package, snap or `/var/lib/lxd` (it can clash with Incus on bridges and networks).
- Initialisation state: storage pools with their drivers, managed networks, the default profile's devices.
- Access: the invoking user's membership in the `incus` and `incus-admin` groups, in the group database and in the current session (a new login or `newgrp` is needed after a change).
- Docker: present or not, for the firewall note.

### What it does

Each step runs only when needed, in this order:

1. Distribution guard: the Debian family only (RPM-based distributions come much later); any other system exits 2 with no change.
   `--source zabbly-*` is further limited to the releases Zabbly lists (Debian 12 and 13, Ubuntu 22.04, 24.04 and 26.04); Kali and non-LTS Ubuntu exit 2 with no change.
2. Source: for a `zabbly-*` source, fetch the repository key, check its fingerprint against the one published by Zabbly before trusting it, and write the key and the channel's `.sources` file only when they differ.
3. Package: `apt-get install incus` when no Incus package or client is present.
4. Initialisation: `incus admin init --preseed` only when the daemon is installed and has no storage pool and no managed network.
   The preseed uses the `btrfs` driver when `/var/lib/incus` is on btrfs and `dir` otherwise, and names the pool `default`; it never uses `--minimal`, which would pick `dir` on the laptop.
5. Access: add the invoking user to the `incus` group (to `incus-admin` only with `--group incus-admin`, the fallback if acceptance shows the restricted group is not enough), and say that a new session is needed.

### Policy for an Incus that already exists

- Whatever its source, an existing Incus is reported and never installed over, upgraded, downgraded or switched to another source.
- Below the minimum version, `--check` exits 1 and a real run exits 1 without any change.
- An installed daemon with no storage pool and no managed network is initialised (step 4); any pool or managed network means it is never initialised again.
- Group membership is added only when this run installed or initialised Incus, or with `--add-user`; on an Incus configured by someone else the report says what is missing and stops.
- Nothing ever modifies, cleans or deletes a storage pool, network, profile, project or instance.

### Callers

- By hand: `mise run sys:virt:incus:setup --check`, then `--dry-run`, then for real.
- The harness: when its engine is missing or unreachable, its error says to run `mise run sys:virt:incus:setup`.
- CI: runs the file from the checkout (`bash home/dot_config/mise/tasks/sys/virt/incus/executable_setup --source zabbly-<channel>`), because mise and chezmoi are not set up there.
- chezmoi: the change `add-incus-setup-hook`, once `make-install-scripts-idempotent` and `fix-chezmoi-config-template` are archived.

### Tests

The task is a deployed global task, so its tests follow the convention of the other global tasks and not the harness's `uv` project: the standard library only, `tests/global-mise-tasks/test_incus_setup.py` with stub commands in `tests/global-mise-tasks/incus_stubs/`, run by `python3 -m unittest discover -s tests/global-mise-tasks`.
Each stub appends its command line to one log file, `sudo` also saves its standard input, and each stub answers from a scratch state file under `/tmp/opencode`; the scenarios of the spec check the log.

### Alternatives considered

- A chezmoi script alone: CI needs its own routine, it waits for `make-install-scripts-idempotent`, and a new machine would only get Incus on a full apply.
- A harness task or a script under `tests/`: a restored or new production machine would not get Incus unless someone ran it, and a chezmoi template cannot hash a file outside the source directory.
- A `~/.local/sbin` script: not a mise task, so no listing, alias or tags.
- `incus admin init --minimal`: picks the slow `dir` driver.

## Risks / Trade-offs

- [Risk] Installing Incus uses sudo and writes outside `$HOME` (`apt-get install incus`, the access group, the preseed, and for Zabbly the key and `.sources` file under `/etc/apt`). → The task checks before each step and skips what is done; `--check` and `--dry-run` never call `sudo`; the key fingerprint is verified before it is trusted; on the laptop only with the user's go.
- [Risk] The task acts on a machine that already runs Incus, possibly with its own pool, network and instances. → It reports and never installs over, upgrades, switches source, re-initialises or modifies anything; below the minimum version it refuses; group membership is added only with `--add-user` on such a host.
- [Risk] The `incus-admin` group is root-equivalent on the host, like the `docker` group. → The default is the restricted `incus` group; the admin group only with `--group incus-admin`, and only if acceptance shows it is needed.
- [Risk] A restricted project may forbid VMs, image import or snapshots. → Acceptance check on the laptop before archive; the fallback is the admin group, and the finding is recorded here.
- [Risk] Docker's firewall rules drop forwarded traffic from the Incus bridge, so guests have no network. → Acceptance check first; if it fails, the fix from the Incus documentation becomes a step of the task.
- [Risk] brew's `incus` client shadows the apt one. → The report flags it; the ban is in `remove-brew-libvirt`; the long-term fix (a mise-managed client on the daemon's release line) is in the `TODO.md` backlog.
- [Risk] A btrfs pool may behave differently on the laptop's layout (a subvolume of `@`). → Acceptance records which kind of pool Incus creates and whether snapshots are fast; `dir` stays the fallback.
- [Risk] Kali's apt Incus (7.0 LTS) and a Zabbly `lts-7.0` install elsewhere can drift apart. → Same release line; the minimum version is 7.0.
- [Trade-off] The task is larger than a plain `apt install` (detection, sources, preseed), in exchange for being safe on machines where Incus already exists.

## Migration Plan

1. `remove-brew-libvirt` first, so that the `virsh` and `incus` on `PATH` are the system ones.
2. Write the task and its tests with stub commands; deploy the task alone (`chezmoi apply --exclude=scripts ~/.config/mise/tasks/sys`).
3. With the user's go, on the laptop: `mise run sys:virt:incus:setup --check`, `--dry-run`, then the real run; log out and in, or use `newgrp incus`, for the group.
4. Acceptance on the laptop with generic catalog images (`images:debian/trixie/cloud`, no Kali import needed):
   1. a guest reaches the network while Docker runs;
   2. as a user in the `incus` group and not in `incus-admin`: launch a container and a VM, `incus exec`, snapshot and restore;
   3. record the kind of pool Incus created (`incus storage list`), and the time of a snapshot.
5. Adjust the defaults in this design and the spec if a check fails, then archive.

Rollback: delete the guests of the acceptance checks, and with the user's go `apt remove incus` and removal from the access group; the repository files go with a `git revert`.

## Open Questions

- Does the `btrfs` driver on the laptop use a host subvolume or a loop file, and are snapshots and VMs fast enough on it?
- Does Debian's `incus` package enable the user socket for the restricted group, and may a restricted project create VMs and take snapshots?
- Does the mise installed on the machines accept `tags` in a task header, or is an upgrade needed first?
- Which profiles turn Incus on by default, and does the server profile need another group policy (`fresh-machine-bootstrap`, cem `T-012`)?

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
