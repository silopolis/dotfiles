## ADDED Requirements

### Requirement: Scripts are no-ops on an up-to-date machine

Every chezmoi script SHALL install nothing, write nothing outside `$HOME`, and call no sudo when the machine already matches its inputs.

#### Scenario: Run each script on the provisioned laptop

- **WHEN** each script is rendered with `chezmoi execute-template` and run with a `sudo` stub first on `PATH` that records any call
- **THEN** the stub records nothing and the script exits 0

#### Scenario: Second run in a row

- **WHEN** a script that installed something is run again immediately
- **THEN** it installs nothing

### Requirement: Scripts never uninstall

No script SHALL uninstall packages, remove taps, or delete caches; drift is reported instead.

#### Scenario: Undeclared brew package

- **WHEN** a brew package is installed but absent from the Brewfile and the brew script runs
- **THEN** the package is still installed afterwards and the script output names it as undeclared

### Requirement: System files written only when needed and never weakened

A script that manages a file outside `$HOME` SHALL write it only when its content differs from the declared data, and SHALL never lower a limit.

#### Scenario: Limits already match

- **WHEN** `/etc/security/limits.d/ulimit.conf` holds the declared open-files limits and the limits script runs
- **THEN** the file is untouched and no sudo call happens

#### Scenario: Declared value lower than the live one

- **WHEN** the declared limit is lower than the value in the file
- **THEN** the script logs a warning and leaves the file unchanged

### Requirement: Non-interactive scripts

Scripts SHALL never prompt, except the identity decryption, which asks for its passphrase only when the identity file is missing.

#### Scenario: No terminal

- **WHEN** a rendered script other than the identity decryption runs with standard input from `/dev/null`
- **THEN** it completes without waiting for input

### Requirement: Triggers follow inputs

Each `run_onchange_` script SHALL embed a hash of every input it acts on, so a change to that input, and only to it, makes the script run again.

#### Scenario: Input change re-renders the script

- **WHEN** a script's declared input file or data changes
- **THEN** `chezmoi execute-template` of that script produces different output

#### Scenario: No escaped template actions

- **WHEN** `grep -rn '\\{\\{' .chezmoiscripts/` runs in the source state
- **THEN** it prints nothing

### Requirement: Portable scripts

Scripts SHALL contain no user-specific absolute path and SHALL guard distro-specific commands.

#### Scenario: No literal home or source path

- **WHEN** `rg -n '/home/[a-z]+/|\.local/share/chezmoi' .chezmoiscripts/` runs in the source state
- **THEN** it prints nothing (the Homebrew prefix comes from data)

#### Scenario: apt only on the Debian family

- **WHEN** the prerequisites script is rendered on a system whose os-release id and id_like do not include `debian`
- **THEN** the rendered script is empty

### Requirement: Dry-run mode

Scripts SHALL honour `CHEZMOI_SCRIPTS_DRY_RUN=1` by printing each action instead of performing it.

#### Scenario: Dry run of the brew script

- **WHEN** the rendered brew script runs with `CHEZMOI_SCRIPTS_DRY_RUN=1`
- **THEN** it prints the commands it would run and changes nothing

### Requirement: Shell quality

Rendered scripts SHALL pass shellcheck.

#### Scenario: shellcheck on rendered scripts

- **WHEN** each script is rendered and passed to `shellcheck -s bash`
- **THEN** it reports no error

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
