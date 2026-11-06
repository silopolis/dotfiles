## Context

Audit finding F36 (`docs/audits/2026-10-30-environment.md`, section 2.8) lists the XDG basics as valuable and unmanaged.
State on the main machine, read on 2026-11-06:

- `~/.config/user-dirs.dirs` (mode 600) declares French folders (Bureau, Téléchargements, Modèles, Public, Documents, Musique, Images, Vidéos) plus `XDG_PROJECTS_DIR="$HOME/Projects"`; `user-dirs.locale` holds `fr_FR`.
  These folders are listed in `.chezmoiignore`, so chezmoi cannot create them as source directories.
  `xdg-user-dirs-update` resets an entry to `$HOME` when its folder is missing.
- `~/.config/mimeapps.list` holds the Firefox ESR and Element defaults in `[Default Applications]`, and the Firefox ESR entries again in `[Added Associations]`.
  KDE and applications rewrite it; `add-mise-app-desktop-entries` will add the `obsidian://` handler to it.
- `~/.config/autostart/` holds Nextcloud, Insync, kitty, Firefox ESR, and `fix-old-genmon-config.desktop`, copied from Kali's `/etc/skel` and limited to XFCE.
  Mattermost, the one entry the migration decided on, is not installed yet.
- `~/.config/gtk-3.0/bookmarks` holds 22 `file://` entries and no network scheme, but several path names name clients, employers or schools; two folders no longer exist.
- Two fontconfig files disagree.
  The system fontconfig, used by KDE and every GUI application, reads only `~/.config/fontconfig/fonts.conf`: about 450 lines written by the KDE Fonts page, repeated blocks where the last ones win (hinting off, `hintnone`, rgba none, antialias on), plus Droid Sans Fallback and Noto Color Emoji appended to the generic families.
  The managed `~/.config/fonts.conf`, reached through the `~/.fonts.conf` symlink, is read only by brew's fontconfig, whose `50-user.conf` still includes the deprecated path; it says `hintslight`.
  The `fc-match` first on `PATH` is brew's, so checks must call `/usr/bin/fc-match`.

The only precedent for merging into a file that applications also write is `dot_config/VSCodium/User/modify_settings.json`.

## Goals / Non-Goals

**Goals:**

- A new machine gets the French user folders, the reviewed default applications, the declared autostart entries, the sidebar bookmarks and one font configuration from one apply.
- Choices the desktop writes on its own (associations, undeclared autostart files) survive an apply.
- No private name reaches the public repository.
- Mattermost is installed from its vendor APT repository, so its autostart entry has something to start.

**Non-Goals:**

- KDE preferences (`kdeglobals`, `kcmfonts`, Dolphin places in `user-places.xbel`): `manage-kde-desktop-config`.
- Installing the terminal fonts: `install-terminal-fonts`.
- Owning the package channel rules or a generic vendor-repository mechanism: `rationalize-package-ownership`.
- Deleting undeclared autostart files.
- Moving the encrypted bookmark fragment into the private store (see Open Questions).

## Decisions

### One data file per resource type

Each XDG resource type has its own data file, with its own top-level key:

| File | Key | Content |
| --- | --- | --- |
| `.chezmoidata/xdg-user-dirs.yaml` | `xdg_user_dirs` | XDG name to folder, relative to the home directory |
| `.chezmoidata/xdg-mime.yaml` | `xdg_mime_defaults` | MIME type or scheme to desktop file id |
| `.chezmoidata/xdg-autostart.yaml` | `xdg_autostart` | entry id to file name, name, command, arguments, icon, extra keys |
| `.chezmoidata/xdg-bookmarks.yaml` | `xdg_bookmarks` | public bookmarks only: path relative to the home directory, optional label |

Templates read them; adding an association or an autostart entry is a data edit in one small file, reviewed on its own.
The fontconfig file has no data file: it is a plain target.
The bookmarks file opens with a comment stating that the repository is public and that private entries never go there.

Distinct top-level keys, instead of one `xdg` map split across files, keep each file independent of how chezmoi merges data files.

Alternatives:

- One `xdg.yaml` with four sections: a single file mixes unrelated reviews and grows with every association `add-mise-app-desktop-entries` and later changes add.
- Values written inline in each target: `add-mise-app-desktop-entries` needs a list it can extend.

### User directories

- `dot_config/private_user-dirs.dirs.tmpl` renders one `XDG_<NAME>_DIR="$HOME/<folder>"` line per `xdg_user_dirs` entry, keeping the header comment of `xdg-user-dirs-update`; `private_` keeps the live mode 600.
- `dot_config/user-dirs.locale` is a plain file holding `fr_FR`.
- `.chezmoiscripts/run_onchange_after_30-xdg-user-dirs.sh.tmpl` runs `mkdir -p` on each declared folder, so `xdg-user-dirs-update` never resets an entry; it embeds the data, so it runs again only when the list changes.
  It writes only under `$HOME` and creates nothing that exists.

Alternative: create the folders as source directories with a `.keep` file.
Rejected because they are ignored targets, and un-ignoring them would bring their content into `chezmoi unmanaged` and `status`.

### Default applications through a `modify_` template

`dot_config/modify_mimeapps.list` is a `chezmoi:modify-template`, like the VSCodium one.
It reads the live file from `.chezmoi.stdin` and goes through it line by line:

- inside `[Default Applications]`, a declared key gets the declared value, whatever the live value was;
- at the end of that section, declared keys that were not seen are appended, in data order;
- if the section is missing, it is created first in the file;
- every other line (undeclared keys, `[Added Associations]`, `[Removed Associations]`, comments, blank lines) is copied as it is;
- the output ends with exactly one newline, so a file that already matches gives the same bytes and `chezmoi diff` stays empty.

The declared list is `xdg_mime_defaults`, reviewed in this change: the ten Firefox ESR web types and schemes and the two Element schemes kept today, each checked against an installed desktop file.
`add-mise-app-desktop-entries` adds its `x-scheme-handler/<scheme>=<id>.desktop` keys to the same list in the template, from its own data; this change exposes the list and nothing else.
`[Added Associations]` is not enforced: it only adds applications to "Open with", and KDE keeps it in line.

Alternatives:

- A plain or templated full file: every association the desktop adds shows as drift and is erased on apply.
- A `modify_` script in Python or `crudini`: an extra runtime dependency in a bootstrap path, for a line-oriented format that template functions handle.

### Autostart entries

One target per entry, `dot_config/autostart/<file>.desktop.tmpl`, each a one-line call to the shared snippet `.chezmoitemplates/autostart.desktop` with the entry id.
The snippet reads `xdg_autostart.<id>` (file name, name, command, arguments, icon, extra keys) and renders nothing when `lookPath` does not find the command; chezmoi then leaves the target absent.
Declared: Mattermost, kitty, Nextcloud (`--background`), Insync (`start --no-daemon`), Firefox ESR.
File names are the ones each application writes when its own "start at login" option is used (`Nextcloud.desktop`, `insync.desktop`, `kitty.desktop`, `firefox-esr.desktop`; Mattermost's is read after its install), so toggling that option shows as drift instead of creating a second entry.
Firefox ESR starts through `firefox-esr`, the command on `PATH`, instead of the `/usr/lib` path in the live file.
Undeclared files, `fix-old-genmon-config.desktop` included, stay unmanaged.

Alternative: one plain file per entry.
Rejected because a missing application would still get an entry that fails at login, which the spec forbids.

### Mattermost from its vendor APT repository

Rule order puts a vendor APT repository before Flatpak, and the GitHub `.deb` pipeline through bin does not exist yet.
The install is a supervised manual task, run with the user's go, not a chezmoi script:

1. read the repository address, the signing key and the package name from Mattermost's documentation at that time;
2. write the keyring under `/etc/apt/keyrings/` and a deb822 `.sources` file under `/etc/apt/sources.list.d/` with `Signed-By`, each only if absent, and compare the key fingerprint with the documented one;
3. `apt update`, `apt install` the desktop package, then record the command it installs and the autostart file name it writes.

A note in the `rationalize-package-ownership` proposal records the repository, so that change takes it into its declared vendor repositories.

Alternatives: a release `.deb` installed once (no updates until the bin pipeline exists), Flatpak (lower in the rule order), a separate change (the autostart entry would stay inert).

### One fontconfig file

`dot_config/fontconfig/fonts.conf` is a plain file, the path every fontconfig reads, with the values chosen with the user on 2026-11-06:

- antialias on;
- rgba `none` (greyscale, no colour fringes);
- hinting on, hintstyle `hintslight`;
- Droid Sans Fallback and Noto Color Emoji appended, weak binding, to monospace, serif and sans-serif.

The `<dir>` entries of the old file are dropped: the system configuration already lists `~/.fonts` and the XDG fonts folder.
`dot_config/fonts.conf` and `symlink_dot_fonts.conf` leave the source state, and `.chezmoiremove` lists `.fonts.conf` and `.config/fonts.conf`.
Brew's fontconfig reads the XDG path as well, so both stacks use one file.

Alternative: keep `~/.fonts.conf` pointing at the new file.
Rejected because brew's fontconfig would load the file twice and the deprecated path would stay.

### Bookmarks: public data plus a private fragment

`dot_config/gtk-3.0/bookmarks.tmpl` writes the public entries from `xdg_bookmarks`, paths joined to `.chezmoi.homeDir`, each with its optional label, then the private entries:

- from `~/.local/share/chezmoi-private/gtk/bookmarks` when that file exists (the store of `add-private-store-external`);
- else from `.private/gtk-bookmarks.age`, an age-encrypted fragment in the source state, read with `include` and `decrypt` and the existing key.

chezmoi ignores dot-prefixed source entries other than its own, so the fragment is never deployed.
The sidebar order becomes public entries, then private ones.
Reviewed list: 21 entries; one stale private entry moves under `~/Work`, the other is dropped.
Paths with spaces or accents are written URL-encoded, as GTK writes them.

Alternatives: the whole file encrypted (nothing reviewable, every public entry hidden), or unmanaged (lost on a new machine).

## Risks / Trade-offs

- [Writes under `/etc/apt` and `apt install` with sudo] → manual task, run only with the user's go; each file is written only if absent and the key fingerprint is checked first; rollback is `apt remove` the package and delete the two files.
- [`.chezmoiremove` deletes `~/.fonts.conf` and `~/.config/fonts.conf`] → both are copied to a dated backup first; their content is in git; the new file is applied and checked before the removal runs.
- [Replacing the KDE-written fontconfig file changes rendering from `hintnone` to `hintslight`] → the user chose it; the old file is backed up; `/usr/bin/fc-match -v sans-serif` shows the values.
- [The KDE Fonts page rewrites `fontconfig/fonts.conf` on Apply] → shows as drift in `chezmoi diff`; the user decides between `chezmoi re-add` after review and apply.
- [The `modify_` template rewrites the live `mimeapps.list` and could drop lines] → it copies every undeclared line; its output is compared with the live file before the first apply, and the file is backed up.
- [An autostart command is missing, so its target renders empty] → chezmoi removes a managed target that renders empty; this only touches files this change manages, and an entry comes back when the application is installed.
- [Apps rewrite their autostart files with other keys] → shows as drift; the data takes the keys the application writes.
- [The `run_onchange` script runs only on a full apply, which is blocked until `make-install-scripts-idempotent` is archived] → the task runs the same `mkdir -p` by hand; the script is for new machines.
- [Private names leak into the public part] → a check greps the plain source for the private names read from the decrypted fragment, without printing them.
- [The encrypted fragment and the private store disagree] → the store wins when present; the fragment is deleted once the store has the file.
- [Brew's `fc-match` comes first on `PATH`] → checks call `/usr/bin/fc-match`.

## Migration Plan

Order: after `adopt-chezmoiroot` (paths under `home/`); the targets are applied one by one with `--exclude=scripts`.

1. Back up the six live targets and the two old font files to a dated scratch folder.
2. Add the four data files and the templates; compare each `chezmoi cat` with the live file.
3. Apply `user-dirs.*`, run the folder creation by hand, check with `xdg-user-dir`.
4. Apply `mimeapps.list`; check with `xdg-mime query default`, then the restoration and keep scenarios.
5. Apply the bookmarks; check the private part comes from the fragment.
6. Apply the fontconfig file, check with `/usr/bin/fc-match -v`, then remove the old files through `.chezmoiremove` with the user's go.
7. Install Mattermost (manual task, with the user's go), add its entry, apply the autostart targets.

Rollback: copy the backups back and remove the new source entries; for Mattermost, see Risks.

## Open Questions

- Mattermost's command and autostart file name: read after its install (step 7).
- Deleting the encrypted bookmark fragment: done by the change that creates the private store, or by a dedicated migration change if several items move into the store.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
