## ADDED Requirements

### Requirement: The Kali VM image is built from a recipe and boots under UEFI

The repository SHALL hold the recipe and the build task of a Kali virtual machine image, and the image built from them SHALL boot as an Incus VM under UEFI firmware with a working Incus agent and cloud-init, without the agent being installed by the harness.

#### Scenario: Recipe has the VM sections

- **WHEN** `rg -c -e 'grub-efi' -e 'incus-agent' <recipe>` runs
- **THEN** it prints at least 2

#### Scenario: Image boots with the agent

- **WHEN** the built image is imported into Incus, launched with `--vm -c security.secureboot=false`, and `incus exec <name> -- true` runs after `incus exec <name> -- cloud-init status --wait`
- **THEN** both exit 0 and `incus exec <name> -- test -d /sys/firmware/efi` exits 0

### Requirement: The pipeline choice is recorded

The design SHALL record the criteria and the chosen pipeline for building custom images, and the reasons the other options were rejected.

#### Scenario: Decision is written

- **WHEN** `rg -c -e 'distrobuilder' -e 'Packer' openspec/changes/support-kali-vm-uefi/design.md` runs after the design exists
- **THEN** it prints at least 2

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
