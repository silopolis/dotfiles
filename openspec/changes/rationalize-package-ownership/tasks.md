<!-- Draft tasks: refine at the start of the session (/opsx-continue rationalize-package-ownership); this change may split into one change per manager. -->

## 1. Inventory

- [ ] 1.1 Fresh lists per manager (brew leaves and casks, `mise ls`, `pipx list --short`, `kubectl krew list`, `bin ls`, apt manual installs relevant to tools)
- [ ] 1.2 Ownership table with the user: owner and reason per overlapping tool

## 2. Clean up

- [ ] 2.1 `mise prune --dry-run`, then `mise prune` with the user's go
- [ ] 2.2 pipx: declare or remove calcure, euporie, hike, ipython, pynvim (`pipx list --short` matches `packages.json`)
- [ ] 2.3 brew: decide the undeclared cask; remove duplicates owned elsewhere, one by one (`brew uses --installed` first)

## 3. Additions

- [ ] 3.1 Omarchy launchers to mise (checklist 4.5)
- [ ] 3.2 bin `.deb` flow and `sysupgrade.sh` step; bin config under chezmoi (checklist 6.1)
- [ ] 3.3 `bin` external refreshed or replaced
- [ ] 3.4 Omarchy package mapping report (checklist 6.6)

## 4. Drift report

- [ ] 4.1 Read-only drift command; empty on this machine

## 5. Close

- [ ] 5.1 Tick cem checklist 4.5, 6.1, 6.6; validate, verify, archive

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
