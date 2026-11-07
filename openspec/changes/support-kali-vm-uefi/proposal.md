## Why

The Incus image server publishes Kali as containers only: the `kali.yaml` recipe of `lxc/lxc-ci` has no VM sections, while `debian.yaml` has 14.
The change `add-kali-vm-target` therefore boots Kali's published cloud image, imported once, with an unsigned bootloader, no Incus agent and no owner for its updates.
An image of our own, built from a recipe, gives reproducible UEFI Kali virtual machines that come from the same source as the container, and a candidate to propose upstream.
Stub: refine at the start of its own session (`/opsx-continue support-kali-vm-uefi`), after `add-kali-vm-target` has proved the plumbing and its spike has shown how the published image behaves.

## What Changes

- A Kali VM image recipe: `kali.yaml` from `lxc/lxc-ci` plus the VM sections of `debian.yaml` (kernel, `grub-efi`, `incus-agent`, grub console settings), with a cloud-init variant, built into an Incus VM image that boots with UEFI.
- The image pipeline decided with criteria written first: Incus-native output and upstreamability (a fork of `lxc/lxc-ci` with `distrobuilder`, or the recipe kept here), against Packer, which can also produce OCI images, Vagrant boxes and cloud images for the devcontainer and DevPod targets; build host, sudo needs, disk and time, reproducibility, and where images are published.
- The `kali-vm` target of the harness switches from the imported cloud image to this image once it boots under UEFI with a working agent and cloud-init, and its instance options (Secure Boot off) stay until `support-kali-vm-secure-boot`.
- Upstream: an issue on `lxc/lxc-ci` asking for Kali VM images, then a pull request with the VM sections once our build works; each text is drafted for the user's review before anything is posted or forked.

## Capabilities

### New Capabilities

- `kali-vm-image`: a Kali virtual machine image built from a recipe, booting under UEFI with the Incus agent and cloud-init.

### Modified Capabilities

None.

## Impact

- New recipe and build task (location decided by the pipeline decision); building with `distrobuilder` (Kali apt, 3.3.1) needs sudo and several GB of disk.
- `tests/machine/targets.toml` changes one target.
- Depends on `add-kali-vm-target`; followed by `support-kali-vm-secure-boot`.
- Public actions (fork, issue, pull request) need the user's go and a drafted text.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
