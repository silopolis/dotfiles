## Why

Incus VMs boot with Secure Boot on by default, and the Kali VM image runs with it off because its bootloader is unsigned (`grubx64.efi` without a certificate table, no `shim` on the EFI system partition of the published cloud image).
Booting with the default firmware settings would remove the instance option from the harness and make the Kali guest closer to a production machine.
Kali ships `shim-signed` (1.51+16.1-2) but no `grub-efi-amd64-signed`, so Debian's signed GRUB is not available there and its own `grub-efi-amd64` (2.14-4+kali1) is a Kali build: whether a signed chain exists for Kali at all is the first question.
Stub: refine at the start of its own session (`/opsx-continue support-kali-vm-secure-boot`), after `support-kali-vm-uefi`.

## What Changes

- Research first, written into the design: what Kali offers for a signed chain (`shim-signed` and the signature on its GRUB build), what keys the Incus firmware trusts (it ships the Microsoft keys), and the options if Kali has no chain: a bootloader signed with our own key and enrolled through the machine owner key (`mokutil`, `sbsigntool`), a different bootloader, or an upstream request to Kali.
- The recipe of `support-kali-vm-uefi` gains the chosen chain, and the image boots with `security.secureboot` left at its default (true).
- The `kali-vm` harness target drops its Secure Boot override.

## Capabilities

### New Capabilities

- `kali-vm-image`: extended by this change with the Secure Boot requirement (the capability is created by `support-kali-vm-uefi`; this change adds to it after that one is archived).

### Modified Capabilities

None.

## Impact

- Depends on `support-kali-vm-uefi`.
- A signing key, if our own chain is chosen, is a secret: it never enters this public repository or a CI job; where it lives is decided in the design.
- `tests/machine/targets.toml` changes one target.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
