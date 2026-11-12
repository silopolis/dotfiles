## Context

Scripts on commit `6bf6881` (reviewed on 2026-11-12; since commit `191ee9e` only the layout move touched them, so every line number below holds), see audit section 2.3.
Paths are under `home/`, see spec `source-layout`.

- `run_onchange_before_00-pre-requesites.sh.tmpl`: not templated, no guard, `sudo apt-get update` and install of 12 packages on every content change (all 12 are installed).
- `run_onchange_before_05-install.sh.tmpl` (linux branch):
  - line 5: escaped, inert mise hash;
  - lines 11, 15-16: `ulimit -n 20480`, then overwrites `/etc/security/limits.d/ulimit.conf` with 20480/40960 (live: 32768/65536);
  - lines 18-28: brew-file variables, `HOMEBREW_BREWFILE` pointing into the source, `Brewfile.backup` spelling differs from the config's `brewfile.backup`;
  - lines 30-32: Homebrew plus brew-file through brew-file's installer, then `brew shellenv` from a literal path;
  - lines 39-41: Brewfile hash, `brew file install`, `brew file clean -V warning`;
  - line 49: `rustup default stable`;
  - lines 52-68: mise block, commented out;
  - lines 70-73: pipx hash and `pipx install-all` from the source path;
  - lines 75-79: `vim +PluginInstall +qall` (before Vundle and vimrc exist on a new machine), YouCompleteMe `install.py --all`;
  - lines 81-82: `gh auth login` when not logged in, `gh extension install github/gh-copilot`.
- `run_onchange_before_10-install-packages.sh.tmpl`: `kubectl krew install` of all 7 plugins (darwin: `brew bundle` of the darwin brews and casks, unrelated to krew).
- `run_onchange_before_decrypt-private-key.sh.tmpl`: literal home path; sorts after `10-` today; shows as pending today because `adopt-chezmoiroot` changed its rendered source path.
- `run_onchange_after_20-vscodium-extensions.sh.tmpl`: good list logic; `.vsix` loop at lines 23-26 reinstalls every time.
- `run_onchange_after_bat-cache-build.sh.tmpl`: escaped, inert hash at line 5.

What `brew file clean` does on Linux with brew-file 10.2.2: it uninstalls undeclared formulae, untaps undeclared taps, runs `brew cleanup` and deletes the brew cache.
It ignores casks on Linux (brew-file handles casks on macOS only), so the `whosthere` cask named in the audit is not removed by it, and it cannot be declared in a Linux Brewfile either.
Every one of those actions honours `--dry-run`, which prints `$ brew uninstall ...`, `$ brew untap ...`, `$ brew cleanup` and `$ rm -rf <cache>` and runs none of them.

chezmoi runs `run_before_` scripts, then updates files and externals, then `run_after_` scripts, each group in name order.
`run_onchange_` state is keyed by the target path of the script (`entryState` bucket, for example `.chezmoiscripts/05-install.sh`) and stores the hash of the rendered content: any edit makes the script run once more, and a renamed script has a new key, so it runs once too.
A script that renders empty or whitespace only is not run and is not listed as pending.
A script runs again after a failure, because chezmoi records only successful runs.
chezmoi sets `CHEZMOI=1` for the scripts it runs, and passes the `env` table of the config (the four brew-file variables) to them.

## Goals / Non-Goals

**Goals:**

- Every script is safe to run at any time: idempotent, non-interactive, no removals, sudo only when a change is needed.
- Every script re-runs exactly when its declared input changes.
- Scripts can be exercised without side effects (dry-run mode, harness).

**Non-Goals:**

- Changing which packages are declared or which manager owns a tool (change `rationalize-package-ownership`).
- Distro and profile data beyond a Debian-family guard (change `fresh-machine-bootstrap`).
- macOS branches beyond keeping them: the darwin brew bundle only moves, and is untested.
- Windows: a krew or brew script there needs PowerShell.

**Exceptions decided by the user on 2026-11-12, after the plan-mode review:**

- The krew script has one branch per operating system, with a shared list and per-system lists, and the darwin `brew bundle` call moves to the brew script.
- `packages.json` is synchronized with the installed venvs, in its own commit.
- `TODO.md` entries are called items instead of lines, and two backlog entries are added, each in its own commit.

## Decisions

### New script set

Numbering by kind: 0x before, 1x package managers, 2x editors, 3x user setup (`manage-xdg-basics` takes 30, `add-mise-app-desktop-entries` takes 31), 9x caches.

| Script | Phase | Trigger (hashed input) | Does |
| --- | --- | --- | --- |
| `run_onchange_before_00-prerequisites.sh.tmpl` | before | `packages.linux.apt` | Debian family only; installs missing apt packages; sudo only if some are missing |
| `run_onchange_before_01-decrypt-private-key.sh.tmpl` | before | content | same logic, `$HOME` instead of a literal path, the binary from `CHEZMOI_EXECUTABLE` |
| `run_onchange_before_02-system-limits.sh.tmpl` | before | `system.limits.nofile` | writes the limits file only when it differs and never with lower values; sudo only then |
| `run_onchange_after_10-brew.sh.tmpl` | after | Brewfile (darwin: brews and casks) | Homebrew and brew-file if missing; `brew file install` against the deployed `~/.config/brewfile/Brewfile`; reports undeclared formulae, taps and casks; `rustup default stable` only when no default toolchain; warns when gh is not logged in; darwin branch: `brew bundle` |
| `run_onchange_after_11-mise.sh.tmpl` | after | `dot_config/mise/config.toml` | `mise install --yes` |
| `run_onchange_after_12-pipx.sh.tmpl` | after | `dot_config/pipx/packages.json` | installs only venvs missing from `pipx list --short`, through a filtered copy of the spec file; reports undeclared venvs |
| `run_onchange_after_13-krew.sh.tmpl` | after | the combined plugin list | Linux and macOS; installs only missing plugins; reports undeclared plugins; renders empty when the list is empty |
| `run_onchange_after_20-vscodium-extensions.sh.tmpl` | after | extension list | as today; `.vsix` skipped when its `publisher.name` is installed |
| `run_onchange_after_21-vim-plugins.sh.tmpl` | after | `dot_config/vim/vimrc` | `vim -Es -u ~/.vimrc +PluginInstall +qall`; YouCompleteMe build only when `vim.ycm_build` is true and the core library is missing |
| `run_onchange_after_90-bat-cache.sh.tmpl` | after | `dot_config/bat/config`, `.chezmoiexternals/bat.toml.tmpl` | `bat cache --build` |

Hash lines use `{{ include "<path>" | sha256sum }}` (paths relative to `home/`) or `{{ .<data> | toJson | sha256sum }}`; nothing escaped.
Package managers move to after-scripts so they read deployed files (Brewfile, `packages.json`, `vimrc`) instead of source paths, and so vim plugins install after Vundle (an external) and the vimrc exist.
The bat hash covers the external declarations, not the upstream theme files, which the weekly refresh may change without re-running the script.
The `.vsix` directory is outside the repository, so adding a file there does not re-run the VSCodium script.

### Shared helper

`.chezmoitemplates/script-lib.sh` is included right after the shebang with `{{ template "script-lib.sh" "<script name>" }}`; it has no shebang of its own.
It holds no data beyond the script name: a script that needs data passes it to the function (`load_brew "{{ .brew.prefix }}"`), so a data change re-runs only the scripts that read it.
It provides:

- `set -euo pipefail`;
- `log` and `warn` (prefixed with the script name, to stderr);
- `have` (`command -v` wrapper);
- `run` (executes, or prints the command with `printf %q` when `CHEZMOI_SCRIPTS_DRY_RUN=1`; read-only queries are written without `run`, so they still execute);
- `as_root <why> <command...>` (logs why, then calls `run sudo`, or `run` directly when already root);
- `load_brew <prefix>` (gives the script the environment of the user's shell: it exports `XDG_CONFIG_HOME` with the default `~/.config` and evaluates `brew shellenv` from the prefix, which is the `brew.prefix` data, when `HOMEBREW_PREFIX` is not set, so that scripts after a first Homebrew install find the tools);
- `report_undeclared <what> <installed> <declared>` (lists installed names that are not declared, removes nothing);
- a warning when the dry-run variable is set while `CHEZMOI=1`.

`load_brew` exports `XDG_CONFIG_HOME` because Homebrew keeps its trust file in `$XDG_CONFIG_HOME/homebrew` and looks in `~/.homebrew` when the variable is unset.
Without the file, third-party taps are untrusted and brew-file lists the 20 installed tap formulae of the Brewfile as missing (found with the live harness: `brew file install --dry-run` printed a `brew install` line for them in a bare environment, and printed nothing once `XDG_CONFIG_HOME` was set).
A shell that sourced `rc.d` has the variable, but ssh commands, cron and `env -i` do not.

An edit to the helper changes every script that includes it, so each runs once more; all of them are no-ops on a provisioned machine.

### No removals, and a drift report

Uninstalling stays a deliberate human action.
Each package script ends with a read-only report of what is installed and undeclared:

- brew: the `$ brew uninstall` and `$ brew untap` lines of `brew file clean --dry-run` (formulae and taps), plus `brew list --cask` minus the `cask` lines of the Brewfile; on Linux that lists every installed cask, `whosthere` today;
- pipx: `pipx list --short` minus the keys of `packages.json`;
- krew: `kubectl krew list` minus the combined plugin list, ignoring `krew` itself.

mise is not covered: `mise prune --dry-run` lists stale versions, not undeclared tools, so it stays with `rationalize-package-ownership`.

### Brew script details

- It sources no `brew-wrap` and exports no brew-file variable: the config's `env` table passes `HOMEBREW_BREWFILE_BACKUP`, `FULL_NAME`, `LEAVES` and `ON_REQUEST`, and the Brewfile path defaults to `~/.config/brewfile/Brewfile`.
  `HOMEBREW_BREWFILE_TOP_PACKAGES` does not change the report on this machine (`gcc` is declared), so it is not exported either.
- When Homebrew is missing, the script runs brew-file's installer with `NONINTERACTIVE=1`; that installer calls sudo itself on a fresh machine, the one sudo that does not go through `as_root`.
### Before scripts

- The prerequisites script renders empty unless the os-release `id` is `debian` or `id_like` names it (Ubuntu, Kali, Mint), and when `packages.linux.apt` is empty; chezmoi neither runs nor lists an empty script.
  It checks each package with `dpkg-query` and calls sudo, for `apt-get update` and one `apt-get install`, only when a package is missing.
- The decrypt script uses the binary that is applying, through `CHEZMOI_EXECUTABLE`, which chezmoi sets for every script it runs, and falls back to `chezmoi` on `PATH` when the script is run by hand.
  A path rendered into the script would change after every chezmoi upgrade and make the script pending again, and `PATH` may not hold chezmoi on a fresh machine.
  It writes the identity with umask 077, so the file is never group-readable, then `chmod 600` as before.
- The limits script reads `system.limits.nofile`, checks at render time that both values are whole numbers with `0 < soft <= hard`, and renders empty when the data is absent.
  It compares the file with the two wanted lines and exits when they match.
  When the file holds a higher or non-numeric limit it warns and leaves the file alone; otherwise it writes with `sudo install -m 0644 /dev/stdin`, so root owns the file and the mode is explicit.

### Krew per system

`.chezmoidata/packages.yaml` holds `packages.common.krews` (plugins that krew offers on Linux, macOS and Windows: explore, get-all, stern, tail), `packages.linux.krews` (colorize-managed-fields, neat, node-shell, which krew offers on Linux and macOS only) and `packages.darwin.krews`, empty until reviewed on a macOS machine (the three Linux plugins are available there).
The script's list is the shared list plus the list of the current system, without duplicates, sorted; on this laptop it is the same 7 plugins as before.
It renders empty on a system with no list, and on Windows, which would need a PowerShell script.

### Vim plugins

The vim plugin script stays, now that Neovim is the editor, because it costs nothing and does nothing when the plugins are present; `vim.ycm_build` is false, and no YouCompleteMe build runs on request or by default.
The core library check is `ycm_core*.so` under `~/.vim/bundle/YouCompleteMe/third_party/ycmd/`.
A non-zero exit of vim is logged as a warning and does not fail the script.
Removing Vundle and the `Plugin 'ycm-core/YouCompleteMe'` line of the vimrc belongs to `cleanup-dead-config`; until then a fresh machine prints a missing core library message when vim starts.

### Data added to `.chezmoidata/packages.yaml`

- `packages.linux.apt`: the 12 packages of the prerequisites script (the empty `dpkgs` key is dropped).
- `packages.common.krews`, `packages.linux.krews`, `packages.darwin.krews` as above.
- `system.limits.nofile`: `soft: 32768`, `hard: 65536` (the live values on 2026-11-12; the script renders empty when the key is absent).
- `vim.ycm_build: false`.
- `brew.prefix: /home/linuxbrew/.linuxbrew`, the only place the Homebrew prefix is written in the scripts.

`home/dot_config/pipx/packages.json` is regenerated from `pipx list --json` (28 venvs: the 23 declared plus calcure, euporie, hike, ipython and pynvim).
All 23 existing entries change too, because their recorded app paths and versions no longer match.

The file holds no absolute path.
pipx writes `app_paths`, `man_paths`, `completion_paths` and their `_of_dependencies` forms after an install, and `pipx install-all` never reads them back: it installs the package at the recorded version, injects the recorded extras, and writes fresh metadata from the new venv.
The six fields stay in the file, emptied (`[]` or `{}`), because pipx requires `app_paths` and `app_paths_of_dependencies`.
`source_interpreter` is `null` for the same reason of portability: it was the Homebrew Python path, which does not exist on macOS or another prefix, and pipx prints a notice and uses its default Python when it is missing.
The cost is the Python pin: all 28 venvs run Python 3.13 today, and a venv built from this file uses pipx's default Python (3.14 on this machine).
`python_version` stays in the file as information; pipx does not use it to choose an interpreter.
`pipx install-all --python <path>` would pin one interpreter for the whole run; whether to pin, and with which data key, is left to `rationalize-package-ownership`.
The F24 part about user-specific paths is closed here for this file.

The file is refreshed with:

```sh
pipx list --json | jq --indent 4 '(.. | objects | select(has("app_paths"))) |= (.app_paths = [] | .app_paths_of_dependencies = {} | .man_paths = [] | .man_paths_of_dependencies = {} | .completion_paths = [] | .completion_paths_of_dependencies = {}) | .venvs[].metadata.source_interpreter = null'
```

It stays plain JSON, not a template: nothing in it depends on the machine.

## Risks / Trade-offs

- [Risk] Every script runs once on the next apply because its content changed or its name is new. → Each is a no-op on this machine by design; proved with the harness (isolated and live read-only modes) before the supervised apply.
- [Risk] Moving brew, pipx and mise to after-scripts means files that need those tools (templates calling `output` or `lookPath`) render before the tools exist on a fresh machine, and `add-mise-app-desktop-entries` writes its entries on the second apply. → Unchanged from today for this machine; a fresh machine is handled in `fresh-machine-bootstrap`, which may move only the brew bootstrap back to a before-script.
- [Risk] `pipx install-all` on a filtered file loses injected packages or Python pins. → Filter with `jq` on the `venvs` keys only, keeping each venv's full metadata.
- [Risk] Dropping `gh auth login` leaves a fresh machine without gh auth. → gh reads its token from the environment; the brew script logs a warning when `gh auth status` fails.
- [Risk] `CHEZMOI_SCRIPTS_DRY_RUN=1 chezmoi apply` runs the scripts in dry-run mode, and chezmoi records them as run because they exit 0, so the real apply later skips them. → The helper warns when both variables are set, `AGENTS.md` says to use the variable only on rendered scripts, and the harness never goes through `chezmoi apply`.
- [Risk] sudo asks for its password when a system change is needed, so apt and limits scripts cannot be fully non-interactive on a fresh machine. → That prompt is allowed by the spec; a provisioned machine never reaches it.
- [Risk] The vim plugin command cannot be proved without installing plugins. → The harness checks the call; the real run is part of the supervised apply, and the script only warns when vim fails.
- [Trade-off] The dry-run variable is a local convention, not a chezmoi feature; documented in `AGENTS.md`.
- [Trade-off] `brew file clean --dry-run` is parsed by line prefix, which ties the report to brew-file's output format; a format change makes the report empty rather than wrong, and the harness fixture catches it.

## Resolved questions

- Keep Vundle and the vim plugins, now that Neovim is the editor? Yes, without YouCompleteMe (decided 2026-11-12).
- Should the undeclared report cover more than brew? Yes: brew (formulae, taps, casks), pipx and krew, read-only; not mise (decided 2026-11-12).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
