## 1. Prerequisites

- [ ] 1.1 Check that `manage-xdg-basics` is archived and that `mimeapps.list` is managed by its `modify_` script (`openspec list | grep -c manage-xdg-basics` prints 0 and `chezmoi managed | grep -x '.config/mimeapps.list'` prints the target)
- [ ] 1.2 Check that Obsidian is installed by mise and record the install layout: binary, icon, window class (`ls ~/.local/share/mise/installs/github-obsidianmd-obsidian-releases/latest/{obsidian,resources/icon.png}`; start Obsidian and run `xprop WM_CLASS` on its window)
- [ ] 1.3 Snapshot the before state (`mkdir -p /tmp/opencode/mise-apps-before && xdg-mime query default x-scheme-handler/obsidian > /tmp/opencode/mise-apps-before/obsidian-handler; cp ~/.config/mimeapps.list /tmp/opencode/mise-apps-before/`)

## 2. Data and shared template

- [ ] 2.1 Create `.chezmoidata/mise-apps.yaml` with a `mise_apps` map; entry `obsidian`: name, comment, install directory `github-obsidianmd-obsidian-releases`, binary `obsidian`, icon `resources/icon.png`, categories `Office;`, schemes `[obsidian]`, `StartupWMClass` from 1.2; header comment on the public repository (`chezmoi data --format=json | jq -r '.mise_apps | keys[]'` prints `obsidian`)
- [ ] 2.2 Create `.chezmoitemplates/mise-app.desktop`: takes the id and the global data, computes the install root from `MISE_DATA_DIR` or `.chezmoi.homeDir`, renders nothing when `stat` finds no binary under `latest/`, else a desktop entry with `Exec=<root>/latest/<binary> %U`, `Icon=<id>`, `MimeType=x-scheme-handler/<scheme>;...`, `Categories`, `StartupWMClass`, `Terminal=false` (`chezmoi execute-template '{{ template "mise-app.desktop" (dict "id" "obsidian" "data" .) }}'`)
- [ ] 2.3 Check that the template renders empty for an absent install by testing it with a fake directory name in a temporary data override (`chezmoi execute-template --override-data '{"mise_apps":{"obsidian":{"dir":"nope"}}}' ... | wc -c` prints 0, adapting the override to the final data shape)

## 3. Targets

- [ ] 3.1 Create `dot_local/share/applications/obsidian.desktop.tmpl` calling the shared template (`chezmoi cat ~/.local/share/applications/obsidian.desktop | desktop-file-validate /dev/stdin` or validate a temporary copy; no error)
- [ ] 3.2 Create `dot_local/share/icons/hicolor/512x512/apps/symlink_obsidian.png.tmpl` rendering the absolute `latest/<icon>` path, or nothing when the binary is absent (`chezmoi cat ~/.local/share/icons/hicolor/512x512/apps/obsidian.png` prints a path containing `/latest/`)
- [ ] 3.3 Review the diff (`chezmoi diff --exclude=externals ~/.local/share/applications/obsidian.desktop ~/.local/share/icons/hicolor/512x512/apps/obsidian.png`)
- [ ] 3.4 Apply the two targets without scripts (`chezmoi apply --exclude=scripts ~/.local/share/applications/obsidian.desktop ~/.local/share/icons/hicolor/512x512/apps/obsidian.png && desktop-file-validate ~/.local/share/applications/obsidian.desktop`)
- [ ] 3.5 Check the launch path (`test -x "$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' ~/.local/share/applications/obsidian.desktop)" && grep -E '^Exec=.*/latest/.* %U$' ~/.local/share/applications/obsidian.desktop`)
- [ ] 3.6 Check the icon (`test -e ~/.local/share/icons/hicolor/512x512/apps/obsidian.png && grep -x 'Icon=obsidian' ~/.local/share/applications/obsidian.desktop`)
- [ ] 3.7 Propose commit `feat(sys:desktop): add desktop entries for mise gui apps, obsidian first`

## 4. Cache refresh script

- [ ] 4.1 Create `.chezmoiscripts/run_onchange_after_31-desktop-database.sh.tmpl`: Linux guard, hash comment of `mise-apps.yaml` and of the shared template, `set -euo pipefail`, `update-desktop-database "$HOME/.local/share/applications"` and `kbuildsycoca6`, each behind `command -v` (`chezmoi execute-template < .chezmoiscripts/run_onchange_after_31-desktop-database.sh.tmpl | bash -n && shellcheck -s bash <(chezmoi execute-template < .chezmoiscripts/run_onchange_after_31-desktop-database.sh.tmpl)`)
- [ ] 4.2 Run the rendered script twice by hand (`for i in 1 2; do chezmoi execute-template < .chezmoiscripts/run_onchange_after_31-desktop-database.sh.tmpl | bash || echo FAIL; done` prints no `FAIL`)
- [ ] 4.3 Check that KDE sees the entry (`grep -alF 'obsidian.desktop' ~/.cache/ksycoca6_*` lists a file; search "Obsidian" in the launcher; note in which menu folder it lands under the current Kali menu)
- [ ] 4.4 Review `chezmoi apply --dry-run --verbose` with the user: only the refresh script and the new targets are pending, no other script is listed (once `make-install-scripts-idempotent` is archived; until then, run only this script as in 4.2 and record it as run)
- [ ] 4.5 Propose commit `feat(sys:desktop): refresh desktop caches when mise app entries change`

## 5. URL scheme handler

- [ ] 5.1 Add the `mise_apps` schemes to the declared associations of the `mimeapps.list` `modify_` script, only for applications whose binary exists, as `x-scheme-handler/<scheme>=<id>.desktop` (`chezmoi cat ~/.config/mimeapps.list | grep -x 'x-scheme-handler/obsidian=obsidian.desktop'`)
- [ ] 5.2 Review and apply the single target (`chezmoi diff ~/.config/mimeapps.list` shows only the added line, then `chezmoi apply --exclude=scripts ~/.config/mimeapps.list`)
- [ ] 5.3 Check the handler (`xdg-mime query default x-scheme-handler/obsidian` prints `obsidian.desktop`)
- [ ] 5.4 Check restoration: delete the line from the live file, apply again, compare the rest (`sed -i '/^x-scheme-handler\/obsidian=/d' ~/.config/mimeapps.list && chezmoi apply --exclude=scripts ~/.config/mimeapps.list && xdg-mime query default x-scheme-handler/obsidian && chezmoi diff ~/.config/mimeapps.list` prints `obsidian.desktop` then nothing)
- [ ] 5.5 Check the link end to end (`xdg-open 'obsidian://open'` brings Obsidian up; then a Web Clipper capture in Firefox opens Obsidian, confirming the handler once in Firefox Settings, Applications, if asked)
- [ ] 5.6 Propose commit `feat(sys:xdg): declare obsidian as the obsidian:// handler`

## 6. Upgrade and absent install

- [ ] 6.1 After the next `mise upgrade` of Obsidian, without applying, check the entry and icon still resolve (`test -x "$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' ~/.local/share/applications/obsidian.desktop)" && test -e ~/.local/share/icons/hicolor/512x512/apps/obsidian.png`); if no upgrade is available, check that `latest` is a symlink to the versioned directory (`readlink ~/.local/share/mise/installs/github-obsidianmd-obsidian-releases/latest`)
- [ ] 6.2 Document in `.chezmoidata/mise-apps.yaml` the second apply needed on a fresh machine, because `make-install-scripts-idempotent` runs `mise install` in an after-script, once the targets are written (F02) (`grep -n F02 .chezmoidata/mise-apps.yaml`)

## 7. Close

- [ ] 7.1 Validate the change (`openspec validate add-mise-app-desktop-entries --strict`) and run `/opsx-verify add-mise-app-desktop-entries`
- [ ] 7.2 Archive (`openspec archive add-mise-app-desktop-entries --yes`); no cem checklist line exists for this change, so none is ticked (`grep -ci 'desktop entr' ~/Work/cles-en-main/migrations/2026-10-omalap-to-ulap01/checklist.md` prints 0)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
