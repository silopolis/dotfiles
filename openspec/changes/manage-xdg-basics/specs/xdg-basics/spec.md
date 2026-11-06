## ADDED Requirements

### Requirement: XDG user directories

The XDG user directory names SHALL be declared in the source state.

#### Scenario: Download directory

- **WHEN** `xdg-user-dir DOWNLOAD` runs after apply
- **THEN** it prints the declared directory

### Requirement: Default applications

Default application associations SHALL be declared and reviewed.

#### Scenario: Browser association

- **WHEN** `xdg-mime query default x-scheme-handler/https` runs after apply
- **THEN** it prints the declared desktop file

#### Scenario: Missing default restored

- **WHEN** a declared key is deleted from `[Default Applications]` in `~/.config/mimeapps.list` and `chezmoi apply --exclude=scripts ~/.config/mimeapps.list` runs
- **THEN** the key is back with its declared value and `chezmoi diff ~/.config/mimeapps.list` prints nothing

#### Scenario: Undeclared association kept

- **WHEN** an undeclared key is added to `~/.config/mimeapps.list` and `chezmoi apply --exclude=scripts ~/.config/mimeapps.list` runs
- **THEN** the key is still present with its value, and `[Added Associations]` is unchanged

### Requirement: Declared autostart set

Only declared autostart entries managed by this repository SHALL be present, and each SHALL point to an installed application.

#### Scenario: Autostart entries resolve

- **WHEN** each managed file in `~/.config/autostart/` is checked with its `Exec` command and `command -v`
- **THEN** every command resolves

#### Scenario: Mattermost starts at login once installed

- **WHEN** Mattermost desktop is installed from its vendor APT repository and the autostart targets are applied
- **THEN** a managed Mattermost entry exists in `~/.config/autostart/` and its command resolves

#### Scenario: Missing application has no entry

- **WHEN** the command of a declared entry is not found by `command -v` and its target is applied
- **THEN** no managed file exists for that entry

### Requirement: One user fontconfig file

The user font configuration SHALL live in one managed file at `~/.config/fontconfig/fonts.conf`, read by both the system and the brew fontconfig.

#### Scenario: Single file

- **WHEN** `ls ~/.config/fontconfig/fonts.conf ~/.config/fonts.conf ~/.fonts.conf 2>/dev/null` runs
- **THEN** only `~/.config/fontconfig/fonts.conf` is listed

#### Scenario: Declared rendering in effect

- **WHEN** `/usr/bin/fc-match -v sans-serif` runs
- **THEN** it shows `antialias: True`, `hinting: True`, `hintstyle: 1` (`hintslight`) and `rgba: 5` (`none`)

### Requirement: No private hosts in bookmarks

Managed bookmark sources in plain text SHALL contain no private host names, addresses or private folder names; private entries SHALL come from encrypted data or from the private store.

#### Scenario: Public-safe bookmarks

- **WHEN** the managed bookmarks source is searched for network schemes (`smb:`, `sftp:`, `ssh:`)
- **THEN** nothing is found, or the entries come from data outside the repository

#### Scenario: Private entries absent from plain sources

- **WHEN** the folder names of the decrypted private fragment are searched in the plain source state, without printing them
- **THEN** the search counts 0, and the applied `~/.config/gtk-3.0/bookmarks` still lists the private entries after the public ones

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
