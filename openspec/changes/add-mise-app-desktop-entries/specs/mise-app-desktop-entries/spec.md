## ADDED Requirements

### Requirement: Declared mise GUI applications

GUI applications installed by mise that need desktop integration SHALL be declared in `.chezmoidata/mise-apps.yaml` under a `mise_apps` map keyed by desktop file id, and Obsidian SHALL be declared with the id `obsidian`.

#### Scenario: Obsidian is declared

- **WHEN** `chezmoi data --format=json | jq -r '.mise_apps | keys[]'` runs
- **THEN** the output contains `obsidian`

### Requirement: Desktop entry per installed application

For each declared application whose binary exists in its mise install, a valid desktop entry SHALL exist at `~/.local/share/applications/<id>.desktop`.

#### Scenario: Obsidian entry is valid

- **WHEN** `desktop-file-validate ~/.local/share/applications/obsidian.desktop` runs after apply on a machine where mise has installed Obsidian
- **THEN** it exits with status 0 and prints no error

#### Scenario: Obsidian appears in the KDE menu

- **WHEN** `kbuildsycoca6` has run and `grep -alF 'obsidian.desktop' ~/.cache/ksycoca6_*` runs
- **THEN** it lists at least one cache file, and searching "Obsidian" in the KDE launcher shows the application

#### Scenario: Application not installed

- **WHEN** a declared application's binary is absent from its mise install and `chezmoi apply --exclude=scripts` runs
- **THEN** `~/.local/share/applications/<id>.desktop` does not exist

### Requirement: Launch path survives mise upgrades

The `Exec` key of each managed entry SHALL start the binary through the mise `latest` symlink of its install, by absolute path and not through the mise shim, and SHALL pass URLs with the `%U` field code.

#### Scenario: Exec target resolves

- **WHEN** the first word of the `Exec=` line of `~/.local/share/applications/obsidian.desktop` is checked with `test -x`
- **THEN** the check succeeds, and the path contains `/latest/` and not `/shims/`

#### Scenario: Exec passes URLs

- **WHEN** `grep '^Exec=' ~/.local/share/applications/obsidian.desktop` runs
- **THEN** the line ends with ` %U`

#### Scenario: Upgrade keeps the entry working

- **WHEN** `mise upgrade` installs a newer Obsidian and no apply is run
- **THEN** the `Exec` target still resolves with `test -x` and points into the new version through `latest`

### Requirement: Themed icon per installed application

For each declared and installed application, `~/.local/share/icons/hicolor/512x512/apps/<id>.png` SHALL be a symlink resolving to the icon inside the mise `latest` install, and the desktop entry SHALL reference it by name with `Icon=<id>`.

#### Scenario: Obsidian icon resolves

- **WHEN** `test -e ~/.local/share/icons/hicolor/512x512/apps/obsidian.png && readlink ~/.local/share/icons/hicolor/512x512/apps/obsidian.png` runs
- **THEN** the test succeeds and the link target contains `/latest/`

#### Scenario: Entry uses the themed name

- **WHEN** `grep '^Icon=' ~/.local/share/applications/obsidian.desktop` runs
- **THEN** it prints `Icon=obsidian`

### Requirement: URL scheme handlers

Each managed entry SHALL list the URL schemes declared for its application as `x-scheme-handler/<scheme>` in its `MimeType` key, and each scheme SHALL be the default association in `~/.config/mimeapps.list`.

#### Scenario: Obsidian handles obsidian links

- **WHEN** `xdg-mime query default x-scheme-handler/obsidian` runs after apply and cache refresh
- **THEN** it prints `obsidian.desktop`

#### Scenario: Scheme declared in the entry

- **WHEN** `grep '^MimeType=' ~/.local/share/applications/obsidian.desktop` runs
- **THEN** the value contains `x-scheme-handler/obsidian;`

#### Scenario: Link opens Obsidian

- **WHEN** `xdg-open 'obsidian://open'` runs in the desktop session
- **THEN** Obsidian starts or comes to the front, and no "address not understood" error is shown

#### Scenario: Removed association is restored

- **WHEN** the `x-scheme-handler/obsidian` line is deleted from `~/.config/mimeapps.list` and `chezmoi apply --exclude=scripts ~/.config/mimeapps.list` runs
- **THEN** `xdg-mime query default x-scheme-handler/obsidian` prints `obsidian.desktop` again, and the lines not declared in the repository are unchanged

### Requirement: Desktop caches refreshed on change

A `run_onchange_after_` script SHALL run `update-desktop-database ~/.local/share/applications` and `kbuildsycoca6` when a managed desktop entry or `mise-apps.yaml` changes, SHALL skip each command that is missing, and SHALL write nothing outside `$HOME`.

#### Scenario: Refresh after a data change

- **WHEN** an entry in `mise-apps.yaml` changes and `chezmoi apply --dry-run --verbose` runs
- **THEN** the refresh script is listed to run

#### Scenario: No refresh without change

- **WHEN** `chezmoi apply --dry-run --verbose` runs twice with no source change in between, after a real apply
- **THEN** the refresh script is not listed to run

#### Scenario: Refresh is idempotent

- **WHEN** the rendered refresh script is run twice in a row with `bash`
- **THEN** both runs exit with status 0

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
