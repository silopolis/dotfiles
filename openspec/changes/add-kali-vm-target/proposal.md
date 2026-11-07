## Why

The harness core (`add-machine-lifecycle-test-infra`) boots Kali system containers only, but a virtual machine is the closer match to a real machine (own kernel, boot process, login sessions), and the first targets of the roadmap are Kali and Omarchy, which will need VMs.
The Incus image server publishes Kali as containers only, so a Kali VM has to come from Kali's own cloud image, which Incus does not know how to run: it has no Incus agent, and its bootloader is unsigned.
Source: split out of `add-machine-lifecycle-test-infra` on 2026-11-07; audit `docs/audits/2026-10-30-environment.md`, finding F25 (bootstrap scripts that were never tested on a clean machine).

## What Changes

- The `vm` kind becomes implemented: `machine:up`, `machine:run`, `machine:snapshot`, `machine:restore` and `machine:down` accept a `kind = "vm"` target and launch it with `--vm`, waiting for the agent.
- Images that Incus does not ship are imported once: the archive is downloaded to the cache directory, checked against a SHA-256 from the target list, converted to qcow2, given metadata that asks Incus to attach the agent CD-ROM, imported under an alias, and the scratch files are deleted.
- The `kali-vm` target: Kali's published cloud image, with Secure Boot off (the bootloader is unsigned), and a cloud-init snippet that installs the agent from the CD-ROM.
- The smoke stage passes on the VM.
- Spike, with fallbacks in a fixed order: UEFI with Secure Boot off, then legacy BIOS (`security.csm`), then a Kali VM image built with `distrobuilder` (the follow-up `support-kali-vm-uefi`), then a Debian testing VM switched to the Kali repositories; if Incus cannot run any of them, Vagrant with libvirt for VMs only, behind the same interface.

## Capabilities

### New Capabilities

- `machine-test-vms`: VM guests in the machine test harness, and the import of images that Incus does not ship.

### Modified Capabilities

None.

## Impact

- Depends on `add-machine-lifecycle-test-infra` (the harness core, whose spec it extends once archived) and on `add-incus-host-setup` (Incus with KVM).
- New files under `tests/machine/` (the import code, the `agent` cloud-init snippet) and one target in `targets.toml`.
- A 240 MB download and a 25 GiB raw disk to convert, once per host, in the user's cache directory.
- KVM-based virtual machines and VirtualBox cannot run at the same time on the laptop: VirtualBox VMs must be stopped for the VM scenarios.
- Memory: about 5 GB free in normal use, so one VM at a time locally, 2 CPUs and 3 GB by default.
- Followed by `support-kali-vm-uefi` (an image of our own) and `support-kali-vm-secure-boot`.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
