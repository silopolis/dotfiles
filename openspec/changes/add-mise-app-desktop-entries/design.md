## Context

mise installs Obsidian from the upstream Linux tarball (`"github:obsidianmd/obsidian-releases" = "latest"` in `dot_config/mise/config.toml`).
The files land in `~/.local/share/mise/installs/github-obsidianmd-obsidian-releases/<version>/`, with mise-maintained symlinks (`latest`, `1`, `1.14`) pointing at the current version.
The install holds the `obsidian` Electron binary and a 512x512 `resources/icon.png`, but no desktop entry.
mise also exposes a shim, `~/.local/share/mise/shims/obsidian`, which is how the application is started today from a terminal.

Nothing under `~/.local/share/applications/` or `/usr/share/applications/` names Obsidian, so KDE shows no menu item and `xdg-mime query default x-scheme-handler/obsidian` returns nothing.
Firefox ESR asks the desktop for a handler on unknown schemes, finds none, and reports "The address wasn't understood".

`update-desktop-database`, `kbuildsycoca6`, `xdg-mime` and `desktop-file-validate` are installed.
Unprivileged user namespaces are enabled, so Electron's namespace sandbox works without a setuid `chrome-sandbox`.
`~/.config/mimeapps.list` is unmanaged today; `manage-xdg-basics` will bring it under management and must land first.

## Goals / Non-Goals

**Goals:**

- A menu entry, launcher entry and icon for each declared GUI application installed by mise, Obsidian first.
- `obsidian://` links open Obsidian from Firefox and from `xdg-open`.
- Entries keep working across `mise upgrade` without a new apply.
- Adding the next application is a data entry plus a one-line target file.

**Non-Goals:**

- Installing the applications: mise does that, outside this change.
- Managing `mimeapps.list` as a whole: that is `manage-xdg-basics`; this change only contributes its associations.
- Firefox profile state (`handlers.json`): the one-time confirmation is left to the user.
- `obsidian-cli`, vault configuration, Web Clipper settings.
- Applications installed by other channels (apt, Flatpak, bin), which ship their own desktop entries.
- The layout of the KDE menu: the `kali-menu` package merges `/etc/xdg/menus/applications-merged/kali-applications.menu` into it and hides the upstream categories (no Office folder today).
  Moving the Kali tools into a submenu and restoring the upstream Plasma categories is a separate change, to be created later.
  This change uses the standard freedesktop `Categories` (`Office;` for Obsidian), so the entries land in the right folder once that change is done; until then they are found through launcher search.

## Decisions

### Declare applications as template data

A new `.chezmoidata/mise-apps.yaml` holds a `mise_apps` map keyed by desktop file id (`obsidian`), with: display name, comment, the mise install directory name, the binary and icon paths relative to the install, categories, MIME types and URL schemes, and the `StartupWMClass`.

The install directory name is written out (`github-obsidianmd-obsidian-releases`) rather than derived from the tool name, because the mapping from backend to directory is a mise implementation detail.

Alternative: hard-code each desktop entry.
Rejected because the next application would copy the whole file, and the scheme list would be duplicated between the desktop entry and `mimeapps.list`.

### One small target per application, one shared template

chezmoi maps one source file to one target, so each application gets `dot_local/share/applications/<id>.desktop.tmpl` containing a single `template` call to a shared `.chezmoitemplates/mise-app.desktop` with that application's data.
All the logic lives in the shared template.

Alternative: a script that writes every entry in a loop.
Rejected because the entries would leave chezmoi's view: no `chezmoi diff`, no `chezmoi managed`, no clean removal.

### Launch through the `latest` symlink, not the shim

`Exec` uses the absolute path `<mise data dir>/installs/<dir>/latest/<binary> %U`, rendered from `.chezmoi.homeDir` (or `MISE_DATA_DIR` when set at apply time).

The shim was the alternative.
It also survives upgrades, but it starts mise on every launch, resolves the version from the working directory (KDE starts applications from `$HOME`, but a project `mise.toml` could pin something else), and fails if mise is not on the session `PATH`.
The `latest` symlink is maintained by mise on install and prune, needs no process, and does not depend on the environment the desktop session inherited.

`%U` passes URLs and files, which is what makes the scheme handler work.

### Icon through a symlink into the user hicolor theme

`dot_local/share/icons/hicolor/512x512/apps/<id>.png` is a chezmoi `symlink_` target pointing at `latest/<icon>` in the install, and the desktop entry says `Icon=<id>`.
The icon follows upgrades and is found by name like any themed icon.

Alternatives: an absolute `Icon=` path (works, but bypasses the theme and confuses some launchers), or a copy committed to the repository (goes stale and puts a vendor asset in a public repository).

### Render only what is installed

The shared template and the icon symlink check, with chezmoi's `stat`, that the binary exists in the install; when it does not, the target renders empty and chezmoi removes it.
This avoids a menu item that cannot start and a dangling icon link on a machine where mise has not installed the application yet.
The cost is that a fresh machine needs a second apply after `mise install` (see Risks).

### URL schemes in the desktop entry and in `mimeapps.list`

The desktop entry lists `MimeType=x-scheme-handler/obsidian;`, which is enough for `update-desktop-database` to offer Obsidian as a handler.
The explicit default in `[Default Applications]` of `mimeapps.list` is added as well, so the association does not depend on cache ordering and is reviewable in one place, as the user chose.

The lines are produced from the same `mise_apps` data.
`manage-xdg-basics` manages `mimeapps.list` through a `modify_` script (decided with the user on 2026-11-06), on the model of `dot_config/VSCodium/User/modify_settings.json.tmpl`:

- it reads the live file on standard input and writes the result on standard output;
- every declared association is enforced: a missing key is added back, creating its section if needed, and a key with another value is reset to the declared one;
- keys that are not declared are kept as they are, so choices made in KDE or Firefox survive;
- the output is stable (no change when the live file already matches), so `chezmoi diff` stays empty after an apply.

This change does not touch the script: it only feeds it, by having the script's list of declared associations include one `x-scheme-handler/<scheme>=<id>.desktop` entry per scheme in `mise_apps`, for applications that pass the installed check.

Alternative: a plain or templated full file.
Rejected because every association added by the desktop would show as drift and be erased on the next apply.

### Refresh caches from an after script

`.chezmoiscripts/run_onchange_after_30-desktop-database.sh.tmpl` embeds a hash of the rendered entries and of `mise-apps.yaml`, so it runs only when they change.
It runs `update-desktop-database ~/.local/share/applications` and `kbuildsycoca6`, each guarded by `command -v`, and touches nothing outside `$HOME`.
Both commands are idempotent.

## Risks / Trade-offs

- [Fresh machine: entries are skipped on the first apply because mise has not installed the application yet] → the mise install block in `05-install` is commented out today (F02); once `make-install-scripts-idempotent` runs mise before the targets, a single apply suffices; until then, document the second apply in the tasks.
- [`latest` symlink missing or stale after a manual cleanup of `installs/`] → `mise install` recreates it; the entry check in the specs (`desktop-file-validate`, `Exec` path exists) shows the problem.
- [mise renames the install directory scheme in a future release] → the directory is explicit data, one line to fix; the existence check keeps the menu clean meanwhile.
- [A later apt or Flatpak install of Obsidian ships its own `obsidian.desktop`] → the user entry under `~/.local/share/applications` takes precedence; drop the application from `mise_apps` when switching channels.
- [KDE or Firefox rewrites `mimeapps.list` and drops or changes the line] → the `modify_` script of `manage-xdg-basics` adds it back on the next apply; `chezmoi diff` shows the gap meanwhile, and the `xdg-mime query` scenario detects it.
- [Firefox keeps a stale "always ask" or "do nothing" choice for `obsidian`] → one-time fix in Firefox Settings, Applications; not managed because it is profile state.
- [Electron sandbox fails on a machine where unprivileged user namespaces are disabled] → not worked around with `--no-sandbox`; the same failure would already affect the shim, and it is a host setting outside this change.
- No step uses sudo, writes outside `$HOME`, uninstalls or deletes, apart from chezmoi removing a target this change created when its application is gone.

## Migration Plan

1. Land `manage-xdg-basics` (owner of `mimeapps.list`).
2. Add the data, shared template, per-application target, icon symlink and after script.
3. Preview with `chezmoi diff --exclude=externals`, then apply the new targets with `--exclude=scripts`, then run the refresh script once by hand or apply it alone.
4. Check: menu entry visible, `xdg-mime query default x-scheme-handler/obsidian` prints `obsidian.desktop`, a Web Clipper link opens Obsidian.

Rollback: remove the application from `mise_apps` (targets render empty and are removed) or forget the targets, then rerun the refresh commands.

## Open Questions

None.
Resolved on 2026-11-06:

- `mimeapps.list` is managed by a `modify_` script in `manage-xdg-basics` that enforces declared associations, adding missing ones back, and keeps the others.
- `mise_apps` stays in its own `.chezmoidata/mise-apps.yaml`; moving it into a central package file later, if `rationalize-package-ownership` creates one, is a small edit.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
