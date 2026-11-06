## Why

Basic desktop plumbing is unmanaged: the French XDG user directories, default applications, autostart entries, GTK bookmarks and the user fontconfig file; `TODO.md` has listed some of them for months (audit finding F36).
They are small, rarely rewritten by applications, and needed on any new machine.

## What Changes

- Manage `~/.config/user-dirs.dirs` and `user-dirs.locale` (French names: Bureau, Téléchargements, ...).
- Manage `~/.config/mimeapps.list`, reviewing each association, through a `modify_` script: declared associations are enforced (missing ones added back, changed ones reset) and undeclared ones written by KDE or applications are kept (decided 2026-11-06; `add-mise-app-desktop-entries` adds its scheme handlers to the declared list).
- Manage selected `~/.config/autostart/*.desktop` entries: Mattermost, kitty, Nextcloud, Insync and Firefox ESR, each rendered only when its command is installed; undeclared entries stay unmanaged.
- Install Mattermost desktop from its vendor APT repository, as a supervised task run with the user's go, so its autostart entry has something to start.
- Manage `~/.config/gtk-3.0/bookmarks` as a template: public entries from data in the repository, private entries from an age-encrypted fragment until the private store holds them.
- Reconcile the two fontconfig files into one managed `~/.config/fontconfig/fonts.conf` (antialias, greyscale, `hintslight`, emoji and CJK fallbacks); `~/.fonts.conf` and `~/.config/fonts.conf` are removed.

## Capabilities

### New Capabilities

- `xdg-basics`: user directories, default applications, autostart and fontconfig.

### Modified Capabilities

None.

## Impact

- New data files, one per resource type (`.chezmoidata/xdg-user-dirs.yaml`, `xdg-mime.yaml`, `xdg-autostart.yaml`, `xdg-bookmarks.yaml`), templates for the targets, a shared autostart snippet, a `run_onchange_after` script creating the user folders, an encrypted bookmark fragment; `TODO.md` entries closed.
- Removed: `dot_config/fonts.conf`, `symlink_dot_fonts.conf`; `.chezmoiremove` gains their targets.
- Outside `$HOME`: the Mattermost keyring and APT sources file under `/etc/apt`, and the package; `rationalize-package-ownership` takes the repository into its declared vendor repositories.
- Font rendering in GUI applications changes from `hintnone` to `hintslight`.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
