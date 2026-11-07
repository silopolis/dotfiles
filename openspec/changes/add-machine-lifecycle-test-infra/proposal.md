## Why

The repository is only proven on machines that already went through it: nothing shows that a clean machine reaches a working environment, that a second apply changes nothing, or that an older machine updates cleanly.
cem will provision, update and restore machines on top of this layer, and the changes under way (`fresh-machine-bootstrap`, `make-install-scripts-idempotent`) each need a disposable machine to prove their result; the bootstrap findings F24 to F26 (audit `docs/audits/2026-10-30-environment.md`, section 4) cannot be closed on the laptop itself, where a full apply is forbidden (section 5).

## What Changes

- A test infrastructure at the repository root (outside `home/`) that creates disposable guests, gives them this repository at a chosen commit, runs a lifecycle stage in them and destroys them.
- Two guest kinds behind one interface: system containers (fast, real init and sudo) and virtual machines (full machine, login shells, desktop later).
- A target list that also has room for OCI images (as system containers, if a spike shows an OCI image can run as a full machine) and for existing machines reached over SSH, without implementing either yet.
- The engine is chosen in the design from a comparison of Incus, Vagrant with libvirt, OCI containers (podman or docker) and plain libvirt with cloud-init, against the same criteria (CI runners, both guest kinds from one tool, distro catalog, snapshots, cloud-init, setup cost on the laptop); Incus is the lead, to be confirmed by a spike.
- Python tooling that follows cem's stack (Typer with Rich, pytest, uv with a lock file), because it is repository tooling and is not deployed.
- Every guest kind used by the infrastructure also runs on a hosted CI runner; a target that cannot is marked local-only in the target list.
- A target list: distro, image, guest kind, CI support; the first entries are Kali Rolling as a container and as a virtual machine.
- mise tasks as the single entry point: bring a guest up, run a stage, snapshot and restore, tear down.
- Secret handling: the real age identity never enters a guest; stages run with encrypted targets excluded or with a throwaway test identity.
- A smoke stage that proves the plumbing without applying anything: the guest boots, the repository is present at the requested commit, and `chezmoi source-path` ends with `/home`.
- Inside a guest, full applies and scripts are allowed; the rule against a full apply on the laptop is unchanged.

### Follow-up changes

Each stage and each distro is its own change; their order and status live in `add-repo-roadmap`.

- Stages: fresh bootstrap (owned by `fresh-machine-bootstrap`), second apply is a no-op (after `make-install-scripts-idempotent`), update from an older commit to HEAD, rollback to the previous commit, purge and teardown.
- Distros: Omarchy (Arch with the Omarchy installer), Debian stable, Ubuntu stable, Ubuntu LTS, Arch Linux; RPM-based distros (Fedora, AlmaLinux) much later.
- Targets: development containers (devcontainers, DevPod) applying these dotfiles; real machines reached over SSH (`kind = host`, with cem); OCI images as virtual machines once Incus supports them (`lxc/incus#1360`); CI pipelines (cem task `T-013`).
- Separate small change: `remove-brew-libvirt` (brew's `libvirt` is an unused dependency whose `virsh` shadows the system one; remove it and forbid its return), done before the spike.

## Capabilities

### New Capabilities

- `machine-test-harness`: how disposable guests are described, created, fed the repository, run a lifecycle stage and destroyed, locally and on CI, without the real secrets.

### Modified Capabilities

None.

## Impact

- New root-level files: target list, guest provisioning (cloud-init or equivalent), stage scripts under `tests/`, mise tasks in `mise.toml`, optionally a CI workflow.
- New host dependency for the chosen engine; installing it on the laptop uses sudo and needs the user's go.
- Hypervisors: KVM-based virtual machines and VirtualBox cannot run at the same time on the laptop.
- `fresh-machine-bootstrap` uses this infrastructure for its container test (its tasks 4.3 and 5.1) instead of defining its own.
- Input for cem tasks `T-012` (profiles per target) and `T-013` (CI pipelines).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
