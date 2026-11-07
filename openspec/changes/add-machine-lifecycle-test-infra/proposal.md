## Why

The repository is only proven on machines that already went through it: nothing shows that a clean machine reaches a working environment, that a second apply changes nothing, or that an older machine updates cleanly.
cem will provision, update and restore machines on top of this layer, and the changes under way (`fresh-machine-bootstrap`, `make-install-scripts-idempotent`) each need a disposable machine to prove their result; the bootstrap findings F24 to F26 (audit `docs/audits/2026-10-30-environment.md`, section 4) cannot be closed on the laptop itself, where a full apply is forbidden (section 5).
This change is the core of the test infrastructure: disposable system containers driven by one interface, on top of an Incus installed by `add-incus-host-setup`.
Virtual machines, the committed CI workflow and the Incus installation are separate changes (below), so that each stays small enough to review and apply on its own.

## What Changes

- A test infrastructure at the repository root (outside `home/`) that creates disposable guests, gives them this repository at a chosen commit, runs a lifecycle stage in them and destroys them; here the guests are Kali system containers.
- The engine is chosen in the design from a comparison of Incus, Vagrant with libvirt, OCI containers (podman or docker) and plain libvirt with cloud-init, against the same criteria (CI runners, both guest kinds from one tool, distro catalog, snapshots, cloud-init, setup cost on the laptop); Incus is the lead, confirmed here by a throwaway run of a Kali container on a hosted CI runner.
- A target list: distro, image, guest kind, CI support, and optional instance options; the first entry is `kali-container`.
  It also has room for virtual machines, OCI images and existing machines reached over SSH: the file may name them, every command that would need them exits 2 with "not implemented yet", and the changes that implement them lift that.
- mise tasks as the single entry point: bring a guest up, run a stage, snapshot and restore, tear down.
- Isolation: guests live in a harness project and carry a marker key, and only marked guests are ever deleted; a user confined to the restricted `incus` group works in their own project.
- Guests run as a user unlike the host's, provisioned by cloud-init; the repository reaches them as a git bundle of a chosen commit.
- Secret handling: the real age identity never enters a guest; stages run with encrypted targets excluded.
- A stage contract and a smoke stage that proves the plumbing without applying anything.
- Python tooling that follows cem's stack (Typer with Rich, pytest, uv with a lock file), because it is repository tooling and is not deployed.
- Inside a guest, full applies and scripts are allowed; the rule against a full apply on the laptop is unchanged.

### Split into other changes

- `add-incus-host-setup`: the deployed task that detects, installs and initialises Incus (production tooling), with the acceptance checks on the laptop that decide its defaults.
- `add-incus-setup-hook`: the opt-in flag and the chezmoi hook that run that task.
- `add-kali-vm-target`: the `vm` kind, importing the Kali cloud image, and the `kali-vm` target.
- `add-machine-smoke-ci`: the committed workflow, with the matrix over Zabbly channels.

### Follow-up changes

Each stage and each distro is its own change; their order and status live in the checklist of `TODO.md` and later in `add-repo-roadmap`.

- Production profiles: desktop, laptop and server profiles get Incus by default through profile data (`fresh-machine-bootstrap` and cem task `T-012`).
- Stages: fresh bootstrap (owned by `fresh-machine-bootstrap`), second apply is a no-op (after `make-install-scripts-idempotent`), update from an older commit to HEAD, rollback to the previous commit, purge and teardown.
- Distros: Omarchy (Arch with the Omarchy installer), Debian stable, Ubuntu stable, Ubuntu LTS, Arch Linux; RPM-based distros (Fedora, AlmaLinux) much later.
- Kali VM images of our own: `support-kali-vm-uefi`, then `support-kali-vm-secure-boot`.
- Targets: development containers (devcontainers, DevPod) applying these dotfiles, with OCI images as machines (needs an image of our own and the rule that OCI references are pinned); real machines reached over SSH (`kind = host`, with cem, with the rule that the harness never creates, resets or deletes one); OCI images as virtual machines once Incus supports them (`lxc/incus#1360`); CI pipelines (cem task `T-013`).
- Upstream: Zabbly packages for Debian testing are refused until the forky freeze (`zabbly/incus#119`, likely early 2027): revisit then.
- `remove-brew-libvirt`: brew's `libvirt` and `incus` client must not shadow the system ones; done before Incus is installed.
- Backlog in `TODO.md`: a mise-managed Incus client on the daemon's release line (`github:lxc/incus`).

## Capabilities

### New Capabilities

- `machine-test-harness`: how disposable guests are described, created, fed the repository, run a lifecycle stage and destroyed, without the real secrets.

### Modified Capabilities

None.

## Impact

- New root-level files: target list, guest provisioning (a cloud-init snippet), stage scripts under `tests/machine/`, mise tasks in `mise.toml`.
- Depends on `add-incus-host-setup` having installed and initialised Incus (and on `remove-brew-libvirt` before it).
- Hypervisors: once `add-kali-vm-target` adds KVM-based virtual machines, they and VirtualBox cannot run at the same time on the laptop.
- `fresh-machine-bootstrap` uses this infrastructure for its container test (its tasks 4.3 and 5.1) instead of defining its own.
- Input for cem tasks `T-012` (profiles per target) and `T-013` (CI pipelines).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
