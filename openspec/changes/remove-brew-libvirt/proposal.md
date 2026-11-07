## Why

Homebrew's `libvirt` is installed only as a dependency of `terraform-provider-libvirt`, a Terraform provider that nothing here uses (Terraform downloads its providers from the registry), and it puts a `virsh` first on `PATH` that looks for brew's own socket and cannot reach the system libvirt daemon that is running.
The same shadowing would happen with brew's `incus`, a command-line client only (7.6) that would hide the system `/usr/bin/incus` and may not match the daemon's version, once Incus is installed from apt by `add-incus-host-setup`; brew's `qemu` would shadow the system QEMU that Incus and libvirt use.
Removing them fixes the `virsh` today, and a ban keeps them from coming back by accident through a dependency, a Brewfile line or a hand-typed `brew install`.
Source: found while preparing `add-machine-lifecycle-test-infra`; audit `docs/audits/2026-10-30-environment.md`, finding F16 (package drift and overlap between managers) and the install priority rule (mise, brew, apt, vendor repository, Flatpak).

## What Changes

- Remove the `terraform-provider-libvirt` line from the Brewfile, uninstall `terraform-provider-libvirt` and `libvirt` with brew, and review then remove the dependencies they leave orphaned (`libiscsi`, `libnl` at the time of writing).
- A managed file `home/dot_config/homebrew/brew.env` that sets `HOMEBREW_FORBIDDEN_FORMULAE` to `libvirt qemu terraform-provider-libvirt incus` and `HOMEBREW_FORBIDDEN_OWNER`, so that Homebrew refuses to install them, or any formula that depends on them.
- A managed symlink `~/.homebrew/brew.env` to that file, because Homebrew reads the user file from `$XDG_CONFIG_HOME/homebrew` when `XDG_CONFIG_HOME` is set and from `~/.homebrew` otherwise, and minimal shells (ssh command, cron, `env -i`) do not set it.
- Checks that the system `virsh`, `incus` and the Vagrant libvirt plugin are unaffected.

## Capabilities

### New Capabilities

- `brew-package-bans`: which formulae Homebrew must never install on these machines, and how the ban is configured for every kind of shell.

### Modified Capabilities

None.

## Impact

- Uninstalling formulae deletes files under the Homebrew prefix, outside `$HOME`; it needs the user's go, and the Brewfile change is committed by the brew hook (expect a `chore(pkg:brew): remove ...` commit).
- New managed files: `home/dot_config/homebrew/brew.env` and `home/dot_homebrew/symlink_brew.env`; applied alone with `--exclude=scripts`.
- Nothing outside the Homebrew prefix changes: no sudo, no system-wide `/etc/homebrew/brew.env`.
- A banned formula also blocks installing any formula that depends on one; the ban list is short and each entry has a reason.
- Order: first of the Incus group (`add-incus-host-setup` follows), and independent of `fix-chezmoi-config-template` and `make-install-scripts-idempotent`.
- `rationalize-package-ownership` may later fold the ban list into its ownership table.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
