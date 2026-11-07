## ADDED Requirements

### Requirement: Brew's libvirt stack is removed and shadows nothing

The Brewfile SHALL name none of the libvirt stack, Homebrew SHALL have none of `libvirt`, `terraform-provider-libvirt` or the dependencies only they needed installed, and the first `virsh` on `PATH` SHALL be the system one.

#### Scenario: Brewfile is clean

- **WHEN** `grep -c libvirt home/dot_config/brewfile/Brewfile` runs at the repository root
- **THEN** it prints 0

#### Scenario: Formulae are gone

- **WHEN** `brew list --formula | grep -cE '^(libvirt|terraform-provider-libvirt|libiscsi|libnl)$'` runs
- **THEN** it prints 0

#### Scenario: The system virsh answers

- **WHEN** `command -v virsh` runs, then `virsh -c qemu:///system list --all`
- **THEN** the first prints `/usr/bin/virsh` and the second exits 0

#### Scenario: Vagrant keeps its plugin

- **WHEN** `vagrant plugin list | grep -c vagrant-libvirt` runs, then `ldd "$(find ~/.vagrant.d/gems -name _libvirt.so | head -1)" | grep -c 'not found'`
- **THEN** the first prints 1 and the second prints 0

#### Scenario: No formula lost a dependency

- **WHEN** `brew missing | grep -c .` runs
- **THEN** it prints 0

#### Scenario: Brewfile and target agree

- **WHEN** `chezmoi status ~/.config/brewfile/Brewfile` runs after the removal
- **THEN** it prints nothing

### Requirement: Brew is configured to refuse the banned formulae in every kind of shell

`~/.config/homebrew/brew.env` SHALL set `HOMEBREW_FORBIDDEN_FORMULAE` to `libvirt qemu terraform-provider-libvirt incus` and `HOMEBREW_FORBIDDEN_OWNER` to a text that names this repository, in plain `KEY=value` lines with no quotes, and `~/.homebrew/brew.env` SHALL be a relative symlink to it, both managed by chezmoi.

#### Scenario: File content

- **WHEN** `grep -c '^HOMEBREW_FORBIDDEN_FORMULAE=libvirt qemu terraform-provider-libvirt incus$' ~/.config/homebrew/brew.env` runs, then `grep -c '"' ~/.config/homebrew/brew.env`
- **THEN** the first prints 1 and the second prints 0

#### Scenario: Symlink

- **WHEN** `readlink ~/.homebrew/brew.env` runs
- **THEN** it prints `../.config/homebrew/brew.env`

#### Scenario: Managed

- **WHEN** `chezmoi managed | grep -cE '^\.(config/homebrew|homebrew)/brew\.env$'` runs, then `chezmoi status ~/.config/homebrew/brew.env ~/.homebrew/brew.env`
- **THEN** the first prints 2 and the second prints nothing

#### Scenario: Effective when XDG_CONFIG_HOME is set

- **WHEN** `env XDG_CONFIG_HOME="$HOME/.config" brew config | grep HOMEBREW_FORBIDDEN_FORMULAE` runs
- **THEN** its output holds `libvirt qemu terraform-provider-libvirt incus`

#### Scenario: Effective when XDG_CONFIG_HOME is not set

- **WHEN** `env -u XDG_CONFIG_HOME brew config | grep HOMEBREW_FORBIDDEN_FORMULAE` runs
- **THEN** its output holds `libvirt qemu terraform-provider-libvirt incus`

### Requirement: A banned formula is refused and other installs are unaffected

Homebrew SHALL refuse to install a banned formula, and any formula that depends on one, before downloading anything, and SHALL install unrelated formulae as before.

#### Scenario: Install is refused

- **WHEN** `brew install libvirt` runs after the removal and the ban files are applied
- **THEN** it exits non-zero, its error holds `forbidden`, and `brew list --formula | grep -c '^libvirt$'` prints 0

#### Scenario: The refusal names the owner

- **WHEN** the same command's error is searched for the text of `HOMEBREW_FORBIDDEN_OWNER`
- **THEN** it is found

#### Scenario: Unrelated installs still plan

- **WHEN** `brew install --dry-run jq` runs
- **THEN** it exits 0

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
