## Context

- Nothing tests the repository on a clean machine; the only proof is the laptop, where a full `chezmoi apply` is forbidden until `make-install-scripts-idempotent` is archived.
- `fresh-machine-bootstrap` planned its own podman container test (its design, section "Container test"); with this change it keeps the bootstrap stage and its assertions, and uses this infrastructure to run them.
- Lifecycle stages come later, each as its own change: fresh bootstrap, second apply is a no-op, update from an older commit to HEAD, rollback to the previous commit, purge.
- Targets come later too, each as its own change: Kali Rolling and Omarchy first, then Debian stable, Ubuntu stable and LTS, Arch, much later RPM-based distros; development containers (devcontainers, DevPod) are a target of their own, and so may be real machines reached over SSH, with cem.
- This change is the core, for system containers.
  Split out on 2026-11-07 because the whole was 23 requirements against 5 to 8 in the other changes of this repository:
  - `add-incus-host-setup` installs and initialises Incus on a host (production tooling) and decides the access group and storage defaults by acceptance checks on the laptop;
  - `add-incus-setup-hook` is the opt-in flag and the chezmoi hook;
  - `add-kali-vm-target` adds the `vm` kind, the imported Kali image and the `kali-vm` target;
  - `add-machine-smoke-ci` commits the workflow.
- Host on 2026-11-07:
  - KVM available (`/dev/kvm`); system `libvirtd` active, QEMU and `virt-install` installed; the `virsh` first on `PATH` comes from brew and cannot reach the system daemon (`remove-brew-libvirt`).
  - Vagrant 2.4.9 with `vagrant-libvirt` 0.12.2 (linked against the system libvirt); the four local boxes are VirtualBox-only.
  - podman and docker installed; VirtualBox installed, with 37 registered VMs used for other work.
  - 12 CPUs, 15 GB RAM with about 5 GB free in normal use, about 230 GB free disk.
- Images, checked on 2026-11-07:
  - The Incus image server lists `kali/current`, `archlinux/current`, `debian/trixie`, `debian/forky`, `ubuntu/noble`, `ubuntu/resolute`, `fedora/43` to `45`, `almalinux/8` to `10`, most with a `cloud` (cloud-init) variant.
  - For Kali the server has container files only (`rootfs.squashfs`); Arch, Debian and Ubuntu also have a VM disk (`disk.qcow2`).
  - Incus accepts OCI registries as image remotes and runs their images as application containers only; running them as VMs is `lxc/incus#1360`, open, no release date.
  - The `kalilinux/kali-rolling` OCI image has `CMD ["bash"]` and no entry point, so using it as a system container needs an image of our own (devcontainer follow-up).
- chezmoi 2.73.3 installs from `get.chezmoi.io` with `-t <tag>`; its prompt flags are keyed by prompt text, not by data path.
- GitHub-hosted Linux runners expose KVM to the runner user after a udev rule (GitHub changelog, 2024-04-02); containers need no KVM.
- cem pins no chezmoi version in its mise files; `rationalize-package-ownership` still asks whether chezmoi itself moves to mise.
- CI belongs to cem task `T-013`; the committed workflow is `add-machine-smoke-ci`.

## Goals / Non-Goals

**Goals:**

- One way, local and on CI, to create a disposable Kali system container, give it this repository at a chosen commit, run a stage in it and destroy it.
- An engine chosen on stated criteria, with the losing options and the reasons kept here.
- No real secret ever inside a guest or a CI job.
- A smoke stage that proves the plumbing without applying anything.
- Engine-specific code kept in one place, so a fallback engine is a contained change.
- A target list that already has room for virtual machines, OCI images and real machines, without code for them yet.

**Non-Goals:**

- Installing Incus (`add-incus-host-setup`), the opt-in flag and hook (`add-incus-setup-hook`).
- Virtual machines, the Kali image import and the `kali-vm` target (`add-kali-vm-target`).
- The committed CI workflow and its matrix (`add-machine-smoke-ci`).
- Any lifecycle stage beyond smoke (each is its own change).
- Targets other than Kali (each distro is its own change; Omarchy needs an Arch VM plus its installer).
- Development container targets (devcontainers, DevPod), OCI images as machines, and real-machine targets (`kind = host`): the target list leaves room for them, and the rules that belong to them (OCI references pinned; the harness never creates, resets or deletes a real machine) are written by the changes that implement them.
- Fixing what the guests reveal (hard-coded `/home/tarax`, prompts, brew): those findings go to the changes that own them.

## Decisions

### Engine comparison

| Criterion | Incus | Vagrant with libvirt | OCI (podman, docker) | libvirt with cloud-init |
| --- | --- | --- | --- | --- |
| Hosted CI runner | apt install (Zabbly on Ubuntu runners); containers need no KVM, VMs need the KVM udev rule | install Vagrant, libvirt and the plugin on every run; VMs only; slow start | preinstalled; fastest | install libvirt; VMs only |
| Containers and VMs from one tool | yes, same commands and images; also OCI application containers | VMs only | containers only, no real init unless a systemd image is built | VMs only |
| Distro catalog | official image server: Kali (container only), Arch, Debian, Ubuntu, Fedora, AlmaLinux (containers and VMs) | per-vendor boxes, uneven libvirt coverage; Kali has one | official images for all, none with init or cloud-init | vendor cloud images, downloaded and tracked by hand |
| Snapshots and restore | native, both kinds | `vagrant snapshot` on libvirt | image commit only, no live state | `virsh snapshot`, by hand |
| First-boot provisioning | cloud-init from instance config | shell provisioners | Dockerfile | cloud-init seed image |
| Laptop setup | apt, a group, `incus admin init` (the task of `add-incus-host-setup`); firewall interplay with docker | already installed | already installed | already installed |
| Fidelity | system container: real init, sudo, login; VM: full machine | full machine | process container | full machine |

### Engine: Incus, confirmed by a throwaway run on a hosted runner

Incus is the only option that gives both guest kinds, most of the distro list, cloud-init and snapshots from one tool on the laptop and on a hosted runner.
The choice stays provisional until it has passed four checks, split by where they belong:

1. A guest reaches the network while Docker runs: acceptance of `add-incus-host-setup`.
2. A Kali VM boots from the imported Kali image, with its fallbacks: `add-kali-vm-target`.
3. A user in the restricted `incus` group can run containers and VMs and snapshot them: acceptance of `add-incus-host-setup`.
4. A Kali system container boots on a hosted runner with the Zabbly `lts-7.0` package: the first group of this change's tasks, run as a throwaway workflow on a branch or a fork (public pushes need the user's go), with the setup task's source file doing the install.

Fallbacks if a check fails:

- Check 4: Vagrant with libvirt for VMs and podman with a systemd-enabled image for containers, behind the same interface; the engine module is the only code that changes.
- Check 2: contained in `add-kali-vm-target` (Vagrant with libvirt for VMs only).

### Interface: repository mise tasks over one Python entry point

- mise tasks in the root `mise.toml`, namespace `machine:`: `machine:list`, `machine:up <target>`, `machine:run <target> <stage> [--commit <ref>]`, `machine:snapshot`, `machine:restore`, `machine:down <target>`.
- The namespace is `machine` and not `test` (the `tests/` directory already holds other suites) or `host` (in virtualization the host is the machine that runs the guests, here the laptop, and cem uses `host` for a remote machine reached over SSH).
  systemd also says "machine" for containers and VMs alike, and a real computer is a machine too.
- Target kinds are `container`, `vm` and, reserved for later, `host`: an existing machine reached over SSH.
  The file may name `vm` and `host` targets and `oci:` or imported-image references (the rule that the list does not change shape later); every command that would need one exits 2 with "not implemented yet" until the change that implements it, which also writes the rules that belong to it.
- Managing real machines is cem's domain (`target.host`, cem `DR-005`); the harness may move into cem once cem can drive them, and the target list and stage contract are written to move unchanged.
- The tasks call one script, `tests/machine/machine.py`, which holds the command line; engine calls live in one module (`tests/machine/engine_incus.py`) and a fallback engine is a second module with the same functions.
- Every command takes `--targets <file>` (another target list, used by scratch scenarios); `machine:list` takes `--json`; `machine:snapshot` and `machine:restore` take a snapshot name after the target; `MACHINE_ENGINE` names the engine command (default `incus`), so a missing engine is testable.
- Exit codes follow the fleet: 0 success, 1 failure, 2 usage, target-list error or not-implemented, 127 missing engine command; results go to standard output, messages and logs to standard error.
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
- Per target: `name`, `kind` (`container`, `vm`, later `host`), `image` (`images:<path>` for the Incus server; the other forms are reserved: `oci:<remote>:<path>:<tag>` and a local alias for an imported image), `ci` (`true` or `false`), `cpus`, `memory`, `disk`.
- Optional per target: `config`, a table of Incus instance options passed at launch, and `cloud_init`, the list of cloud-init snippets to merge (default `["base"]`).
- First entry: `kali-container` (`images:kali/current/cloud`, `ci = true`).
- The chezmoi pin starts at the version the laptop runs (2.73.3 on 2026-11-07); it is a single value, so a later move of chezmoi to mise (open in `rationalize-package-ownership`) or a pin shared with cem changes one line.

### Isolation and guards

- The harness project is, in this order: the value of `MACHINE_PROJECT` when set; `dotfiles-test`, created on first use, when the user may create projects (`incus-admin`); otherwise the one project the user can see (a user in the restricted `incus` group is confined to a project of their own).
- Every guest carries the key `user.dotfiles-machine` set to its target name, and a name made of the target name, a dash and a short identifier.
- `machine:down <target>` prints the names it is going to delete and deletes only guests of the harness project that carry the key, so a mistake cannot reach other instances, whichever access mode is in use.
- Each command checks the state first (project exists, instance exists, instance running), so every command can run again safely.

### Guest provisioning

- cloud-init user data in `tests/machine/cloud-init/base.yaml`: a non-root user `tester` with passwordless sudo, and `git`, `curl`, `ca-certificates`, `sudo` installed.
- A user other than the laptop's is on purpose: it exposes hard-coded user paths (audit F24).
- The script waits for the agent and then for `cloud-init status --wait` before any stage.

### Repository delivery

- The host builds `git bundle create <file> <commit>` from the requested commit (default `HEAD`), pushes the file into the guest and clones it to `~/.local/share/chezmoi`, chezmoi's default source directory, as a real machine would have it.
- Only committed content enters the guest; the working tree, `.git/hooks` and any host configuration stay out.
- Alternative considered: a read-only mount of the working tree; rejected as the default because it tests uncommitted state and cannot give an older commit, which the update and rollback stages need.

### Secrets

- The script never copies anything from `~/.config/chezmoi`, `~/.ssh` or any key store into a guest, and the CI workflow (`add-machine-smoke-ci`) uses no repository secret.
- The bundle holds `home/key.txt.age`, which is passphrase-protected and already public.
- Stages that apply run with `--exclude=encrypted`; how a stage keeps the passphrase-prompting decrypt script from blocking (for example a placeholder identity file) is decided by the first applying stage, `fresh-machine-bootstrap`.

### Stage contract

- A stage is an executable `tests/machine/stages/<name>.sh`, copied to `/home/tester/stages/<name>.sh` and run there as `tester` through a login shell, with `EXPECTED_COMMIT` and `CHEZMOI_VERSION` in its environment.
- Exit status 0 passes; output goes to the terminal and to a log under `${XDG_STATE_HOME:-~/.local/state}/dotfiles-machine-tests/` on the host (an artifact on CI).
- `smoke.sh`: init reports running or degraded, `git -C ~/.local/share/chezmoi rev-parse HEAD` equals `EXPECTED_COMMIT`, chezmoi installed from `get.chezmoi.io` at `CHEZMOI_VERSION`, `chezmoi source-path` ends with `/home`.

## Risks / Trade-offs

- [Risk] The throwaway run publishes a branch to the public repository, or uses a fork. → Only with the user's go; the workflow holds no secret; the branch is deleted afterwards.
- [Risk] The harness runs on an Incus that nobody installed. → Missing or unreachable engines exit 127 or 1 and name `mise run sys:virt:incus:setup`.
- [Risk] Deleting guests is a deletion. → Only guests of the harness project that carry the `user.dotfiles-machine` key; `machine:down` lists what it deletes.
- [Risk] Memory: about 5 GB free in normal use. → Containers are light; the VM defaults (2 CPUs, 3 GB, one VM at a time) are set in `add-kali-vm-target`.
- [Risk] Kali's apt Incus (7.0 LTS) and CI's Zabbly `lts-7.0` can drift apart. → Same release line; `add-machine-smoke-ci` adds an informational `stable` leg to show what is coming.
- [Risk] A hosted runner lacks disk or time for a Kali container. → The throwaway run measures it; a target may be marked `ci = false`, and the target list says so explicitly.
- [Trade-off] A new host tool on the laptop and on CI, in exchange for one interface over both guest kinds.
- [Trade-off] Python dependencies and a lock file for repository tooling, in exchange for a tested command line that follows cem's stack and can move there.
- [Trade-off] Bundles test only committed state; quick iteration on uncommitted edits needs a commit (a local one is enough).
- [Trade-off] The core proves containers only; the Kali VM is proven by `add-kali-vm-target`, a change later in the order.

## Migration Plan

1. `remove-brew-libvirt`, then `add-incus-host-setup` applied on the laptop (with its acceptance checks), so that `incus` is the system one and reachable.
2. Throwaway run (group 1 of the tasks): a Kali container boots on a hosted runner with the Zabbly `lts-7.0` package; with the user's go.
3. Confirm or switch the engine in this design, then build the script, target list, cloud-init, smoke stage and tasks.
4. `add-machine-smoke-ci` commits the workflow; `add-kali-vm-target` adds the VM.

Rollback: `machine:down` for every target, `incus project delete` for the harness project; the repository files go with a `git revert`.

## Open Questions

- Does a Kali container boot, with cloud-init, on a hosted runner with the Zabbly `lts-7.0` package, and how long does it take?
- Does cem read the same chezmoi pin as the target list, or keep its own? (cem task `T-012`.)
- Does `fresh-machine-bootstrap` drive `chezmoi init` with `--promptDefaults` or with explicit prompt answers from a per-target answers file, keyed by the prompt texts and not by the data paths (checked on 2.73.3)? (Its own decision, needed before its stage runs here; the second is the lead: `--promptDefaults` only answers prompts that have a default, and the config template's prompts for email, name and others have none, so a non-interactive run would block.)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
