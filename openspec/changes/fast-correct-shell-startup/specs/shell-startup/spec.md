## ADDED Requirements

### Requirement: Fast startup

An interactive zsh SHALL start in at most 1.0 s (median of 5 runs), and a login interactive zsh in at most 10 % more.

#### Scenario: Interactive startup time

- **WHEN** `zsh -i -c exit` is timed 5 times on the laptop
- **THEN** the median is at most 1.0 s

#### Scenario: Login startup time

- **WHEN** `zsh -l -i -c exit` is timed 5 times
- **THEN** the median is at most 1.1 times the interactive median

### Requirement: Single load of the interactive configuration

Each shell SHALL source `rc.d` exactly once, whatever the combination of login and interactive.

#### Scenario: Login zsh

- **WHEN** `SHELL_RC_DEBUG=1 zsh -l -i -c exit 2>&1 | grep -c 'rc.d'` counts the debug line printed once per `rc.d` pass
- **THEN** it prints 1

### Requirement: Silent startup

Shell startup SHALL print nothing on standard output or standard error unless debugging is requested.

#### Scenario: No output

- **WHEN** `zsh -i -c exit 2>&1 | wc -c` and `bash -i -c exit 2>&1 | wc -c` run in a terminal
- **THEN** both print 0

### Requirement: Clean PATH

`PATH` SHALL keep inherited entries, contain no duplicates and no missing directories, and start with the user's own bin directories.

#### Scenario: No duplicates

- **WHEN** `echo "$PATH" | tr ':' '\n' | sort | uniq -d` runs in a new interactive shell
- **THEN** it prints nothing

#### Scenario: User bin first

- **WHEN** `echo "$PATH" | tr ':' '\n' | head -1` runs
- **THEN** it prints `$HOME/.local/bin`

#### Scenario: Nested shells do not grow PATH

- **WHEN** the `PATH` length of a shell and of a shell started inside it are compared
- **THEN** they are equal

### Requirement: Working locale

The shell SHALL set only locales that are generated on the machine and SHALL not force `LC_ALL`.

#### Scenario: No locale warnings

- **WHEN** `bash -i -c exit` runs
- **THEN** no `setlocale` warning is printed, and `LC_ALL` is empty in the environment

### Requirement: bash login on a bare terminal

A bash login shell started with a minimal environment SHALL load the shared configuration.

#### Scenario: Minimal environment

- **WHEN** `env -i HOME="$HOME" TERM=xterm bash -l -i -c 'alias cm'` runs
- **THEN** it prints the `cm` alias

### Requirement: Opt-in token exposure

API tokens SHALL not be present in the environment of a new shell unless the user loads them, through the mechanism recorded in this change's design.

#### Scenario: Fresh shell has no tokens

- **WHEN** the names of the variables defined in the encrypted environment file are checked in a new shell's environment
- **THEN** none is set

#### Scenario: Loader

- **WHEN** the user runs the documented loader in a shell
- **THEN** the tokens are available in that shell and its children only

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
