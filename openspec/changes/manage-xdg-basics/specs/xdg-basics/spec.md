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

### Requirement: Declared autostart set

Only declared autostart entries managed by this repository SHALL be present, and each SHALL point to an installed application.

#### Scenario: Autostart entries resolve

- **WHEN** each managed file in `~/.config/autostart/` is checked with its `Exec` command and `command -v`
- **THEN** every command resolves

### Requirement: One user fontconfig file

The user font configuration SHALL live in one managed file.

#### Scenario: Single file

- **WHEN** `ls ~/.config/fontconfig/fonts.conf ~/.config/fonts.conf ~/.fonts.conf 2>/dev/null` runs
- **THEN** only the managed file and links to it exist

### Requirement: No private hosts in bookmarks

Managed bookmark files SHALL contain no private host names or addresses.

#### Scenario: Public-safe bookmarks

- **WHEN** the managed bookmarks source is searched for network schemes (`smb:`, `sftp:`, `ssh:`)
- **THEN** nothing is found, or the entries come from data outside the repository

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
