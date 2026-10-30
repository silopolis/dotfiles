## Context

Scripts on commit `191ee9e` (paths under `home/` after `adopt-chezmoiroot`), see audit section 2.3:

- `run_onchange_before_00-pre-requesites.sh.tmpl`: not templated, no guard, `sudo apt-get update` and install of 12 packages on every content change.
- `run_onchange_before_05-install.sh.tmpl` (linux branch):
  - line 5: escaped, inert mise hash;
  - lines 11, 15-16: `ulimit -n 20480`, then overwrites `/etc/security/limits.d/ulimit.conf` with 20480/40960 (live: 32768/65536);
  - lines 18-28: brew-file variables, `HOMEBREW_BREWFILE` pointing into the source, `Brewfile.backup` spelling differs from the config's `brewfile.backup`;
  - lines 30-32: Homebrew plus brew-file through brew-file's installer, then `brew shellenv` from a literal path;
  - lines 39-41: Brewfile hash, `brew file install`, `brew file clean -V warning` (uninstalls undeclared packages, untaps, wipes the cache);
  - line 49: `rustup default stable`;
  - lines 52-68: mise block, commented out;
  - lines 70-73: pipx hash and `pipx install-all` from the source path;
  - lines 75-79: `vim +PluginInstall +qall` (before Vundle and vimrc exist on a new machine), YouCompleteMe `install.py --all`;
  - lines 81-82: `gh auth login` when not logged in, `gh extension install github/gh-copilot`.
- `run_onchange_before_10-install-packages.sh.tmpl`: `kubectl krew install` of all 7 plugins (darwin: `brew bundle`).
- `run_onchange_before_decrypt-private-key.sh.tmpl`: literal home path; sorts after `10-` today.
- `run_onchange_after_20-vscodium-extensions.sh.tmpl`: good list logic; `.vsix` loop at lines 23-26 reinstalls every time.
- `run_onchange_after_bat-cache-build.sh.tmpl`: escaped, inert hash at line 5.

chezmoi runs `run_before_` scripts, then updates files and externals, then `run_after_` scripts, each group in name order.
`run_onchange_` state is keyed by the rendered content's hash: any edit makes the script run once more; renaming alone does not.

## Goals / Non-Goals

**Goals:**

- Every script is safe to run at any time: idempotent, non-interactive, no removals, sudo only when a change is needed.
- Every script re-runs exactly when its declared input changes.
- Scripts can be exercised without side effects (dry-run mode).

**Non-Goals:**

- Changing which packages are declared or which manager owns a tool (change `rationalize-package-ownership`).
- Distro and profile data beyond a Debian-family guard (change `fresh-machine-bootstrap`).
- macOS branches: kept as they are, untested.

## Decisions

### New script set

| Script | Phase | Trigger (hashed input) | Does |
| --- | --- | --- | --- |
| `run_onchange_before_00-prerequisites.sh.tmpl` | before | `packages.linux.apt` | Debian family only; installs missing apt packages; sudo only if some are missing |
| `run_onchange_before_01-decrypt-private-key.sh.tmpl` | before | content | unchanged logic, `$HOME` instead of a literal path |
| `run_onchange_before_02-system-limits.sh.tmpl` | before | `system.limits` | writes the limits file only when it differs and never with lower values; sudo only then |
| `run_onchange_after_10-brew.sh.tmpl` | after | Brewfile | Homebrew and brew-file if missing; `brew file install` against the deployed `~/.config/brewfile/Brewfile`; prints `brew file clean --dry-run` output as a report; `rustup default stable` only when no default toolchain |
| `run_onchange_after_11-mise.sh.tmpl` | after | `dot_config/mise/config.toml` | `mise install --yes` |
| `run_onchange_after_12-pipx.sh.tmpl` | after | `packages.json` | installs only venvs missing from `pipx list --short`, through a filtered copy of the spec file |
| `run_onchange_after_13-krew.sh.tmpl` | after | `packages.linux.krews` | installs only missing plugins (darwin `brew bundle` part kept in its own darwin branch) |
| `run_onchange_after_20-vscodium-extensions.sh.tmpl` | after | extension list | as today; `.vsix` skipped when its `publisher.name` is installed |
| `run_onchange_after_30-vim-plugins.sh.tmpl` | after | `dot_config/vim/vimrc` | `vim -Es -u ~/.vimrc +PluginInstall +qall`; YouCompleteMe build only when `vim.ycm_build` is true and the core library is missing |
| `run_onchange_after_90-bat-cache.sh.tmpl` | after | `dot_config/bat/config`, `.chezmoiexternals/bat.toml.tmpl` | `bat cache --build` |

Hash lines use `{{ include "<path>" | sha256sum }}` or `{{ .<data> | toJson | sha256sum }}`; nothing escaped.
Package managers move to after-scripts so they read deployed files (Brewfile, `packages.json`, `vimrc`) instead of source paths, and so vim plugins install after Vundle (an external) and the vimrc exist.

### Shared helper

`.chezmoitemplates/script-lib.sh`, included with `{{ template "script-lib.sh" . }}`, provides:

- `log` (prefixed with the script name, to stderr);
- `run` (executes, or prints when `CHEZMOI_SCRIPTS_DRY_RUN=1`);
- `as_root` (calls sudo through `run`, logs why);
- `have` (`command -v` wrapper);
- `set -euo pipefail`.

### No removals

Uninstalling stays a deliberate human action.
The brew script prints what `brew file clean` would remove so drift is visible on every run that matters.

### Data added to `.chezmoidata/packages.yaml`

- `packages.linux.apt`: the 12 packages of the prerequisites script (key `dpkgs` renamed, it is empty and unused).
- `system.limits.nofile`: `soft: 32768`, `hard: 65536` (live values on 2026-10-30).
- `vim.ycm_build: false`.
- `brew.prefix: /home/linuxbrew/.linuxbrew`, the only place the Homebrew prefix is written.

## Risks / Trade-offs

- [Risk] Every script runs once on the next apply because its content changed. → Each is a no-op on this machine by design; proved with dry-run mode and a sudo stub before the supervised apply.
- [Risk] Moving brew, pipx and mise to after-scripts means files that need those tools (templates calling `output "aqua"` and similar) render before the tools exist on a fresh machine. → Unchanged from today for this machine; a fresh machine is handled in `fresh-machine-bootstrap`, which may move only the brew bootstrap back to a before-script.
- [Risk] `pipx install-all` on a filtered file loses injected packages or Python pins. → Filter with `jq` on the `venvs` keys only, keeping each venv's full metadata.
- [Risk] Dropping `gh auth login` leaves a fresh machine without gh auth. → gh reads the token from the encrypted environment; the brew script logs a warning when `gh auth status` fails.
- [Trade-off] The dry-run variable is a local convention, not a chezmoi feature; documented in `AGENTS.md`.

## Open Questions

- Keep Vundle and the vim plugins at all, now that Neovim is the editor? (Default: keep, without YouCompleteMe.)
- Should the brew undeclared-package report also cover mise (`mise prune --dry-run`) and pipx? (Default: brew only here; the rest in `rationalize-package-ownership`.)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
