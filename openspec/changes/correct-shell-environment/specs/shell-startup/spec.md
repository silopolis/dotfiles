## MODIFIED Requirements

### Requirement: Single load of the interactive configuration

Each interactive shell SHALL source `rc.d` exactly once, whether it is a login shell or not, in zsh and in bash.
A non-interactive login shell SHALL source no `rc.d` pass and SHALL load the environment part once, as the `shell-environment` capability describes.

#### Scenario: Login zsh

- **WHEN** `SHELL_RC_DEBUG=1 zsh -l -i -c exit 2>&1 | grep -c 'rc.d'` counts the debug line printed once per `rc.d` pass
- **THEN** it prints 1

#### Scenario: The other interactive shells

- **WHEN** the same count runs for `zsh -i -c exit`, `bash -i -c true` and `bash -l -i -c true`
- **THEN** each prints 1

#### Scenario: Non-interactive login shells

- **WHEN** the same count runs for `zsh -l -c true` and `bash -l -c true`
- **THEN** each prints 0, and each prints the debug line of `shell/environment` once

#### Scenario: Completion dump

- **WHEN** a login zsh and a normal zsh start one after the other, five times
- **THEN** the `#files:` header of the completion dump is the same after each start

### Requirement: Behaviour that a startup change must keep

A startup change SHALL NOT export the variables of the private environment file, SHALL NOT stop `rc.d/010-env_user.sh` from unsetting the name it unsets, and SHALL NOT change the `opencode` function, the aliases and functions defined at startup, the exported names of login shells or the environment of a non-interactive login shell, except for the names that the change lists, with its reasons, in the allow file of its comparison with the previous ref.

#### Scenario: Private environment

- **WHEN** a synthetic private environment file with `DEMO_` names is present, a synthetic value is set under the name that `010-env_user.sh` unsets, and `zsh -i`, `bash -i`, `zsh -l -i` and the replay of the display manager's call start under `env -i`
- **THEN** none of them exports a `DEMO_` name or the unset name

#### Scenario: opencode function

- **WHEN** an interactive zsh and an interactive bash define `opencode` and call it with a stub binary and synthetic secret-named variables
- **THEN** the stub holds none of them and the arguments and exit status pass through, as in the `agent-environment` capability

#### Scenario: Aliases and functions

- **WHEN** the names of the aliases and functions of an interactive shell are listed on the previous ref and on the change (`DOTFILES_TEST_BASE_REF`)
- **THEN** the lists are equal, except the names listed in the change's allow file (`DOTFILES_TEST_BASE_ALLOW`)

#### Scenario: Desktop session environment

- **WHEN** the display manager's call is replayed (`emulate -R zsh; . ~/.zprofile` in a non-interactive zsh under `env -i`) on the previous ref and on the change
- **THEN** the exported variables, names and values, are equal, `PATH` included, except the names listed in the change's allow file

#### Scenario: Interactive login shell

- **WHEN** the names of the exported variables of `zsh -l -i` and `bash -l -i` are compared on the previous ref and on the change, and the `PATH` of `zsh -l -i` is compared with the one of `zsh -i`, both started from the `PATH` that `/etc/profile` gives a login shell (read at run time from a login shell under a scratch home that holds no user file)
- **THEN** the names are equal except the names listed in the change's allow file, and the two `PATH` values are equal, so that a second pass which adds or nests an entry makes the comparison fail

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
