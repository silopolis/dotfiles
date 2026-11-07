## Context

- Checked on 2026-11-07:
  - brew's `libvirt` 12.7.0 is installed as a dependency (`installed_on_request` false) of `terraform-provider-libvirt` 0.9.9, which is on the Brewfile (line 117); `brew uses --installed libvirt` lists only that provider.
  - No `~/.terraformrc` and no `~/.terraform.d/plugins`: Terraform does not use the brew provider.
  - After their removal only `libiscsi` and `libnl` would be unused dependencies of `libvirt`.
  - `which -a virsh` lists brew's first, then `/usr/bin/virsh`; with `LIBVIRT_DEFAULT_URI=qemu:///system` brew's `virsh` fails on brew's own socket path.
  - `vagrant-libvirt` links `/usr/lib/x86_64-linux-gnu/libvirt.so.0` (the system one), so removing brew's libvirt does not affect it.
  - brew's `incus` is 7.6 and installs the client only; `qemu` is not installed from brew.
- How the ban works, read from Homebrew's source on 2026-11-07:
  - `HOMEBREW_FORBIDDEN_FORMULAE` is a space-separated list; the check for the formula itself runs before any download is enqueued, the check for its dependencies runs in the install prelude, and casks are checked too; `brew upgrade` is covered.
  - The message names `HOMEBREW_FORBIDDEN_OWNER`, which defaults to "you"; `HOMEBREW_FORBIDDEN_OWNER_CONTACT` is optional.
  - `brew install --dry-run` does not run the check, so a dry run is not a test of the ban.
- How `brew.env` is read, from `bin/brew`:
  - the system file `/etc/homebrew/brew.env`, then `${HOMEBREW_PREFIX}/etc/homebrew/brew.env`, then the user file: `$XDG_CONFIG_HOME/homebrew/brew.env` when `XDG_CONFIG_HOME` is set, else `$HOMEBREW_XDG_CONFIG_HOME/homebrew/brew.env`, else `~/.homebrew/brew.env`;
  - each line that starts with `HOMEBREW_` is exported as a whole (`export "${line}"`): a value with spaces needs no quotes, and quotes would be part of the value;
  - verified against scratch directories with `brew config`: both the XDG file and a relative symlink at `~/.homebrew/brew.env` work, and a quoted value shows its quotes.
- The interactive shell sets `XDG_CONFIG_HOME=~/.config`; `~/.homebrew` does not exist yet; minimal non-interactive shells set neither.
- The brew hook (`home/dot_config/shell/rc.d/110-pkg_brew.sh`) re-adds the Brewfile after a brew change and commits it by itself.
- `brew uses` without `--installed` returned nothing for any of the four names when tried, even for `libvirt`, so which formulae of homebrew-core depend on a banned name is not known from here.

## Goals / Non-Goals

**Goals:**

- Brew's libvirt stack gone, and the system `virsh` the first one on `PATH`.
- A ban that survives every kind of shell and cannot be bypassed by a dependency.
- Nothing broken: the Vagrant plugin, the system libvirt, other brew formulae.

**Non-Goals:**

- Moving other packages between managers (`rationalize-package-ownership`).
- A system-wide ban in `/etc/homebrew/brew.env` (needs sudo, writes outside `$HOME`).
- Installing Incus (`add-incus-host-setup`) or a mise-managed Incus client (backlog in `TODO.md`).

## Decisions

### Ban list

`libvirt qemu terraform-provider-libvirt incus`:

- `libvirt` and `terraform-provider-libvirt`: removed here; the provider is what pulled libvirt in.
- `qemu`: the system QEMU (apt) is what libvirt and Incus use; brew's would shadow `qemu-system-*`.
- `incus`: brew's is a client only and would shadow `/usr/bin/incus` with a version that may not match the daemon; the supported client is apt's, and a mise-managed one is a backlog item that would be done on purpose and then taken off this list.

### Two locations for one file

`home/dot_config/homebrew/brew.env` (`~/.config/homebrew/brew.env`, read when `XDG_CONFIG_HOME` is set) and a managed relative symlink `home/dot_homebrew/symlink_brew.env` whose content is `../.config/homebrew/brew.env` (`~/.homebrew/brew.env`, read when it is not), so the file has one content and two ways in.
The `HOMEBREW_FORBIDDEN_OWNER` line names this repository, so the refusal message says where the ban comes from.
Plain `KEY=value` lines, no quotes.

### Removal procedure

1. Record the state: `brew list --formula`, `brew uses --installed libvirt`, `which -a virsh`.
2. Remove the Brewfile line (the hook may do it after the uninstall; check `git diff` either way).
3. `brew uninstall terraform-provider-libvirt` then `brew uninstall libvirt`, in an interactive zsh so that the brew hook runs.
4. `brew autoremove --dry-run`: if it lists only `libiscsi` and `libnl`, run `brew autoremove`; if it lists anything else, `brew uninstall libiscsi libnl` by name instead and leave the rest alone.
5. Apply the two ban files alone (`chezmoi apply --exclude=scripts ~/.config/homebrew/brew.env ~/.homebrew/brew.env`).
6. Checks: `which -a virsh`, `virsh -c qemu:///system list --all`, `vagrant plugin list`, `brew missing`, `brew config`, then `brew install libvirt` (refused).

### Alternatives considered

- Only uninstalling: a dependency or a Brewfile line brings it back silently.
- A Brewfile comment or a `brew file clean` rule: `brew-file` does not stop an install.
- A shell alias or function around `brew`: bypassed by scripts and non-interactive shells.
- `/etc/homebrew/brew.env`: covers every user but needs sudo and is outside the dotfiles' reach.

## Risks / Trade-offs

- [Risk] Uninstalling deletes files under the Homebrew prefix, outside `$HOME`. → Only the user's go; named formulae only; the dry-run list of `autoremove` is read before it runs; reinstalling any of them is one `brew install` (after lifting the ban).
- [Risk] `brew autoremove` removes unrelated unused formulae. → Reviewed with `--dry-run` first; anything beyond `libiscsi` and `libnl` makes the procedure fall back to naming them.
- [Risk] The ban blocks a formula that depends on a banned name. → The list is short; the refusal message names the dependency; entries are removed from the list on purpose; `brew deps --formula <wanted>` shows a formula's dependencies before it is wanted.
- [Risk] A quoted value in `brew.env` is taken literally and bans nothing. → The file has no quotes, a scenario checks it, and `brew config` shows the effective value.
- [Risk] The symlink target breaks if `~/.config` moves. → The target is relative and both files are managed together.
- [Risk] The hook's commit of the Brewfile surprises a later reader. → Expected and documented in `AGENTS.md`.
- [Trade-off] Two paths to one file, in exchange for a ban that holds in every kind of shell without sudo.

## Migration Plan

1. Write the two managed files; `chezmoi diff` shows only them.
2. With the user's go, run the removal procedure above.
3. Apply the two files alone.
4. Run the checks; record the brew hook's commit.

Rollback: `git revert` the files and `chezmoi apply` them; `brew install libvirt terraform-provider-libvirt` (after lifting the ban) restores the packages.

## Open Questions

- Which formulae of homebrew-core depend on a banned name (`brew uses` returned nothing without `--installed`)? Does any formula the user wants?
- Does `brew file install` (brew-file) report the ban clearly when a Brewfile line is on the list?

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
