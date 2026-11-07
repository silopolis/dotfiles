## Context

- Nothing tests the repository on a clean machine; the only proof is the laptop, where a full `chezmoi apply` is forbidden until `make-install-scripts-idempotent` is archived.
- `fresh-machine-bootstrap` planned its own podman container test (its design, section "Container test"); with this change it keeps the bootstrap stage and its assertions, and uses this infrastructure to run them.
- Lifecycle stages come later, each as its own change: fresh bootstrap, second apply is a no-op, update from an older commit to HEAD, rollback to the previous commit, purge.
- Targets come later too, each as its own change: Kali Rolling and Omarchy first, then Debian stable, Ubuntu stable and LTS, Arch, much later RPM-based distros; development containers (devcontainers, DevPod) are a target of their own, and so may be real machines reached over SSH, with cem.
- Host on 2026-11-07:
  - KVM available (`/dev/kvm`); system `libvirtd` active, QEMU and `virt-install` installed.
  - The `virsh` first on `PATH` comes from brew and looks for brew's own socket, so it cannot reach the system daemon without an explicit URI and socket path; brew's `libvirt` is only a dependency of an unused Terraform provider and is removed by the change `remove-brew-libvirt`.
  - Vagrant 2.4.9 with `vagrant-libvirt` 0.12.2 (linked against the system libvirt); the four local boxes are VirtualBox-only.
  - podman and docker installed; VirtualBox installed, with 37 registered VMs used for other work.
  - 12 CPUs, 15 GB RAM with about 5 GB free in normal use, about 230 GB free disk.
  - Incus not installed; `incus` 7.0.1 is the apt candidate.
- Facts checked on 2026-11-07:
  - The Incus image server lists `kali/current`, `archlinux/current`, `debian/trixie`, `debian/forky`, `ubuntu/noble`, `ubuntu/resolute`, `fedora/43` to `45`, `almalinux/8` to `10`, most with a `cloud` (cloud-init) variant.
  - For Kali the server has container files only (`rootfs.squashfs`); Arch, Debian and Ubuntu also have a VM disk (`disk.qcow2`).
  - Kali publishes a generic cloud image with cloud-init (`kali-linux-2026.3-cloud-genericcloud-amd64.tar.xz`, on `kali.download/cloud-images/`); its `kalilinux/rolling` Vagrant box (2026.2.0) ships a `libvirt` provider.
  - Incus accepts OCI registries as image remotes (`incus remote add <name> <url> --protocol=oci`) and runs their images as application containers; running OCI images as VMs is `lxc/incus#1360`, open and assigned, with no release date.
  - Incus documents `incus-simplestreams generate-metadata` and `incus-migrate` for importing images and disks that come without Incus metadata.
  - GitHub-hosted Linux runners expose KVM to the runner user after a udev rule (GitHub changelog, 2024-04-02).
  - cem pins no chezmoi version in its mise files; `rationalize-package-ownership` still asks whether chezmoi itself moves to mise.
- CI belongs to cem task `T-013`; this change only has to leave every guest kind it uses runnable there.

## Goals / Non-Goals

**Goals:**

- One way, local and on CI, to create a disposable Kali guest as a system container or a VM, give it this repository at a chosen commit, run a stage in it and destroy it.
- An engine chosen on stated criteria, with the losing options and the reasons kept here.
- No real secret ever inside a guest or a CI job.
- A smoke stage that proves the plumbing without applying anything.
- Engine-specific code kept in one place, so a fallback engine is a contained change.
- A target list that already has room for OCI images and for real machines, without code for them yet.

**Non-Goals:**

- Any lifecycle stage beyond smoke (each is its own change).
- Targets other than Kali (each distro is its own change; Omarchy needs an Arch VM plus its installer).
- Development container targets (devcontainers, DevPod) and real-machine targets (`kind = host`): the target list leaves room for them, nothing here implements them.
- OCI images as VMs: not supported by Incus today (`lxc/incus#1360`).
- A CI pipeline beyond one workflow running the smoke stage (cem `T-013`).
- Removing brew's libvirt (change `remove-brew-libvirt`).
- Fixing what the guests reveal (hard-coded `/home/tarax`, prompts, brew): those findings go to the changes that own them.

## Decisions

### Engine comparison

| Criterion | Incus | Vagrant with libvirt | OCI (podman, docker) | libvirt with cloud-init |
| --- | --- | --- | --- | --- |
| Hosted CI runner | apt install on the runner; containers need no KVM, VMs need the KVM udev rule | install Vagrant, libvirt and the plugin on every run; VMs only; slow start | preinstalled; fastest | install libvirt; VMs only |
| Containers and VMs from one tool | yes, same commands and images; also OCI application containers | VMs only | containers only, no real init unless a systemd image is built | VMs only |
| Distro catalog | official image server: Kali (container only), Arch, Debian, Ubuntu, Fedora, AlmaLinux (containers and VMs) | per-vendor boxes, uneven libvirt coverage; Kali has one | official images for all, none with init or cloud-init | vendor cloud images, downloaded and tracked by hand |
| Snapshots and restore | native, both kinds | `vagrant snapshot` on libvirt | image commit only, no live state | `virsh snapshot`, by hand |
| First-boot provisioning | cloud-init from instance config | shell provisioners | Dockerfile | cloud-init seed image |
| Laptop setup | apt, a group, `incus admin init`; firewall interplay with docker | already installed | already installed | already installed |
| Fidelity | system container: real init, sudo, login; VM: full machine | full machine | process container | full machine |

### Engine: Incus, confirmed by a spike

Incus is the only option that gives both guest kinds, most of the distro list, cloud-init and snapshots from one tool on the laptop and on a hosted runner.
The choice stays provisional until a spike shows four things:

1. A Kali system container from the image server boots locally with cloud-init and network.
2. A Kali VM boots locally with cloud-init and network; the server has no Kali VM image, so the spike imports the Kali generic cloud image (metadata from `incus-simplestreams generate-metadata`, or `incus-migrate`) and checks that it boots under Incus's UEFI firmware.
3. The official Kali OCI image, added as an `oci` remote, starts systemd as its entry command in a system container, with a `tester` user and sudo; this decides whether OCI is usable as a machine image.
4. A Kali system container boots on a hosted runner.

Fallbacks if the spike fails:

- Check 2: a Debian testing VM from the server switched to the Kali repositories, or Vagrant with libvirt for VMs (the Kali box exists), behind the same interface.
- Check 3: OCI stays reserved for development container targets, where the image format is the target itself.
- Checks 1 or 4: Vagrant with libvirt for VMs, podman with a systemd-enabled image for containers.

If check 3 passes, one image format can serve the harness, devcontainers, DevPod and CI; OCI as VMs is revisited when `lxc/incus#1360` ships.

### Interface: repository mise tasks over one Python entry point

- mise tasks in the root `mise.toml`, namespace `machine:`: `machine:list`, `machine:up <target>`, `machine:run <target> <stage> [--commit <ref>]`, `machine:snapshot`, `machine:restore`, `machine:down <target>`.
- The namespace is `machine` and not `test` (the `tests/` directory already holds other suites) or `host` (in virtualization the host is the machine that runs the guests, here the laptop, and cem uses `host` for a remote machine reached over SSH).
  systemd also says "machine" for containers and VMs alike, and a real computer is a machine too.
- Target kinds are `container`, `vm` and, reserved for later, `host`: an existing machine reached over SSH.
  A `host` target accepts `machine:run` and refuses `up`, `down`, `snapshot` and `restore`, so the harness can never create, delete or reset a real machine.
  Nothing implements `host` here; the rule is written so the target list does not change shape later.
- Managing real machines is cem's domain (`target.host`, cem `DR-005`); the harness may move into cem once cem can drive them, and the target list and stage contract are written to move unchanged.
- The tasks call one script, `tests/machine/machine.py`, which holds the command line; engine calls live in one module (`tests/machine/engine_incus.py`) and a fallback engine is a second module with the same functions.
- Alternative considered: a bash script; rejected because the target list is TOML and argument handling grows with the stages.

### Python stack

- The harness is repository tooling, not deployed: it follows cem's stack (cem `DR-003`) instead of the standard-library-only rule that holds for the global tasks deployed to every machine, which must run before anything is installed.
- Python at the fleet's mise pin (3.12.13), uv with a committed lock file, Typer with Rich for the command line, pytest for tests; ruff as in the fleet.
- The `incus` command line is called through `subprocess` (with `--format json` where output is parsed); no Incus API client: `pylxd` targets LXD and its Incus compatibility is unproven, and the command line keeps the engine module small and replaceable.
- Every library beyond that list needs a reason in this design or in the change that adds it; `tomllib` from the standard library reads the target list.
- Layout: `tests/machine/pyproject.toml` and `tests/machine/uv.lock`; the root `mise.toml` pins `python` and `uv` for it.

### Target list

`tests/machine/targets.toml`: a `[defaults]` table and one table per target.

- Defaults: `chezmoi_version` (the smoke stage installs this tag with the official installer, `-t <tag>`).
- Per target: `name`, `kind` (`container`, `vm`, later `host`), `image` (`images:<path>` for the Incus server, `oci:<remote>:<path>` for an OCI registry remote, or a local alias for an imported image), `ci` (`true` or `false`), `cpus`, `memory`, `disk`.
- First entries: `kali-container` (`images:kali/current/cloud`, `ci = true`) and `kali-vm` (the imported Kali cloud image; `ci` set after the spike).
- The chezmoi pin starts at the version the laptop runs (2.73.3 on 2026-11-07); it is a single value, so a later move of chezmoi to mise (open in `rationalize-package-ownership`) or a pin shared with cem changes one line.

### Isolation and guards

- Every guest lives in a dedicated Incus project, `dotfiles-test`, created on first use; the script never addresses an instance outside it.
- Instance names are `<target>-<short id>`; `machine:down` deletes only instances of that project, so a mistake cannot reach the other VMs on the laptop.
- Each command checks the state first (project exists, instance exists, instance running), so every command can run again safely.

### Guest provisioning

- cloud-init user data in `tests/machine/cloud-init/base.yaml`: a non-root user `tester` with passwordless sudo, and `git`, `curl`, `ca-certificates`, `sudo` installed.
- A user other than the laptop's is on purpose: it exposes hard-coded user paths (audit F24).
- The script waits for `cloud-init status --wait` before any stage.

### Repository delivery

- The host builds `git bundle create <file> <commit>` from the requested commit (default `HEAD`), pushes the file into the guest and clones it to `~/.local/share/chezmoi`, chezmoi's default source directory, as a real machine would have it.
- Only committed content enters the guest; the working tree, `.git/hooks` and any host configuration stay out.
- Alternative considered: a read-only mount of the working tree; rejected as the default because it tests uncommitted state and cannot give an older commit, which the update and rollback stages need.

### Secrets

- The script never copies anything from `~/.config/chezmoi`, `~/.ssh` or any key store into a guest, and the CI workflow uses no repository secret.
- The bundle holds `home/key.txt.age`, which is passphrase-protected and already public.
- Stages that apply run with `--exclude=encrypted`; how a stage keeps the passphrase-prompting decrypt script from blocking (for example a placeholder identity file) is decided by the first applying stage, `fresh-machine-bootstrap`.

### Stage contract

- A stage is an executable `tests/machine/stages/<name>.sh`, pushed into the guest and run there as `tester` through a login shell, with `EXPECTED_COMMIT` and `CHEZMOI_VERSION` in its environment.
- Exit status 0 passes; output goes to the terminal and to a log under `${XDG_STATE_HOME:-~/.local/state}/dotfiles-machine-tests/` on the host (an artifact on CI).
- `smoke.sh`: init reports running or degraded, `git -C ~/.local/share/chezmoi rev-parse HEAD` equals `EXPECTED_COMMIT`, chezmoi installed from `get.chezmoi.io` at `CHEZMOI_VERSION`, `chezmoi source-path` ends with `/home`.

### CI workflow

One workflow, `.github/workflows/machine-smoke.yml`, on `workflow_dispatch` and on pushes that touch `tests/machine/` or `home/`: install and initialise Incus on `ubuntu-latest`, run `machine:run kali-container smoke`, then the same for `kali-vm` in a job that enables KVM first.
cem `T-013` may replace it with the shared pipeline later.

## Risks / Trade-offs

- [Risk] Installing Incus on the laptop uses sudo and writes outside `$HOME` (`apt install incus`, group `incus-admin`, `incus admin init --minimal`). → Run only with the user's go; each step checks first (`command -v incus`, `id -nG`, `incus info`) and is skipped when done.
- [Risk] Docker's firewall rules drop forwarded traffic from the Incus bridge, so guests have no network. → Follow the Incus documentation's Docker section; the spike checks network from a guest before anything else.
- [Risk] KVM VMs and running VirtualBox VMs may not coexist. → Stop VirtualBox VMs before VM tests; recorded in the task that runs them.
- [Risk] Deleting guests is a deletion. → Guarded by the dedicated project and the name prefix; `machine:down` lists what it deletes; `host` targets refuse it.
- [Risk] Memory: about 5 GB free in normal use. → VMs default to 2 CPUs and 3 GB; one VM at a time locally.
- [Risk] The Kali VM has no image on the Incus server, so it depends on an imported image that nobody updates for us. → The import is a documented step of `machine:up` for that target, with the image URL and checksum in the target list; the spike checks the UEFI boot; fallback in the engine decision.
- [Risk] A hosted runner lacks disk or time for a VM. → The VM job may be marked `ci = false` after the spike; the target list says so explicitly.
- [Risk] The `oci` remote pulls images from a public registry. → Only pinned references (tag or digest) in the target list; no registry credential on CI.
- [Trade-off] A new host tool on the laptop and on CI, in exchange for one interface over both guest kinds.
- [Trade-off] Python dependencies and a lock file for repository tooling, in exchange for a tested command line that follows cem's stack and can move there.
- [Trade-off] Bundles test only committed state; quick iteration on uncommitted edits needs a commit (a local one is enough).

## Migration Plan

1. With the user's go, install and initialise Incus on the laptop (after `remove-brew-libvirt`, so the `virsh` on `PATH` is unambiguous).
2. Spike, in this order: network from a Kali system container, the imported Kali VM, the Kali OCI image as a system container, then a Kali system container on a hosted runner (a throwaway branch or a fork is enough).
3. Confirm or switch the engine in this design, then build the script, target list, cloud-init, smoke stage and tasks.
4. Add the CI workflow.

Rollback: `machine:down` for every target, `incus project delete dotfiles-test`, and with the user's go `apt remove incus`; the repository files go with a `git revert`.

## Open Questions

- Does the Kali generic cloud image boot under Incus's UEFI firmware, and does cloud-init pick up the instance configuration there?
- Does Incus start systemd from the official Kali OCI image as a system container?
- Does cem read the same chezmoi pin as the target list, or keep its own? (cem task `T-012`.)
- Does `fresh-machine-bootstrap` drive `chezmoi init` with `--promptDefaults` or with explicit `--promptString` and `--promptBool` answers from a per-target answers file? (Its own decision, needed before its stage runs here; the second is the lead: `--promptDefaults` only answers prompts that have a default, and the config template's prompts for email, name and others have none, so a non-interactive run would block.)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
