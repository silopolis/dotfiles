## ADDED Requirements

<!-- Moved without edit from the draft of fast-correct-shell-startup on 2026-11-16: refine them when this change is worked (/opsx-continue correct-shell-environment). -->

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

### Requirement: Opt-in token exposure

API tokens SHALL not be present in the environment of a new shell unless the user loads them, through the mechanism recorded in this change's design.

#### Scenario: Fresh shell has no tokens

- **WHEN** the names of the variables defined in the encrypted environment file are checked in a new shell's environment
- **THEN** none is set

#### Scenario: Loader

- **WHEN** the user runs the documented loader in a shell
- **THEN** the tokens are available in that shell and its children only

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
