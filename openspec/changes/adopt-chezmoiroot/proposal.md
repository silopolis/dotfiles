## Why

With a flat layout, every repository-level file (agent guide, docs, specs, tool pins, hook config, bootstrap script, README) is a potential target and needs its own `.chezmoiignore` entry, and forgetting one deploys it into the home directory.
Moving the source state into `home/` with `.chezmoiroot` separates "what chezmoi deploys" from "how the repository is run", before the other changes start touching paths (decision in the audit `docs/audits/2026-10-30-environment.md`, section 5).

## What Changes

- Add `.chezmoiroot` containing `home`.
- `git mv` everything chezmoi reads into `home/`: `.chezmoi.toml.tmpl`, `.chezmoidata/`, `.chezmoiexternals/`, `.chezmoiignore`, `.chezmoiremove`, `.chezmoiscripts/`, `.chezmoitemplates/`, `dot_*`, `empty_*`, `symlink_*`, `key.txt.age`.
- Keep at the repository root: `.git*`, `.opencode/`, `AGENTS.md`, `README.md`, `TODO.md`, `docs/`, `openspec/`, `scripts/`, `mise.toml`, `hk.pkl` and any other tooling.
- Remove the now useless ignore entries (`README.md`, `TODO.md`, `scripts`, the temporary repository-files block).
- Replace the source paths hard-coded in scripts (`$HOME/.local/share/chezmoi/dot_config/...`) with `{{ .chezmoi.sourceDir }}`.
- Update `.gitignore`, `AGENTS.md` and `openspec/config.yaml` to the new layout.

## Capabilities

### New Capabilities

- `source-layout`: where the chezmoi source state lives inside the repository and what stays outside it.

### Modified Capabilities

None.

## Impact

- Every source path gains a `home/` prefix; targets, modes, contents and script state do not change.
- `chezmoi source-path` now points to `home/`; the brew hook and the `cm*` aliases use it, so they follow.
- `chezmoi cd` keeps opening the working tree (the repository root), so the `cmcd` alias changes to `cd "$(chezmoi source-path)"` to land in `home/`.
- Open changes and the audit refer to flat paths; readers prefix `home/` (stated in the audit and `AGENTS.md`).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
