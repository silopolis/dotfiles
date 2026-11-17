## MODIFIED Requirements

### Requirement: Scripts are no-ops on an up-to-date machine

Every chezmoi script SHALL install nothing, write nothing outside `$HOME`, and call no sudo when the machine already matches its inputs.

#### Scenario: Run each script on the provisioned laptop

- **WHEN** each script is rendered with `chezmoi -S <worktree> execute-template` and run by `mise run test:live` in the live read-only mode of the suite (read-only queries reach the real tools, every other command is refused and logged, `sudo` is a logging stub)
- **THEN** the script exits 0, and the sudo log and the refused-command log are empty

#### Scenario: Second run in a row

- **WHEN** a script that installed something is run again immediately
- **THEN** it installs nothing


### Requirement: System files written only when needed and never weakened

A script that manages a file outside `$HOME` SHALL write it only when its content differs from the declared data, and SHALL never lower a limit.

#### Scenario: Limits already match

- **WHEN** `/etc/security/limits.d/ulimit.conf` holds the declared open-files limits and the limits script runs
- **THEN** the file is untouched and no sudo call happens

#### Scenario: Declared value lower than the live one

- **WHEN** the declared limit is lower than the value in the file
- **THEN** the script logs a warning and leaves the file unchanged

#### Scenario: Declared value higher than the live one

- **WHEN** the declared limits are higher than the values in the file and the limits script runs in the isolated mode of the suite (stubs only, a scratch home)
- **THEN** the only sudo call recorded installs the declared content into `/etc/security/limits.d/ulimit.conf`


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

- **WHEN** the isolated mode of the suite runs a script whose `use_tool_dirs` lists a real directory
- **THEN** it refuses to run it


<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
