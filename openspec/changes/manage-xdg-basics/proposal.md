## Why

Basic desktop plumbing is unmanaged: the French XDG user directories, default applications, autostart entries, GTK bookmarks and the user fontconfig file; `TODO.md` has listed some of them for months (audit finding F36).
They are small, rarely rewritten by applications, and needed on any new machine.

## What Changes

- Manage `~/.config/user-dirs.dirs` and `user-dirs.locale` (French names: Bureau, Téléchargements, ...).
- Manage `~/.config/mimeapps.list`, reviewing each association.
- Manage selected `~/.config/autostart/*.desktop` entries (the migration decided Mattermost only, plus the terminal and sync clients in use).
- Manage `~/.config/gtk-3.0/bookmarks` only if it holds no private host, else template it from data kept out of the public repository.
- Reconcile the two fontconfig files (`~/.config/fonts.conf`, managed, and `~/.config/fontconfig/fonts.conf`, unmanaged) into one.

## Capabilities

### New Capabilities

- `xdg-basics`: user directories, default applications, autostart and fontconfig.

### Modified Capabilities

None.

## Impact

- New plain targets; `TODO.md` entries closed.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
