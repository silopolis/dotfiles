# shell-startup Specification

## Purpose
How fast and how cleanly the user's bash and zsh start: the interactive and login startup times, one load of the shared `rc.d` configuration per interactive shell, no output unless debugging is asked for, cached completion scripts, the behaviour a startup change must keep (private environment, the `opencode` function, aliases and functions, the desktop session's environment), the aliases file free of shellcheck errors, and bash login on a bare terminal.
The environment a shell provides (`PATH`, locale, exported secrets, umask) is the capability of `correct-shell-environment`.

## Requirements

### Requirement: Fast startup

An interactive zsh SHALL start in at most 1.0 s (median of at least 7 alternating runs, in a terminal), and a login interactive zsh in at most 150 ms more.

#### Scenario: Interactive startup time

- **WHEN** `zsh -i -c exit` is timed at least 7 times, alternating with the other shell kinds, on the laptop under a pseudo-terminal
- **THEN** the median is at most 1.0 s

#### Scenario: Login startup time

- **WHEN** `zsh -l -i -c exit` is timed in the same rounds
- **THEN** its median is at most the interactive median plus 150 ms

### Requirement: Single load of the interactive configuration

Each interactive shell SHALL source `rc.d` exactly once, whether it is a login shell or not, in zsh and in bash.
A non-interactive login shell SHALL load what it loads today, once.

#### Scenario: Login zsh

- **WHEN** `SHELL_RC_DEBUG=1 zsh -l -i -c exit 2>&1 | grep -c 'rc.d'` counts the debug line printed once per `rc.d` pass
- **THEN** it prints 1

#### Scenario: The other interactive shells

- **WHEN** the same count runs for `zsh -i -c exit`, `bash -i -c true` and `bash -l -i -c true`
- **THEN** each prints 1

#### Scenario: Non-interactive login zsh

- **WHEN** the same count runs for `zsh -l -c true`
- **THEN** it prints 1

#### Scenario: Completion dump

- **WHEN** a login zsh and a normal zsh start one after the other, five times
- **THEN** the `#files:` header of the completion dump is the same after each start

### Requirement: Silent startup

Shell startup SHALL print nothing on standard output or standard error unless debugging is requested with `SHELL_RC_DEBUG`.

#### Scenario: No output with a terminal

- **WHEN** `zsh -i -c exit`, `zsh -l -i -c exit`, `bash -i -c true` and `bash -l -i -c true` run under a pseudo-terminal and their output is counted
- **THEN** each prints 0 bytes

#### Scenario: No output without a terminal

- **WHEN** `zsh -i -c exit 2>&1 </dev/null | wc -c` runs
- **THEN** it prints 0

#### Scenario: Debug output

- **WHEN** `SHELL_RC_DEBUG=1 zsh -i -c exit 2>&1 >/dev/null` runs under `sh -c`, so that zsh's own redirection rules do not apply
- **THEN** the debug lines are on standard error and none is on standard output

### Requirement: Cached completions

The completion scripts of kubectl, minikube, kind, gh, glab, localstack, infracost and docker SHALL come from cache files generated on demand: used while the tool resolves to the file the cache was made for and is not newer than the cache, regenerated silently otherwise, and never half written.

#### Scenario: Cache hit

- **WHEN** a second interactive shell starts after the first one filled the cache
- **THEN** no completion generator runs (a call log of stub tools counts 0 calls)

#### Scenario: Tool changed

- **WHEN** a stub tool is replaced by another file at the same name, or made newer than its cache file
- **THEN** the next start regenerates that tool's cache file and the others are left as they were

#### Scenario: Failing generator

- **WHEN** a tool's completion command exits with an error or prints nothing
- **THEN** no cache file is created for it, an older cache file is kept and used, and the start prints nothing

#### Scenario: Completion still works

- **WHEN** an interactive zsh started with the cache filled is asked for the completions registered for each cached tool, and the same is done in bash
- **THEN** each tool is registered, with the same functions and registrations as with the previous startup (`_comps` and function names compared in zsh)

#### Scenario: Refresh

- **WHEN** a shell starts with `SHELL_COMPLETION_REFRESH=1`
- **THEN** every cache file is regenerated

### Requirement: Behaviour that a startup change must keep

Speeding up and silencing startup SHALL NOT change what the private environment file and `rc.d/010-env_user.sh` export and unset, the order in which the private environment file is sourced, the `opencode` function, the aliases and functions defined at startup, or the environment of a non-interactive login shell.

#### Scenario: Private environment

- **WHEN** a synthetic private environment file with `DEMO_` names is present, and a synthetic value is set under the name that `010-env_user.sh` unsets, and a shell starts under `env -i`
- **THEN** every `DEMO_` name is set, the unset name is not, in the same way before and after the change

#### Scenario: opencode function

- **WHEN** an interactive zsh and an interactive bash define `opencode` and call it with a stub binary and synthetic secret-named variables
- **THEN** the stub holds none of them and the arguments and exit status pass through, as in the `agent-environment` capability

#### Scenario: Aliases and functions

- **WHEN** the names of the aliases and functions of an interactive shell are listed before and after the change
- **THEN** the lists are equal, with four exceptions: the `cm*` aliases that expanded the source path at definition (they expand to the same words once used), `mkcd`, `cmmkdir` and `cmtouch`, which became functions (below), the helper `_cached_completion`, and the functions of the infracost completion script, which its broken call never defined in zsh

#### Scenario: Desktop session environment

- **WHEN** the display manager's call is replayed (`emulate -R zsh; . ~/.zprofile` in a non-interactive zsh under `env -i`) before and after the change
- **THEN** the exported variables, names and values, are equal, `PATH` included

#### Scenario: Interactive login shell

- **WHEN** the names of the exported variables of `zsh -l -i` and `bash -l -i` are compared before and after the change, and the `PATH` of `zsh -l -i` is compared with the one of `zsh -i`
- **THEN** the names are equal, and the two `PATH` values are equal: the second pass of the old login shell had added a nested aqua directory that does not exist and moved the real one (audit F18, which moved to `correct-shell-environment`)

### Requirement: Aliases file passes shellcheck at error level

`home/dot_config/shell/aliases` SHALL have no shellcheck finding at error level, and the commands it defines SHALL take their arguments as the user types them.

#### Scenario: shellcheck

- **WHEN** `shellcheck -s bash -S error home/dot_config/shell/aliases` runs
- **THEN** it reports nothing

#### Scenario: Commands that take arguments

- **WHEN** `mkcd "a b/c"`, `cmmkdir "x y" z`, `cmtouch "x y/f"`, `gbc main`, `gbbc main`, `vagrant-libvirt ssh-config "two words"` and `convert_to_png "dir with space"` run in an interactive zsh and an interactive bash, with stub tools and a scratch source path
- **THEN** each creates, lists or passes exactly what its arguments name, the `cm*` functions work relative to the source path and leave the current directory alone, and `convert_to_png` without an argument prints a usage line and returns 1

### Requirement: bash login on a bare terminal

A bash login shell started with a minimal environment SHALL load the shared configuration.

#### Scenario: Minimal environment

- **WHEN** `env -i HOME="$HOME" TERM=xterm bash -l -i -c 'alias cm'` runs
- **THEN** it prints the `cm` alias

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
