## Why

The install scripts are the reason a full `chezmoi apply` has been off limits since 2026-10-26: `05-install` would lower the system open-files limit, uninstall undeclared brew packages, remove taps and the brew cache, compile YouCompleteMe, prompt for GitHub login and reinstall a retired extension, all because a package list changed.
Other scripts never re-run when their inputs change, or redo work on every run.
Scripts must become safe to run at any time before the supervised apply (audit findings F01, F02, F24 for scripts, F27).

## What Changes

- **BREAKING (behaviour)**: `run_onchange_before_05-install.sh.tmpl` is split into focused after-scripts, one per manager, each triggered by its own input: brew (Brewfile), mise (`config.toml`), pipx (`packages.json`), krew (the plugin lists), vim plugins (`vimrc`).
- No script uninstalls anything: `brew file clean` is replaced by a dry-run report of what is undeclared, and the pipx and krew scripts report their undeclared installs the same way.
- The open-files limit comes from data (the values live on 2026-11-12: soft 32768, hard 65536), is written only when the file differs, and is never lowered.
- `gh auth login` and the gh-copilot install are dropped (the brew script warns when gh is not logged in); YouCompleteMe is built only on request and only when missing.
- The apt prerequisites script is guarded to the Debian family, installs only missing packages, and calls sudo only then; its list moves to `home/.chezmoidata/packages.yaml`.
- The krew script has one branch per operating system (Linux and macOS): the plugin list is a shared list `packages.common.krews` plus a list per system; the darwin `brew bundle` call moves to the darwin branch of the brew script.
- `home/dot_config/pipx/packages.json` is synchronized with the 28 venvs installed on this machine, so that the undeclared report starts empty.
- Broken trigger lines (`\{\{ ... \}\}`) become real hashes; the bat cache script also hashes its themes.
- The VSCodium script skips `.vsix` files whose extension is installed.
- Scripts share a small helper (logging, dry-run mode, sudo guard, Homebrew and mise environment) and contain no user-specific paths.
- A script that skips because its tool is missing runs again once the tool appears: its hash comment holds the tool's presence in a list of directories, not in the `PATH` of whoever renders it.
- That list is configurable (`tools.search` in `.chezmoidata/tools.yaml`: default list, additional directories, full override, set in the local chezmoi config), and the scripts put the same directories on their own `PATH`.
- The mise script refreshes the mise shims after installing (`mise reshim`), which removes the shims of tools that are no longer installed.
- The tools the scripts use are declared: `jq` and `kubectl` in the mise config, `vim` in the Brewfile; the vimrc sets `nocompatible` before Vundle loads, so that Ex mode can install the plugins.
- Scripts are numbered by kind: 0x before, 1x package managers, 2x editors, 3x user setup (taken by other changes), 9x caches.
- `TODO.md` calls its entries items instead of lines, and gains two follow-ups (the soft open-files limit of the desktop session, the per-system review of the krew plugins).

## Capabilities

### New Capabilities

- `install-scripts`: what chezmoi's scripts may do, when they run, and how they are checked.

### Modified Capabilities

- `chezmoi-config`: the config template keeps the local `tools.search` settings across `chezmoi init`.

## Impact

- `home/.chezmoiscripts/`: one script removed, several added or renamed; every script's content changes and renamed scripts get a new state key, so each runs once on the next apply (designed to be a no-op on a provisioned machine).
- `home/.chezmoidata/tools.yaml` (new): the directories searched for tools.
- `home/.chezmoi.toml.tmpl`: a `[data.tools.search]` table, copied from the existing data.
- `home/.chezmoidata/packages.yaml`: apt list, shared and per-system krew lists, open-files limits, `vim.ycm_build`, `brew.prefix`.
- `home/dot_config/pipx/packages.json`: synchronized with the installed venvs (five added, the 23 existing entries refreshed), with no absolute path left.
- `home/dot_config/mise/config.toml`: `jq` and `kubectl`; `home/dot_config/brewfile/Brewfile`: `vim`; `home/dot_config/vim/vimrc`: `set nocompatible` moved to the first line.
- New `home/.chezmoitemplates/script-lib.sh`, `tools-dirs`, `tools-present` and `tools-use`.
- `TODO.md`: wording and two follow-up entries.
- Installed software is unchanged by this change.
  The declarations are the exception: pipx declares what is already installed, `jq` is installed by mise at the next apply, `kubectl` and `vim` are already installed (by mise's older versions and as a dependency of another package).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
