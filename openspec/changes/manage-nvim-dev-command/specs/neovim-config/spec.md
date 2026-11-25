## ADDED Requirements

### Requirement: A development command starts the development checkout with its own application name

The command `nvim-dev` SHALL be a managed executable at `~/.local/bin/nvim-dev` that runs `nvim` with `NVIM_APPNAME=nvim-dev` and the arguments of its caller unchanged, and returns the exit status of `nvim`.
It SHALL refuse to start when the profile `$XDG_CONFIG_HOME/nvim-dev` (`~/.config/nvim-dev` when the variable is unset) does not exist, saying on standard error which path is missing and exiting with status 1, and it SHALL NOT create the profile or the clone it stands for.
It SHALL be a POSIX shell script that needs no alias, so that scripts and panes that do not read the aliases file start the same editor, and it SHALL hold no home directory path, host name or e-mail address.

#### Scenario: Starts the development profile

- **WHEN** the profile exists, `nvim` is a stub that records `NVIM_APPNAME` and its arguments, and `nvim-dev a "b c"` runs with another `NVIM_APPNAME` in its environment
- **THEN** the stub is called once, with `NVIM_APPNAME` equal to `nvim-dev` and the two arguments `a` and `b c`

#### Scenario: Arguments and status come back unchanged

- **WHEN** `nvim-dev` runs with an empty argument, a glob, a quote, a dollar sign, a leading dash and `--`, and the stub exits with status 7
- **THEN** the stub received exactly those arguments in that order, and `nvim-dev` exits with status 7

#### Scenario: The profile follows the XDG directory

- **WHEN** `XDG_CONFIG_HOME` names a directory that holds `nvim-dev` and the home directory holds none, or the other way round
- **THEN** the first case starts the stub, and the second is refused with a message that names the path below `XDG_CONFIG_HOME`

#### Scenario: A missing profile is refused

- **WHEN** the profile path does not exist, or is a symlink to a path that does not exist, and `nvim-dev x` runs
- **THEN** nothing is printed on standard output, standard error names the profile path, the exit status is 1, the stub is not called, and no file or directory is created

#### Scenario: Works without aliases and in the usual shells

- **WHEN** the file runs under `env -i`, with a `PATH` that holds the stub, through `sh`, `dash` and `bash`, and as a program found on that `PATH`
- **THEN** each run starts the stub as in the first scenario

#### Scenario: Portable and published as it is

- **WHEN** the file is checked with `shellcheck -s sh`, `dash -n` and `bash -n`, and searched for a home directory path and an e-mail address
- **THEN** the three syntax checks pass, its first line is `#!/bin/sh`, and the search finds nothing

#### Scenario: The target is managed and executable

- **WHEN** `chezmoi dump` reads the target `.local/bin/nvim-dev` of the source state
- **THEN** it is a file whose mode has the owner's executable bit and whose content equals `home/dot_local/bin/executable_nvim-dev`

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
