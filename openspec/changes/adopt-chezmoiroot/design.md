## Context

- chezmoi reads `.chezmoiroot` at the top of the working tree and takes the source state from the directory it names; `.chezmoi.toml.tmpl` and every special file are then read from that directory.
- `.chezmoi.sourceDir` becomes `~/.local/share/chezmoi/home`; `.chezmoi.workingTree` stays `~/.local/share/chezmoi`.
- Entry state (what chezmoi last wrote) is keyed by target path and script state by script content hash, so a pure move changes neither.
- Source paths are used by:
  - `run_onchange_before_decrypt-private-key.sh.tmpl:5` (`{{ .chezmoi.sourceDir }}/key.txt.age`), fine if `key.txt.age` moves too; its rendered path gains `/home`, so its hash changes and it shows as pending once, a no-op while `~/.config/chezmoi/key.age` exists;
  - `run_onchange_before_05-install.sh.tmpl:18,73` (hard-coded `$HOME/.local/share/chezmoi/dot_config/...`), breaks;
  - `include` calls in scripts (relative to the source dir), fine;
  - `dot_config/shell/rc.d/110-pkg_brew.sh:67-89` (brew hook: `chezmoi source-path`, then `git -C "$repo"` with a path relative to it), fine since git resolves paths from the subdirectory;
  - `dot_config/shell/aliases:173-181` (`cm*` aliases through `chezmoi source-path`), fine;
  - `.chezmoidata/vscodium.yaml:1` comment, cosmetic.
- `.gitignore:7` names `dot_config/tmux/plugins`.

## Goals / Non-Goals

**Goals:**

- A move with no effect on any target.
- No repository file can become a target by accident.

**Non-Goals:**

- Fixing the scripts beyond their source paths (change `make-install-scripts-idempotent`).
- Changing `scripts/install.sh` behaviour (change `fresh-machine-bootstrap`; note that it passes `--source=<scripts dir>`, already wrong today).

## Decisions

### Directory name `home`

The name used in chezmoi's own documentation; it reads as "what ends up in `$HOME`".

### `key.txt.age` moves into `home/`

It stays next to the other source files so the decrypt script keeps `{{ .chezmoi.sourceDir }}/key.txt.age`, and keeps its ignore entry.
Alternative considered: keep it at the root and use `{{ .chezmoi.workingTree }}`; rejected because the key belongs to the source state's bootstrap, not to the repository tooling.

### One commit for the move, one for the edits

The `git mv` commit contains renames only (100% similarity), so `git log --follow` and blame keep working; path fixes and ignore cleanup come in a second commit.

## Risks / Trade-offs

- [Risk] A missed special file stays at the root and silently stops being read. → Compare `chezmoi managed`, `chezmoi status`, `chezmoi data` and `chezmoi diff --exclude=externals` before and after; any difference stops the change.
- [Risk] Externals re-download because their state looks new. → Externals state is keyed by target; check `chezmoi status` shows no new external entries and run `chezmoi apply --dry-run --verbose --include=externals` to confirm.
- [Risk] The brew hook commits from the wrong directory. → Replay it in a scratch clone (as done on 2026-10-26 for its first version) before relying on it.
- [Trade-off] Every open change refers to flat paths; the `home/` prefix rule is written once in `AGENTS.md` and the audit instead of editing every change.

## Migration Plan

1. Snapshot: `chezmoi managed`, `chezmoi status`, `chezmoi data --format=json`, `chezmoi diff --exclude=externals` into `/tmp/opencode/chezmoiroot-before/`.
2. `git mv` the listed entries into `home/`, write `.chezmoiroot`, commit.
3. Fix paths and ignores, commit.
4. Snapshot again and diff.

Rollback: `git revert` both commits; nothing outside the repository changed.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
