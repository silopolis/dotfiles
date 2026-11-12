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
- The tools the scripts use are declared: `jq` and `kubectl` in the mise config, `vim` in the Brewfile; the vimrc sets `nocompatible` before Vundle loads.
- The directories where the scripts look for tools are configurable (default list, additional directories, full override), and the mise script refreshes the mise shims after installing.

## Decisions

### New script set

Numbering by kind: 0x before, 1x package managers, 2x editors, 3x user setup (`manage-xdg-basics` takes 30, `add-mise-app-desktop-entries` takes 31), 9x caches.

| Script | Phase | Trigger (hashed input) | Does |
| --- | --- | --- | --- |
| `run_onchange_before_00-prerequisites.sh.tmpl` | before | `packages.linux.apt` | Debian family only; installs missing apt packages; sudo only if some are missing |
| `run_onchange_before_01-decrypt-private-key.sh.tmpl` | before | content | same logic, `$HOME` instead of a literal path, the binary from `CHEZMOI_EXECUTABLE` |
| `run_onchange_before_02-system-limits.sh.tmpl` | before | `system.limits.nofile` | writes the limits file only when it differs and never with lower values; sudo only then |
| `run_onchange_after_10-brew.sh.tmpl` | after | Brewfile (darwin: brews and casks) | Homebrew and brew-file if missing; `brew file install` against the deployed `~/.config/brewfile/Brewfile`; reports undeclared formulae, taps and casks; `rustup default stable` only when no default toolchain; warns when gh is not logged in; darwin branch: `brew bundle` |
| `run_onchange_after_11-mise.sh.tmpl` | after | `dot_config/mise/config.toml`, presence of `mise` | `mise install --yes`, then `mise reshim` (shim cleanup) |
| `run_onchange_after_12-pipx.sh.tmpl` | after | `dot_config/pipx/packages.json`, presence of `pipx` and `jq` | installs only venvs missing from `pipx list --short`, through a filtered copy of the spec file; reports undeclared venvs |
| `run_onchange_after_13-krew.sh.tmpl` | after | the combined plugin list, presence of `kubectl` and `kubectl-krew` | Linux and macOS; installs only missing plugins; reports undeclared plugins; renders empty when the list is empty |
| `run_onchange_after_20-vscodium-extensions.sh.tmpl` | after | extension list, presence of `codium` | installs missing extensions, then the `.vsix` files of `~/.local/share/vsix` whose extension is not installed |
| `run_onchange_after_21-vim-plugins.sh.tmpl` | after | `dot_config/vim/vimrc`, presence of `vim` | `vim -N -Es -n -u ~/.vimrc -i NONE +PluginInstall +qall`; YouCompleteMe build only when `vim.ycm_build` is true and the core library is missing |
| `run_onchange_after_90-bat-cache.sh.tmpl` | after | `dot_config/bat/config`, `.chezmoiexternals/bat.toml.tmpl` | `bat cache --build` |

Hash lines use `{{ include "<path>" | sha256sum }}` (paths relative to `home/`) or `{{ .<data> | toJson | sha256sum }}`; nothing escaped.
Package managers move to after-scripts so they read deployed files (Brewfile, `packages.json`, `vimrc`) instead of source paths, and so vim plugins install after Vundle (an external) and the vimrc exist.
The bat hash covers the external declarations, not the upstream theme files, which the weekly refresh may change without re-running the script.
The `.vsix` directory is outside the repository, so adding a file there does not re-run the VSCodium script.

A script that skips when a tool is missing also hashes whether that tool is there.
Its hash comment holds `# tools: <tool>=present|absent ...`, produced by the `tools-present` template: for each tool, chezmoi's `findExecutable` looks in the directories of the `tools-dirs` template (by default the mise shims, `<brew.prefix>/bin`, `~/.local/bin`, `/usr/local/bin`, `/usr/bin` and `/bin`).
A skip exits 0, so chezmoi records it like a run, and the recorded hash holds `absent`; when the tool is installed in one of those directories the next render holds `present`, and the script runs again by itself.
The lookup never reads the `PATH` of the process that renders, which is what makes the plain `lookPath` version of this idea unreliable: an interactive shell, cron and `env -i` have different `PATH`s and would flip the hash without any change on the machine (the harness shows the text is identical under three different `PATH`s, and fails when `lookPath` is used instead).

### Directories searched for tools

`.chezmoidata/tools.yaml` holds `tools.search` with three keys, applied in this order:

- `dirs`: the default list, in search order (the six directories above);
- `extra`: directories searched after the default ones;
- `override`: when it is not empty, the only directories searched (`dirs` and `extra` are ignored).

An entry is an absolute path, `~/x` (below the home directory) or `<brew>/x` (below `brew.prefix`); the list is normalised (`..` and `.` segments, trailing slashes) and de-duplicated.
An entry that is relative, names the home directory itself or something above it, is not a string, or holds a colon, a quote or a newline fails the render with a message naming `tools.search`: a relative path would make `findExecutable` depend on the working directory, and the other characters would break the `PATH` or the shell script that receives the list.

Local changes belong to the local chezmoi config, table `[data.tools.search]`, because the machine decides them: the data file stays the same on every machine.
The config wins over the data file for the keys it sets (checked with a scratch config), and `.chezmoi.toml.tmpl` copies `extra` and `override` from the existing data into the generated config, as empty lists when there are none, so that `chezmoi init` keeps hand-written values instead of dropping them; it prompts for nothing.

Two templates consume the list: `tools-present` expands `~/` with the chezmoi home directory for `findExecutable`, and `tools-use` renders `use_tool_dirs '<dir>' ...` with the `~/` entries kept as they are, so that a rendered script holds no home path and expands `~` itself at run time.
The scripts therefore search and use the same directories, whatever the list is.
A change of the list changes the `use_tool_dirs` line of the four scripts that read it, so each of them runs once more; the presence entries change only when a tool is found or lost.

The directories are prepended to `PATH` when they exist and are missing from it, so a `PATH` that already holds them keeps its order, and with the default list a mise tool wins over Homebrew and the distribution in a bare environment.
A script that ran in the harness with real directories first on `PATH` would run real tools in front of the stubs: the harness therefore renders the scripts of its isolated runs with a scratch `tools.search.override`, and `run.sh` refuses an isolated script whose list holds a real directory.

Residual limits, now narrower: a tool installed outside the searched directories does not re-run the script (add the directory to `extra`, or the next edit of the script's input does), and a custom mise data directory is searched only when its shims directory is listed.
A mise shim left behind by an uninstalled tool no longer counts forever: the mise script removes it (see "Shim cleanup" below), after which the presence entry of the other scripts turns `absent` at the next render.

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
- `use_tool_dirs <dir>...` (puts the directories of `tools.search` on `PATH`: a directory that exists and is missing from `PATH` is prepended in list order, `~/` is expanded to `$HOME`);
- `need <tool>...` (succeeds when every tool is found; otherwise warns, naming the missing ones, and fails, and the script ends with `need ... || exit 0`);
- `report_undeclared <what> <installed> <declared>` (lists installed names that are not declared, removes nothing);
- a warning when the dry-run variable is set while `CHEZMOI=1`.

`load_brew` exports `XDG_CONFIG_HOME` because Homebrew keeps its trust file in `$XDG_CONFIG_HOME/homebrew` and looks in `~/.homebrew` when the variable is unset.
Without the file, third-party taps are untrusted and brew-file lists the 20 installed tap formulae of the Brewfile as missing (found with the live harness: `brew file install --dry-run` printed a `brew install` line for them in a bare environment, and printed nothing once `XDG_CONFIG_HOME` was set).
A shell that sourced `rc.d` has the variable, but ssh commands, cron and `env -i` do not.
`brew shellenv` prepends the Homebrew directory to `PATH` unconditionally, which is why the harness always passes `HOMEBREW_PREFIX` (so `load_brew` never evaluates it there) and refuses a script that embeds the real prefix when asked to leave it unset.

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
- Homebrew or brew-file counts as missing when `brew` is not found or `brew file version` fails; the script then runs brew-file's installer, which installs Homebrew first when needed and ends with `brew doctor`, failing the script when it reports a problem.
  Homebrew's installer calls sudo, and `NONINTERACTIVE=1` makes it use cached credentials and never prompt, so the script caches them first through `as_root` (`sudo -v`): the one place where a password prompt can appear, and it shows in the sudo log of the harness.
  Without a terminal and without passwordless sudo, `sudo -v` fails, and so does the script, before anything is installed.
- A missing deployed Brewfile fails the script: brew-file would create a Brewfile from the installed packages instead of installing anything.
- `rustup default stable` runs when `rustup default` does not report a default toolchain; a missing gh login is only warned about, because a login needs a terminal.
- The darwin branch is the `brew bundle` call of the old krew script, with a guard for a missing `brew`; its lists are the trigger.

### Before scripts

- The prerequisites script renders empty unless the os-release `id` is `debian` or `id_like` names it (Ubuntu, Kali, Mint), and when `packages.linux.apt` is empty; chezmoi neither runs nor lists an empty script.
  It checks each package with `dpkg-query` and calls sudo, for `apt-get update` and one `apt-get install`, only when a package is missing.
- The decrypt script uses the binary that is applying, through `CHEZMOI_EXECUTABLE`, which chezmoi sets for every script it runs, and falls back to `chezmoi` on `PATH` when the script is run by hand.
  A path rendered into the script would change after every chezmoi upgrade and make the script pending again, and `PATH` may not hold chezmoi on a fresh machine.
  It writes the identity with umask 077, so the file is never group-readable, then `chmod 600` as before.
- The limits script reads `system.limits.nofile`, checks at render time that both values are whole numbers with `0 < soft <= hard`, and renders empty when the data is absent.
  It compares the file with the two wanted lines and exits when they match.
  When the file holds a higher or non-numeric limit it warns and leaves the file alone; otherwise it writes with `sudo install -m 0644 /dev/stdin`, so root owns the file and the mode is explicit.

### Package manager scripts

- `11-mise`, `12-pipx`, `13-krew` and `21-vim-plugins` call `load_brew` and `use_tool_dirs`, so they find their tools right after a first Homebrew or mise install, and `need` their tools.
  A missing tool is a skip (warning, exit 0), so that an apply never stops because an optional manager is absent, and the script runs again once the tool appears, because the tool's presence is part of its hash (see above).
  Only a missing input that the apply itself should have written (the deployed `packages.json`, the Brewfile, the vimrc and Vundle) fails the script, so that chezmoi retries it at the next apply.
- `12-pipx` compares `jq` keys of the deployed `packages.json` with `pipx list --short`, writes the filtered copy under `$XDG_CACHE_HOME` (inside `$HOME`, removed on exit) only when a venv is missing, and does not write it in dry-run mode.
  Its header comment holds the refresh command of `packages.json`.
- `13-krew` needs `kubectl` and `kubectl-krew` (the krew plugin manager, from the `krew` formula), ignores `krew` itself and the `PLUGIN` header in `kubectl krew list`, and skips when `kubectl krew version` fails.
- `11-mise` has no input besides the deployed global config: `mise install --yes` leaves other versions alone and prunes nothing, then `mise reshim` refreshes the shims (next section).

### Shim cleanup

A shim is a generated link in the mise shims directory, one per executable of an installed tool.
After a tool is uninstalled, or its directory is deleted, its shim can stay behind: it counts as a present tool for the `tools-present` line of the other scripts, and it cannot run.
A shim without a usable version fails with the message "No version is set for shim"; this machine shows it today for `shellcheck` and `yq`, whose tools are installed but have no active version, which is a different case that a reshim keeps as it is.
The cleanup is `mise reshim`, run by `11-mise` after the install, so that it also runs when a tool is removed from the mise config (an edit of the config re-runs the script).
From the source of mise (`src/shims.rs`): it adds the missing shims and removes the mise-owned shims that no installed tool provides any more, and it leaves every other file of the directory alone.
It is not an uninstall: no tool version is touched, only generated links, inside `$HOME`; the "never uninstall" rule is about packages, taps and caches.
`mise uninstall` already rebuilds the shims itself (`rebuild_shims_and_runtime_symlinks_after_removal` in its source), so the case the cleanup covers is a tool that went away by other means (a deleted install directory, a pruned version, or a removal done while mise was not the one asked).

Proof, without touching the real shims: `reshim-sandbox.sh` runs the real mise binary offline in a scratch home and data directory with a fake `node` install, a stale shim, a current shim and a non-shim file (stale removed, missing added, current and non-shim kept, installed tool untouched, second run identical); `reshim-preview.sh` runs it against a symlink farm of the real installs and a copy of the real shims directory, and reports what a real reshim would change on this laptop (nothing: 137 shims before and after, then 138 once `jq` was installed), and fails when a stale shim is planted in the copy.
In live mode the harness swaps `mise reshim` for `mise --version`, because the real command writes the shims directory.

### VSCodium script

- It is the list logic of today with the helper, the `codium` presence line and a quoted array instead of an unquoted word list.
  Extension ids are compared in lower case, because ids are case-insensitive.
- `codium --list-extensions` runs once, and each successful install is appended to the list, so a `.vsix` whose id was just installed from the list is not installed again.
  When the listing fails the script fails before installing anything, instead of treating every extension as missing.
- A `.vsix` is identified by `publisher.name` read from `extension/package.json` inside the archive (`unzip -p` and `jq`); when `unzip` or `jq` is absent, or the file is not a readable archive, by its file name without the version suffix (`sitoi.ai-commit-0.1.2.vsix` gives `sitoi.ai-commit`).
  It is skipped when that id is installed, whatever its version: upgrading from a newer `.vsix` is a manual action.
- A failed install is a warning and the script ends with exit 0, as today: one extension that Open VSX does not offer must not stop the apply, and chezmoi would not retry the script before the list changes.
- The `.vsix` directory is outside the repository and is not part of the trigger.
- The comment of `.chezmoidata/vscodium.yaml` named `modify_settings.json.tmpl`, which does not exist; it names `modify_settings.json` now (F27).

### Krew per system

`.chezmoidata/packages.yaml` holds `packages.common.krews` (plugins that krew offers on Linux, macOS and Windows: explore, get-all, stern, tail), `packages.linux.krews` (colorize-managed-fields, neat, node-shell, which krew offers on Linux and macOS only) and `packages.darwin.krews`, empty until reviewed on a macOS machine (the three Linux plugins are available there).
The script's list is the shared list plus the list of the current system, without duplicates, sorted; on this laptop it is the same 7 plugins as before.
It renders empty on a system with no list, and on Windows, which would need a PowerShell script.

### Vim plugins

The vim plugin script stays, now that Neovim is the editor, because it costs nothing and does nothing when the plugins are present; `vim.ycm_build` is false, and no YouCompleteMe build runs on request or by default.
The core library check is `ycm_core*.so` under `~/.vim/bundle/YouCompleteMe/third_party/ycmd/`.
The script needs the deployed vimrc and the Vundle external: when either is missing it fails, so that chezmoi runs it again.
A non-zero exit of vim is logged as a warning and does not fail the script.
Ex mode (`-Es`) starts with `compatible` set, and Vundle's autoload file defines its commands over continuation lines that a compatible vim does not join.
The vimrc used to load Vundle at line 21 and set `nocompatible` only at line 665, so Vundle loaded too early.
Measured on this machine with the old vimrc (`:command` listing after startup): without `-N`, `Plugin` and `PluginInstall` exist with an empty definition and vim exits 1, so the vimrc declares no plugin and `+PluginInstall` does nothing, with only a warning from the script; with `-N` both commands are complete and vim exits 0.
In an interactive vim the problem does not appear, because finding a vimrc resets `compatible` before it is read.
Two fixes are applied together, by decision of the user (2026-11-12): the vimrc now sets `nocompatible` on its first line, as Vundle's documentation asks, and the script keeps `-N`, which costs nothing and protects a machine whose deployed vimrc is still the old one until the next apply.
`-n` and `-i NONE` keep vim from writing swap and viminfo files.
Removing Vundle and the `Plugin 'ycm-core/YouCompleteMe'` line of the vimrc belongs to `cleanup-dead-config`; until then a fresh machine prints a missing core library message when vim starts.

### Tools the scripts need

Install priority is mise, then brew, then the distribution (`AGENTS.md`).
The scripts use a handful of tools, and each is declared once, by the highest-priority manager that offers it:

| Tool | Declared in | Why there |
| --- | --- | --- |
| `mise`, `pipx`, `krew` (the `kubectl-krew` plugin), `rustup`, `gh` | Brewfile | already there; the scripts only use them |
| `jq` | mise config (`jq = "latest"`) | the pipx script filters its spec file with it; mise has it through aqua; `/usr/bin/jq` on this laptop is an accidental dependency of other packages (`clevis-luks`, `fwupd`) and stays as a fallback |
| `kubectl` | mise config (`kubectl = "latest"`) | the krew script runs it; mise has it through aqua |
| `vim` | Brewfile (`brew vim`) | the vim plugin script runs it; mise offers vim only as a conda package or a build-from-source plugin, so brew is the first practical choice; it is a secondary editor now that Neovim is the main one |

Effects on this machine.
The user approved, on 2026-11-12, deploying the three changed files (mise config, Brewfile, vimrc, each as a single target with `--exclude=scripts`) and installing `jq` with mise; both were done during this change, and nothing else was installed, upgraded or removed:

- `mise install jq` installed `jq` 1.8.2 (the mise config now declares it, and `mise install --dry-run-code` exits 0); `kubectl = "latest"` is already satisfied by the installed 1.36.0, since mise treats `latest` as the newest installed version until `mise upgrade`.
- The mise shim of `kubectl` comes before Homebrew in the interactive `PATH`, so `kubectl` moves from Homebrew's 1.37.0 to mise's 1.36.0 (the declaration is deployed) until `mise upgrade kubectl` (1.37.2 at the time of writing).
  The `kubernetes-cli` line stays in the Brewfile: removing duplicates between brew and mise is `rationalize-package-ownership`.
- `vim` is installed here only as a dependency of `ttyd`, and brew-file lists only packages installed on request, so its next regeneration of the Brewfile (after a brew command through `brew-wrap`) would drop the `brew vim` line (checked with `brew file init` into a scratch file: with the default settings `vim` is absent, with `vim` among the top packages it is listed).
  A fresh machine is not affected: `brew file install` installs `vim` on request.
  On this laptop, `brew install vim` once marks it as installed on request; it is the user's to run.

### Data added

`.chezmoidata/tools.yaml` (new): `tools.search.dirs`, `extra` and `override`, described above.

In `.chezmoidata/packages.yaml`:

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
- [Risk] A script skips because a tool is missing, and nobody notices. → The skip is a warning in the apply output, `chezmoi status` lists the script as pending again as soon as the tool appears in one of the searched directories, and the tools themselves are declared, so a missing one means an earlier step failed.
- [Risk] The tool presence is looked up in a list of directories while the script uses `PATH`. → `use_tool_dirs` puts the same list on the script's `PATH`; the residual cases are listed under "Directories searched for tools".
- [Risk] A bad `tools.search` value in the local config breaks the render of four scripts, and so every apply. → The render fails early with a message that names the key and the entry, and `chezmoi init` writes only the two keys `extra` and `override` from what the config already holds.
- [Risk] `mise reshim` removes a shim that something still uses. → Only mise-owned shims that no installed tool provides are removed, and such a shim cannot run; a file that is not a mise shim is never touched.
- [Risk] The vim plugin command cannot be proved without installing plugins. → The harness checks the call; the real run is part of the supervised apply, and the script only warns when vim fails.
- [Trade-off] The dry-run variable is a local convention, not a chezmoi feature; documented in `AGENTS.md`.
- [Trade-off] `brew file clean --dry-run` is parsed by line prefix, which ties the report to brew-file's output format; a format change makes the report empty rather than wrong, and the harness fixture catches it.

## Resolved questions

- Keep Vundle and the vim plugins, now that Neovim is the editor? Yes, without YouCompleteMe (decided 2026-11-12).
- Should the undeclared report cover more than brew? Yes: brew (formulae, taps, casks), pipx and krew, read-only; not mise (decided 2026-11-12).
- Skip or fail when a manager's tool is missing? Skip with a warning, and run again when the tool appears, through a path-independent presence entry in the hash comment (decided 2026-11-12; a `lookPath` version was rejected for its dependence on `PATH`, and failing the apply for a missing optional tool was rejected too).
- Where do `jq`, `kubectl` and `vim` come from? `jq` and `kubectl` from mise, `vim` from brew (decided 2026-11-12).
- Vim in Ex mode: `-N` in the script, `set nocompatible` first in the vimrc, both (decided 2026-11-12).
- Should the searched directories be customizable? Yes: a default list, additional directories and a full override, from the local config (decided 2026-11-12).
- A cleanup step for shims of removed packages? Yes: `mise reshim` in the mise script, after the install (decided 2026-11-12).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
