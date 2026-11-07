## Context

- The harness core boots containers only; its target list already has room for `vm` targets and imported images, and refuses them with "not implemented yet" until this change.
- The Incus image server has Kali containers only (`rootfs.squashfs`); Arch, Debian and Ubuntu also have a VM disk (`disk.qcow2`).
- The recipe `debian.yaml` of `lxc/lxc-ci` has 14 VM-only sections (kernel, `grub-efi`, `incus-agent`, grub console); `kali.yaml` has none; no issue asks for Kali VMs; `distrobuilder` 3.3.1 is in Kali's apt.
- Kali publishes a generic cloud image (`kali-linux-2026.3-cloud-genericcloud-amd64.tar.xz`, 240.6 MB, checksum from `SHA256SUMS` on `kali.download`).
  Inspected on 2026-11-07 without booting it:
  - GPT with a BIOS boot partition, an EFI system partition and an ext4 root; 25 GiB raw disk;
  - the EFI partition holds an unsigned `grubx64.efi` (also installed as `BOOTX64.EFI`; no certificate table, no `shim`);
  - kernel `7.1.5+kali-cloud-amd64`; cloud-init present; no `incus-agent` and no QEMU guest agent.
- So the image should boot under Incus's UEFI firmware with Secure Boot off, and with the legacy BIOS (`security.csm`) too; with Secure Boot on it cannot boot.
- Incus runs a VM without the agent when the image metadata says `requirements.cdrom_agent: true` (the agent CD-ROM is attached) and the guest installs the agent from it (`mount /dev/disk/by-label/incus-agent /mnt; /mnt/install.sh`); cloud-init data then comes through the extra disk `cloud-init:config` (Incus documentation).
- The README of Kali's VM builder (`kali-vm`) describes MBR images with `grub-pc`, UEFI only for its Hyper-V variant; the published cloud image does not match that (it is GPT with both a BIOS boot and an EFI partition), so how it is built is not known from here.
- Incus VMs boot UEFI with Secure Boot on by default; `security.secureboot=false` turns it off, and `security.csm=true` (which needs it off) boots through SeaBIOS.
- Kali ships `shim-signed` (1.51+16.1-2) but no `grub-efi-amd64-signed`; Secure Boot is `support-kali-vm-secure-boot`.
- KVM-based VMs and running VirtualBox VMs may not coexist on the laptop (37 VirtualBox VMs are registered).

## Goals / Non-Goals

**Goals:**

- `kind = "vm"` works through the same six tasks as containers.
- The Kali cloud image is imported once, checked, and boots as a guest with a working agent and cloud-init.
- The smoke stage passes on the VM.
- The fallbacks are written down in order, so a failed boot is a decision and not a surprise.

**Non-Goals:**

- A Kali VM image of our own, UEFI recipe or Secure Boot (`support-kali-vm-uefi`, `support-kali-vm-secure-boot`).
- VM targets for other distros: those with a VM image on the Incus server need no import and are their own changes.
- The committed CI workflow (`add-machine-smoke-ci`), which decides per target with `ci`.

## Decisions

### The `vm` kind

- The engine module launches `kind = "vm"` targets with `incus launch --vm`, with the target's `cpus`, `memory`, `disk` and `config`, and waits for the agent before cloud-init (a VM boots slower than a container).
- Everything else (project, marker key, bundle delivery, stages, snapshot and restore) is shared with containers.
- VM defaults: 2 CPUs and 3 GB of memory, one VM at a time on the laptop.

### Imported images

- For a target whose `image` is a local alias, `machine:up` imports the image once:
  1. download `image_url` to `${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-machine-tests/`;
  2. check `image_sha256` before anything else touches the file;
  3. extract, convert the raw disk to qcow2 with `qemu-img`;
  4. write the metadata file (architecture, creation date, `requirements.cdrom_agent: true`);
  5. `incus image import` under the alias;
  6. delete the archive and the converted disk after a successful import.
- A later run finds the alias and skips all of it.
- The checksum comes from the target list, which comes from the vendor's `SHA256SUMS`; updating the image is a one-line change of URL and checksum.

### Agent snippet

`tests/machine/cloud-init/agent.yaml`, merged for targets whose image lacks the agent (`cloud_init = ["base", "agent"]`): installs the agent from the agent CD-ROM, so that `incus exec` and file transfer work on an image that was not built for Incus.

### The `kali-vm` target

`kali-vm`: `kind = "vm"`, the imported alias, `image_url` and `image_sha256` of the Kali cloud image, `config = { "security.secureboot" = "false" }` first and `"security.csm" = "true"` if the spike needs the BIOS path, `cloud_init = ["base", "agent"]`, `ci` set after the spike and the CI change.

### Spike order

1. UEFI firmware with `security.secureboot=false`.
2. Legacy BIOS with `security.csm=true` and `security.secureboot=false`.
3. A Kali VM image built with `distrobuilder` from the `kali.yaml` recipe plus the VM sections of `debian.yaml`: becomes `support-kali-vm-uefi`, which also covers UEFI properly.
4. A Debian testing VM from the image server switched to the Kali repositories.
5. If Incus cannot run any of them: Vagrant with libvirt for VMs (the `kalilinux/rolling` box has a libvirt provider), behind the same interface; only the engine module changes.

Each step is judged by the same test: the agent answers (`incus exec <name> -- true`) and `cloud-init status --wait` ends with `done`.

## Risks / Trade-offs

- [Risk] The Kali VM depends on an imported image that nobody updates for us, with an unsigned bootloader, so it runs with Secure Boot off. → The URL and checksum are in the target list; it is a throwaway test guest; Secure Boot and our own image are follow-up changes.
- [Risk] The import downloads 240 MB and converts a 25 GiB raw disk. → Done once, in the user's cache directory, deleted afterwards; the spike measures time and space.
- [Risk] KVM VMs and running VirtualBox VMs may not coexist. → The VM scenarios say to stop the VirtualBox VMs first; recorded in the task that runs them.
- [Risk] Memory: about 5 GB free in normal use. → 2 CPUs and 3 GB by default; one VM at a time.
- [Risk] A hosted runner lacks KVM, disk or time for a VM. → The target's `ci` flag says so; `add-machine-smoke-ci` follows it.
- [Risk] The vendor changes the image layout (UEFI-only, a signed chain). → The checksum fails first; the target is updated by hand; the spike order is re-run.
- [Trade-off] The import code is specific to images that ship as a raw disk in an archive; other formats are added when a target needs them.

## Migration Plan

1. After `add-machine-lifecycle-test-infra` and `add-incus-host-setup` are applied, with the VirtualBox VMs stopped.
2. Spike in the order above, with the user's go for the download.
3. Implement the `vm` kind, the import and the `kali-vm` target for the step that worked; record the choice here.
4. Smoke on the VM.

Rollback: `machine:down kali-vm`, `incus image delete` of the alias, delete the cache directory; the repository files go with a `git revert`.

## Open Questions

- Does the Kali cloud image boot under Incus's UEFI firmware with Secure Boot off, and under the legacy BIOS, and does the agent installed from the CD-ROM work?
- Does a restricted project (the `incus` group) allow importing an image and launching a VM from it?
- How long does the import take, and how much space does it need at its peak?

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
