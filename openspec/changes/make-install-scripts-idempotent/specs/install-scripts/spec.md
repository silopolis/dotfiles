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

#### Scenario: Undeclared brew package

- **WHEN** a brew formula, tap or cask is installed but absent from the Brewfile and the brew script runs
- **THEN** it is still installed afterwards and the script output names it as undeclared

#### Scenario: Undeclared pipx venv

- **WHEN** a pipx venv is installed but absent from `packages.json` and the pipx script runs
- **THEN** it is still installed afterwards and the script output names it as undeclared

#### Scenario: Undeclared krew plugin

- **WHEN** a krew plugin is installed but absent from the combined plugin list and the krew script runs
- **THEN** it is still installed afterwards and the script output names it as undeclared

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
