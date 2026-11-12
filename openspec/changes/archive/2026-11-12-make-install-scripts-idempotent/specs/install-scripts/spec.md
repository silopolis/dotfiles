## ADDED Requirements

### Requirement: Scripts are no-ops on an up-to-date machine

Every chezmoi script SHALL install nothing, write nothing outside `$HOME`, and call no sudo when the machine already matches its inputs.

#### Scenario: Run each script on the provisioned laptop

- **WHEN** each script is rendered with `chezmoi -S <worktree> execute-template` and run in the live read-only mode of the harness (read-only queries reach the real tools, every other command is refused and logged, `sudo` is a logging stub)
- **THEN** the script exits 0, and the sudo log and the refused-command log are empty

#### Scenario: Second run in a row

- **WHEN** a script that installed something is run again immediately
- **THEN** it installs nothing

### Requirement: Scripts never uninstall

No script SHALL uninstall packages, remove taps, or delete caches; drift is reported instead.
Regenerating the generated shims of mise is not an uninstall and is allowed, because it touches no installed tool and writes only inside `$HOME`.

#### Scenario: Undeclared brew package

- **WHEN** a brew formula, tap or cask is installed but absent from the Brewfile and the brew script runs
- **THEN** it is still installed afterwards and the script output names it as undeclared

#### Scenario: Undeclared pipx venv

- **WHEN** a pipx venv is installed but absent from `packages.json` and the pipx script runs
- **THEN** it is still installed afterwards and the script output names it as undeclared

#### Scenario: Undeclared krew plugin

- **WHEN** a krew plugin is installed but absent from the combined plugin list and the krew script runs
- **THEN** it is still installed afterwards and the script output names it as undeclared

#### Scenario: Stale mise shim

- **WHEN** the mise shims directory holds a mise-owned shim that no installed tool provides, a shim that is missing for an installed tool, and a file that is not a shim, and `mise reshim` runs (real mise binary, scratch home and data directory, offline)
- **THEN** the stale shim is gone, the missing shim exists, the other file is untouched, no installed tool is touched, and a second run changes nothing

#### Scenario: The mise script refreshes the shims

- **WHEN** the rendered mise script runs
- **THEN** `mise reshim` is called after `mise install --yes`, and in dry-run mode it is printed and not called

#### Scenario: Nothing to clean on the provisioned laptop

- **WHEN** `mise reshim` is simulated against a symlink farm of the real installs and a copy of the real shims directory
- **THEN** no shim would be removed and none added

### Requirement: System files written only when needed and never weakened

A script that manages a file outside `$HOME` SHALL write it only when its content differs from the declared data, and SHALL never lower a limit.

#### Scenario: Limits already match

- **WHEN** `/etc/security/limits.d/ulimit.conf` holds the declared open-files limits and the limits script runs
- **THEN** the file is untouched and no sudo call happens

#### Scenario: Declared value lower than the live one

- **WHEN** the declared limit is lower than the value in the file
- **THEN** the script logs a warning and leaves the file unchanged

#### Scenario: Declared value higher than the live one

- **WHEN** the declared limits are higher than the values in the file and the limits script runs in the harness
- **THEN** the only sudo call recorded installs the declared content into `/etc/security/limits.d/ulimit.conf`

### Requirement: Non-interactive scripts

Scripts SHALL never prompt, except the identity decryption, which asks for its passphrase only when the identity file is missing, and sudo's own password prompt when a system change is needed.

#### Scenario: No terminal

- **WHEN** a rendered script other than the identity decryption runs with standard input from `/dev/null` on a machine that needs no system change
- **THEN** it completes without waiting for input

### Requirement: Triggers follow inputs

Each `run_onchange_` script SHALL embed a hash of every input it acts on, so a change to the script, to the shared helper or to that input makes it run again, and no other change does.

#### Scenario: Input change re-renders the script

- **WHEN** a script's declared input file or data changes
- **THEN** `chezmoi -S <worktree> execute-template` of that script produces different output

#### Scenario: Unrelated change leaves the script alone

- **WHEN** a file or data key that is not an input of a script changes
- **THEN** `chezmoi -S <worktree> execute-template` of that script produces the same output

#### Scenario: No escaped template actions

- **WHEN** `grep -rn '\\{\\{' home/.chezmoiscripts/` runs in the repository
- **THEN** it prints nothing

### Requirement: Portable scripts

Scripts SHALL contain no user-specific absolute path and SHALL guard distro-specific commands.

#### Scenario: No literal home or source path

- **WHEN** `rg -n '/home/[a-z]+/|\.local/share/chezmoi' home/.chezmoiscripts/` runs in the repository
- **THEN** it prints nothing (the Homebrew prefix comes from data)

#### Scenario: No absolute path in the pipx spec file

- **WHEN** `jq '[.. | strings | select(startswith("/"))] | length' home/dot_config/pipx/packages.json` runs in the repository
- **THEN** it prints 0

#### Scenario: apt only on the Debian family

- **WHEN** the prerequisites script is rendered with `--override-data '{"chezmoi":{"osRelease":{"id":"fedora","idLike":"rhel"}}}'`
- **THEN** the rendered script is empty

### Requirement: A skipped script runs again when its tool appears

A script that skips when a tool is missing SHALL hash, in a comment, whether each tool it needs is present in the directories of `tools.search`, and SHALL NOT read the `PATH` of the process that renders it.

#### Scenario: Tool appears

- **WHEN** a script is rendered with a tool absent from every searched directory, and again after an executable file of that name is created in one of them (scratch home and Homebrew prefix through `--override-data`)
- **THEN** the two renderings differ, and they are identical again once the file is removed

#### Scenario: A file that is not executable does not count

- **WHEN** a non-executable file named like the tool is created in a searched directory
- **THEN** the rendering does not change

#### Scenario: Rendering does not depend on PATH

- **WHEN** a script is rendered under `PATH=/nonexistent`, under the normal `PATH`, and under a `PATH` that holds every tool in a directory the template does not search
- **THEN** the three renderings are identical

#### Scenario: Missing tool is a skip

- **WHEN** a rendered script runs without one of its tools on `PATH`
- **THEN** it prints a warning that names the tool and exits 0, and it changes nothing

#### Scenario: Tool provided by a mise shim

- **WHEN** the only copy of a tool is an executable in the mise shims directory of `$HOME` and the script runs
- **THEN** the script finds it and does its work

### Requirement: The directories searched for tools are configurable

The directories where the scripts look for tools SHALL come from `tools.search`: a default list `dirs`, additional directories `extra` searched after it, and `override`, which replaces both when it is not empty.
An entry SHALL be an absolute path, `~/x` or `<brew>/x`, and the scripts SHALL put the same directories on their own `PATH`.

#### Scenario: Default list

- **WHEN** the `tools-dirs` template is rendered without any local setting
- **THEN** it lists the mise shims, `<brew.prefix>/bin`, `~/.local/bin`, `/usr/local/bin`, `/usr/bin` and `/bin`, in this order

#### Scenario: Additional directories

- **WHEN** the local config sets `extra`, with a duplicate of a default directory, a `~/` entry and a path with dot segments
- **THEN** the list is the default one followed by the new directories, normalised, without duplicates

#### Scenario: Override

- **WHEN** the local config sets `override`
- **THEN** the list holds those directories only, and `extra` and the defaults are ignored

#### Scenario: Bad entry

- **WHEN** an entry is relative, is `~` or `~/`, goes above the home directory, is not a string, or holds a colon or a quote
- **THEN** the render fails with a message that names `tools.search`

#### Scenario: Local config wins

- **WHEN** the local config sets `extra` and `chezmoi data` is read
- **THEN** `tools.search.extra` is the local value, and `dirs` is still the default list

#### Scenario: A tool in an added directory

- **WHEN** an executable exists only in a directory listed in `extra`
- **THEN** the presence entry of the script is `absent` without that setting and `present` with it

#### Scenario: Same directories at run time

- **WHEN** a script runs with a tool that exists only in an added directory, and the tool is not on `PATH`
- **THEN** the script finds it and does its work

#### Scenario: PATH helper

- **WHEN** `use_tool_dirs` is called with an existing directory missing from `PATH`, one already on `PATH`, a missing directory and a `~/` entry
- **THEN** the missing existing directories are prepended in list order, the one already present keeps its place, the missing directory is skipped, and `~` is expanded to `$HOME`

#### Scenario: Rendered script holds no home path

- **WHEN** a script that calls `use_tool_dirs` is rendered
- **THEN** its list keeps `~/` entries as they are

#### Scenario: Isolated runs cannot reach real tools

- **WHEN** the harness runs an isolated script whose `use_tool_dirs` lists a real directory
- **THEN** it refuses to run it

### Requirement: The tools the scripts use are declared

Every tool that a script runs and that is not part of the base system SHALL be declared by one package manager of this repository, the highest in the install priority that offers it.

#### Scenario: Declarations

- **WHEN** `grep -E '^(jq|kubectl) = ' home/dot_config/mise/config.toml` and `grep -x 'brew vim' home/dot_config/brewfile/Brewfile` run in the repository
- **THEN** the first prints two lines and the second prints one

#### Scenario: What the next apply installs on the provisioned laptop

- **WHEN** `mise install --dry-run-code` runs against a scratch copy of the repository mise config, from a scratch directory, on the laptop of 2026-11-12
- **THEN** it names no tool except `jq`, and never `kubectl` (an installed version satisfies `latest`); it exits 0 once `jq` is installed

### Requirement: Vim plugins can be installed from Ex mode

The vimrc SHALL set `nocompatible` before Vundle loads, so that `vim -Es` defines the Vundle commands completely.

#### Scenario: Vundle commands under plain Ex mode

- **WHEN** `vim -Es -n -u home/dot_config/vim/vimrc -i NONE -c 'if execute("command PluginInstall") !~ "vundle#installer#new" | cquit 2 | endif' -c qall` runs on a machine where the Vundle external is in place
- **THEN** it exits 0

### Requirement: Local extension files are installed only when missing

The VSCodium script SHALL install a `.vsix` file of `~/.local/share/vsix` only when the extension it holds is not installed, SHALL identify the extension by the `publisher.name` inside the archive and by the file name when the archive cannot be read, and SHALL never remove or upgrade an extension.

#### Scenario: Extension already installed

- **WHEN** the extension of a `.vsix` file is installed, whatever the case of its id, and the rendered script runs
- **THEN** no `codium --install-extension` call is made for it, and the output says it is skipped

#### Scenario: Extension missing

- **WHEN** the extension of a `.vsix` file is not installed and the script runs
- **THEN** `codium --install-extension` is called once, with that file

#### Scenario: Identification

- **WHEN** a `.vsix` file is named differently from its `publisher.name`, with and without `jq` available
- **THEN** with `jq` the id comes from the archive, and without it from the file name

#### Scenario: Unreadable archive

- **WHEN** a `.vsix` file is not an archive and its name without version holds an installed id
- **THEN** it is skipped

#### Scenario: Listing fails

- **WHEN** `codium --list-extensions` fails
- **THEN** the script exits 1 and installs nothing

#### Scenario: One failed install

- **WHEN** installing one declared extension fails
- **THEN** the script warns, installs the other missing extensions, and exits 0

#### Scenario: Provisioned laptop

- **WHEN** the rendered script runs with the real `codium`, `unzip` and `jq` in live read-only mode
- **THEN** it makes no install call and exits 0

### Requirement: Krew plugins come from a shared list and a list per system

The krew script SHALL install the plugins of `packages.common.krews` plus those of the list for the current operating system, without duplicates, and SHALL render empty when that combined list is empty.

#### Scenario: Linux list

- **WHEN** the krew script is rendered on Linux
- **THEN** it names the shared plugins and the Linux plugins, each once

#### Scenario: macOS list

- **WHEN** the krew script is rendered with `--override-data '{"chezmoi":{"os":"darwin"}}'`
- **THEN** it names the shared plugins and the plugins of `packages.darwin.krews`, and no Linux plugin

#### Scenario: Moving a plugin between lists

- **WHEN** a plugin moves from the shared list to the list of the current system and the combined list is unchanged
- **THEN** the rendered script is identical, so it is not pending

### Requirement: Dry-run mode

Scripts SHALL honour `CHEZMOI_SCRIPTS_DRY_RUN=1` by printing each change instead of performing it; read-only queries still run.

#### Scenario: Dry run of the brew script

- **WHEN** the rendered brew script runs with `CHEZMOI_SCRIPTS_DRY_RUN=1`
- **THEN** it prints the commands it would run and changes nothing

#### Scenario: Dry-run variable under chezmoi

- **WHEN** a rendered script runs with `CHEZMOI_SCRIPTS_DRY_RUN=1` and `CHEZMOI=1`
- **THEN** it prints a warning that chezmoi records the script as run

### Requirement: Shell quality

Rendered scripts SHALL pass shellcheck.

#### Scenario: shellcheck on rendered scripts

- **WHEN** each script is rendered and passed to `shellcheck -s bash`
- **THEN** it reports no error

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
