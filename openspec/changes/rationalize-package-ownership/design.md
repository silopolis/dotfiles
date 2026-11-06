## Context

Audit section 2.4 and F16, F28 (2026-10-30): brew 160 formulae plus one undeclared cask; mise 45 tools plus 48 stale versions; pipx 23 declared, 28 installed; krew 7; bin pinned at v0.21.2.
Overlaps include age, node, kubectl, k9s, stern, lazydocker, shellcheck, pre-commit, bat, direnv; mise `npm:` tools use brew's node; two chezmoi binaries (resolved in `harden-sensitive-targets`).
cem's checklist 6.1 describes the bin `.deb` flow (`~/.local/share/bin-debs/`, install with apt when newer) and 6.6 the Omarchy package diff.

## Goals / Non-Goals

**Goals:**

- `which -a <tool>` resolves to one manager for every declared tool.
- A single command shows drift for all managers.

**Non-Goals:**

- Moving everything from brew to mise in one go: tools move when mise has a good backend for them, the rest stays.
- GUI applications from vendor repositories (checklist 6.2), handled in cem.

## Decisions

### Ownership table in data

`.chezmoidata/packages.yaml` gains an `owners` map (tool to manager, optional reason) used by the drift report; the Brewfile, mise config and pipx spec stay the install sources.

### Drift report

`dot_local/bin/executable_pkg-drift` (or a mise task in cem) prints, per manager, undeclared installs and missing declarations; read-only.

### Removals one by one

Each removal from a non-owning manager is listed and approved before it runs; the brew hook commits Brewfile removals by itself.

## Risks / Trade-offs

- [Risk] Removing brew's node breaks mise `npm:` tools. → Move node to mise first and point mise's npm backend at it; reinstall the npm tools; check each.
- [Risk] brew formulae are dependencies of others (python versions). → `brew uses --installed <formula>` before any removal.
- [Risk] Two git binaries (brew 2.55, system 2.53 from apt). → brew's git stays: a dependency of `soft-serve` and used by Homebrew itself (`HOMEBREW_GIT`); the only mise source is `conda:git`, not evaluated.
  The pre-commit hook no longer depends on the git version, since `enforce-hook-with-system-git` installs it as a `.git/hooks` shim (measured 2026-11-06), so the owner of git can be chosen freely.

## Open Questions

- Does chezmoi itself move to mise?
- Is a cem mise task a better home for the drift report than a script here?

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
