## ADDED Requirements

In the scenarios below, `<project>` is the harness project of the capability `machine-test-harness`.
Scenarios need a host where `incus info` succeeds and `/dev/kvm` is usable, with the VirtualBox VMs stopped.

### Requirement: VM guests use the same interface as containers

`machine:up`, `machine:run`, `machine:snapshot`, `machine:restore` and `machine:down` SHALL accept a target whose `kind` is `vm`, launch it as an Incus virtual machine with the target's `cpus`, `memory`, `disk` and `config`, and wait until the agent answers and cloud-init has finished before they return.
The marker key, the harness project and the deletion rule of `machine-test-harness` SHALL apply unchanged.

#### Scenario: VM is launched as a virtual machine

- **WHEN** `mise run machine:up kali-vm` runs and `incus list --project <project> --format json | jq -r '.[] | select(.config["user.dotfiles-machine"] == "kali-vm") | .type'` runs
- **THEN** the first exits 0 and the second prints `virtual-machine`

#### Scenario: Agent and cloud-init are ready

- **WHEN** `incus exec <name> --project <project> -- cloud-init status --wait` runs against the guest printed by `machine:up kali-vm`
- **THEN** it exits 0 and prints `status: done`

#### Scenario: Snapshot and restore

- **WHEN** `machine:snapshot kali-vm clean` runs, then a file is created in the guest, then `machine:restore kali-vm clean` runs
- **THEN** both commands exit 0 and the file no longer exists in the guest

#### Scenario: Down removes only marked VMs

- **WHEN** `mise run machine:down kali-vm` runs while an unmarked virtual machine exists in the same project
- **THEN** the unmarked one is still listed by `incus list --project <project> --format csv -c n`

### Requirement: Imported images are pinned and checked

A target whose `image` is a local alias SHALL set `image_url` and `image_sha256`, and the downloaded file SHALL be checked against `image_sha256` before anything is extracted or imported.

#### Scenario: Imported image needs a checksum

- **WHEN** `mise run machine:list --targets <scratch list with a local-alias image and no image_sha256>` runs
- **THEN** it exits 2 and its error names the target and the field `image_sha256`

#### Scenario: Checksum mismatch stops the import

- **WHEN** `mise run machine:up kali-vm --targets <scratch list with a wrong image_sha256>` runs on a host where the image alias does not exist yet
- **THEN** it exits non-zero, its error says the checksum differs, and `incus list --project <project> --format csv -c n` shows no new instance

### Requirement: Images that Incus does not ship are imported once and made agent-ready

For a target whose `image` is a local alias, `machine:up` SHALL download `image_url` to `${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-machine-tests/`, convert the raw disk to qcow2, write metadata that sets `requirements.cdrom_agent` to true, and import the result under the alias; it SHALL delete the downloaded archive and the converted disk after a successful import, and SHALL skip all of it when the alias already exists.

#### Scenario: Alias exists after the first up

- **WHEN** `mise run machine:up kali-vm` runs on a host without the alias
- **THEN** it exits 0 and `incus image list --project <project> --format csv -c l` lists the alias of the target's `image`

#### Scenario: Scratch files are removed

- **WHEN** `ls "${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-machine-tests/" | grep -c -e 'tar\.xz$' -e 'qcow2$'` runs after that import
- **THEN** it prints 0

#### Scenario: Second up does not download

- **WHEN** `mise run machine:up kali-vm --targets <scratch list whose image_url is http://127.0.0.1:9/unreachable>` runs after the alias exists
- **THEN** it exits 0

#### Scenario: The agent works in the imported VM

- **WHEN** `incus exec <name> --project <project> -- true` runs against the guest printed by `machine:up kali-vm`
- **THEN** it exits 0

### Requirement: The Kali VM target boots Kali's cloud image

`tests/machine/targets.toml` SHALL hold a target `kali-vm` with `kind = "vm"`, an imported image with its URL and SHA-256, `config` that turns Secure Boot off (and, if the spike requires it, the legacy BIOS), and `cloud_init` that merges the `base` and `agent` snippets of `tests/machine/cloud-init/`.

#### Scenario: Target is listed

- **WHEN** `mise run machine:list --json | jq -r '.[] | select(.name == "kali-vm") | "\(.kind) \(.config["security.secureboot"])"'` runs
- **THEN** it prints `vm false`

#### Scenario: Agent snippet exists

- **WHEN** `test -f tests/machine/cloud-init/agent.yaml && rg -c 'incus-agent' tests/machine/cloud-init/agent.yaml` runs at the repository root
- **THEN** it exits 0 and prints at least 1

#### Scenario: Smoke passes on the virtual machine

- **WHEN** `mise run machine:run kali-vm smoke` runs
- **THEN** it exits 0

#### Scenario: Fallback choice is recorded

- **WHEN** `rg -c -e 'security.csm' -e 'distrobuilder' -e 'Debian testing' openspec/changes/add-kali-vm-target/design.md` runs after the spike
- **THEN** it prints at least 1, and the design names the step that worked

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
