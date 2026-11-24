## ADDED Requirements

In the scenarios below:

- "the render" is a scratch render of the shell targets (`tests/helpers/render.sh`), and every shell starts on it under `env -i` with a scratch home, as the `shell-test-harness` capability describes;
- "the private file" is `~/.config/env` of that scratch home, a synthetic file that exports two `DEMO_` names, one of them matching the secret pattern of the `agent-environment` capability;
- "the desktop replay" is the call of the display manager replayed in a non-interactive zsh: `emulate -R zsh`, then `/etc/zsh/zprofile` and `~/.zprofile` sourced, with the `PATH`, `LANG`, `SHELL`, `USER` and `LOGNAME` that the user manager hands to a session;
- "the shell kinds" are the desktop replay, `zsh -i`, `zsh -l -i`, `bash -i`, `bash -l -i` (under a pseudo-terminal), `zsh -l -c`, `zsh -c`, `bash -l -c`, `bash -c`, and `zsh -i`, `bash -i` and `bash -l -i` started without `LANG`;
- "a count" is printed instead of names or values, and no scenario prints a name or a value of the real environment.

### Requirement: The desktop login loads the environment only

A non-interactive login shell of bash or zsh SHALL source `shell/environment`, which sources the `rc.d/*-env_*.sh` files in name order, and SHALL source no other `rc.d` file, no private file and no interactive configuration.
Any other login shell, `sh` among them, SHALL load nothing, as before: the `env_` files are written for bash and zsh and use `source`.

#### Scenario: No rc.d pass in the desktop replay

- **WHEN** the desktop replay, `zsh -l -c true` and `bash -l -c true` run with `SHELL_RC_DEBUG=1` and their standard error is counted
- **THEN** each prints 0 lines that contain `rc.d` and 1 line of `shell/environment`

#### Scenario: What the session keeps

- **WHEN** the desktop replay lists its exported names
- **THEN** `PATH`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`, `LANG`, `LANGUAGE`, `EDITOR` and `CURRENT_SHELL` are set, and `HOMEBREW_PREFIX` is set when brew is installed

#### Scenario: What the session no longer gets

- **WHEN** the desktop replay lists its exported names
- **THEN** none starts with `forgit_`, `LESS_TERMCAP_` or `__MISE_`, and `LS_COLORS`, `LESSOPEN`, `HSTR_CONFIG`, `MISE_SHELL` and `LC_ALL` are not set

#### Scenario: Only env_ files hold the environment

- **WHEN** the `rc.d` files whose names do not contain `-env_` are searched for `export` and for assignments to `PATH`
- **THEN** none exports a variable that the desktop replay sets, and none changes `PATH` except mise's activation in `415-tools_mise.sh`

#### Scenario: A login sh loads nothing

- **WHEN** `sh -l -c true` runs on the render, once without and once with `SHELL_RC_DEBUG=1`, on a machine where `sh` is not bash (the test skips, naming it, where it is)
- **THEN** the first run prints nothing, the second prints only the debug line of `profile` (0 lines that contain `rc.d`, 0 lines of `shell/environment`), and neither exports a name that an `env_` file sets

### Requirement: No key in a new shell

The startup files SHALL NOT export the variables of the private file: neither the desktop session nor a new shell holds them unless the user loads them.

#### Scenario: Every shell kind

- **WHEN** each shell kind counts how many names of the private file it exports
- **THEN** every count is 0

#### Scenario: Inherited copies are dropped

- **WHEN** `zsh -i` and `bash -i` start with both names of the private file in their environment and without `DOTFILES_SECRETS`
- **THEN** each counts 0 of them

#### Scenario: The revoked variable stays unset

- **WHEN** a shell kind starts with a synthetic value under the name that `rc.d/010-env_user.sh` unsets
- **THEN** that name is not exported, in the desktop replay and in every interactive kind

### Requirement: Keys on demand

An interactive shell SHALL define a function `secrets`: `secrets load` exports the variables of the private file into the calling shell and exports `DOTFILES_SECRETS=loaded`, `secrets unload` unsets every name the private file sets, and `secrets` alone prints how many of those names are set.
The names SHALL be read from the private file at each call, and no name of a variable SHALL be written in the startup files.

#### Scenario: Load in the calling shell and its children

- **WHEN** an interactive zsh and an interactive bash run `secrets load`, then count the names of the private file in their own environment and in a child `sh -c`
- **THEN** both counts are 2 in each shell, and a new interactive shell started next to it, not from it, counts 0

#### Scenario: A child shell keeps what its parent loaded

- **WHEN** an interactive zsh runs `secrets load` and then starts an interactive zsh inside it
- **THEN** the inner shell counts 2

#### Scenario: Unload and status

- **WHEN** a shell runs `secrets load`, `secrets`, `secrets unload` and `secrets` again
- **THEN** the two `secrets` calls print `2` and `0`, and no name of the private file appears in the output

#### Scenario: No private file

- **WHEN** `secrets load` runs in a shell whose home has no private file
- **THEN** it prints one line that says so, returns 1 and sets nothing

#### Scenario: No name in the repository

- **WHEN** `rg -c 'DEMO_|_KEY=|_TOKEN=' home/dot_config/shell/rc.d/446-tools_secrets.sh home/dot_config/shell/rc.d/010-env_user.sh` runs, and the names of the user's real private file are searched in the shell source with `rg -c -F -f` (a live test, the list held in memory)
- **THEN** both print nothing

### Requirement: Clean PATH

After the startup files, `PATH` SHALL hold no duplicate and no missing directory, keep the inherited entries that are directories, put the user's bin directories before every system and package-manager directory, and stay the same in a nested shell.
In an interactive shell, the directories that mise's activation adds may come before the user's bin directories.

#### Scenario: No duplicates and no missing directory

- **WHEN** each shell kind that loads the environment prints its `PATH`, split on `:`
- **THEN** no entry appears twice and every entry is a directory

#### Scenario: Inherited entries are kept

- **WHEN** an interactive zsh starts with a scratch directory `inherited` at the end of `PATH`, and the desktop replay runs on a render that holds a fixture file named like an `env_` file, sorted before `040`, which adds that directory to `PATH` (the replay sources `/etc/profile`, which resets the inherited `PATH` before any file of the user runs)
- **THEN** the `PATH` of each holds `inherited` once

#### Scenario: User bin directories first

- **WHEN** the desktop replay prints its `PATH` on a render whose home holds `.local/bin`
- **THEN** the first entry is `$HOME/.local/bin` or `$HOME/.local/sbin`, and both come before every brew and system directory

#### Scenario: Nested shells do not grow PATH

- **WHEN** an interactive zsh starts an interactive zsh which starts a third, and the same is done in bash and from the desktop replay
- **THEN** the three `PATH` values of each chain have the same entries, and `AQUA_BIN_DIR` is the same at each level

#### Scenario: The helper

- **WHEN** `_path_prepend` is called in zsh and in bash with a directory already on `PATH`, a missing directory and a new directory
- **THEN** the first moves to the front, the second is not added, the third is added at the front, and nothing else changes

### Requirement: Working locale

The startup files SHALL NOT set `LC_ALL`, SHALL drop an inherited `LANG`, `LC_ALL` or `LC_*` that names a locale which is not generated, SHALL default an unset `LANG` to `en_US.UTF-8` when it is generated and to `C.UTF-8` otherwise, and SHALL default `LANGUAGE` to `en_US:en`.

#### Scenario: No forced LC_ALL

- **WHEN** each shell kind that loads the environment starts without `LC_ALL`
- **THEN** `LC_ALL` is unset in each, and `LANG` keeps the value it was started with

#### Scenario: No locale warnings from the user's files

- **WHEN** each shell kind runs `perl -e1`, and the interactive kinds started without `LANG` do the same
- **THEN** no line of their output contains `setlocale` or `locale failed`

#### Scenario: An inherited missing locale is dropped

- **WHEN** `zsh -i` and `bash -i` start with `LC_ALL` and `LC_CTYPE` set to a locale that is not generated
- **THEN** both variables are unset after startup, and a child `perl -e1` prints no locale warning

#### Scenario: Default when LANG is unset

- **WHEN** an interactive shell starts without `LANG`
- **THEN** `LANG` is `en_US.UTF-8` when `locale -a` lists it, and `C.UTF-8` otherwise

#### Scenario: The man alias takes effect

- **WHEN** an interactive shell started with `LANG=fr_FR.UTF-8` runs `LANG=C date -d 2026-11-20 +%A` on a machine where `fr_FR.UTF-8` is generated
- **THEN** it prints `Friday`

### Requirement: The shared interactive configuration is interactive-only

`shellrc` SHALL return at once in a shell that is not interactive, and no startup file SHALL source it from a non-interactive shell.

#### Scenario: Non-interactive source

- **WHEN** `zsh -c '. ~/.config/shell/shellrc; echo done'` and the same in `bash -c` run with `SHELL_RC_DEBUG=1`
- **THEN** each prints `done` and 0 lines that contain `rc.d`

#### Scenario: bash started for an ssh command

- **WHEN** `bash -c true` runs with `SSH_CLIENT` set and a shell level of 0, as sshd starts it
- **THEN** it counts 0 names of the private file and prints 0 lines that contain `rc.d`

### Requirement: Highlighting loads last

The file that loads zsh-syntax-highlighting SHALL be the last `rc.d` file in name order.

#### Scenario: Last file

- **WHEN** `ls home/dot_config/shell/rc.d | tail -n 1` runs
- **THEN** it prints the file that sources `zsh-syntax-highlighting.zsh`

### Requirement: History under XDG state

zsh and bash SHALL keep their history in `$XDG_STATE_HOME/zsh/history` and `$XDG_STATE_HOME/bash/history`, in directories of mode 0700 and files of mode 0600, and SHALL move a legacy history file there without losing an entry.

#### Scenario: Paths

- **WHEN** an interactive zsh and an interactive bash print `HISTFILE`
- **THEN** they print the two paths under `$XDG_STATE_HOME`

#### Scenario: First start moves the legacy file

- **WHEN** a scratch home holds a synthetic `~/.zsh_history` of mode 0600 with multi-line entries and no new file, and an interactive zsh starts, and the same is done with a synthetic `~/.bash_history` and an interactive bash
- **THEN** in each case the new file holds every entry, its mode is 0600, its directory's mode is 0700, and the legacy path is a symbolic link to it

#### Scenario: Two shells at once

- **WHEN** two interactive shells of the same kind start at the same moment on such a home, in zsh and in bash
- **THEN** both print nothing, and the new file holds every entry once

#### Scenario: Merge after a trim

- **WHEN** the legacy path is a regular file again, holding entries the new file lacks, and an interactive zsh starts, and the same is done for bash
- **THEN** the new file's mode is 0600 and the legacy path is a symbolic link to it again; the zsh file holds every entry of both files once, in timestamp order; the bash file, whose entries carry no timestamp, holds the lines of the new file followed by the lines of the legacy file that it lacks, a repeated command kept as many times as it was typed

#### Scenario: A failed merge loses nothing

- **WHEN** the legacy path is a regular file again, holding entries the new file lacks, and the merge tool fails during the start of an interactive zsh (it exits with an error, it is missing, or it prints part of its output and then fails), and the same is done for bash
- **THEN** the shell prints nothing, the new file keeps all its lines, and the legacy path stays a regular file with all its lines, so that the next start merges it; no temporary file is left in the directory of the new file

### Requirement: Dead startup files are removed

The profiling stubs `005-dbg_prof_enable.sh` and `995-dbg_prof_results.sh`, the empty `130-pkg-flatpack.sh` and `200-lang_python.sh`, `930-highlighting.sh` under its old name, the old names of the files that became `env_` files, `~/.config/zsh/zshrc` and `~/.config/bash/bashrc` SHALL be absent from the source state and listed in `home/.chezmoiremove`.

#### Scenario: Source and removal list

- **WHEN** each of those targets is looked up with `chezmoi -S <worktree> managed` and in `home/.chezmoiremove`
- **THEN** none is managed and each is listed

### Requirement: The session's umask comes from the login

The startup files SHALL NOT set a umask; the user's sessions SHALL get umask 0027 from the login, through the script of the `install-scripts` capability.

#### Scenario: Startup leaves the umask alone

- **WHEN** the desktop replay, `zsh -i` and `bash -l -i` start once with umask 0027 and once with umask 0002, and print `umask` after startup
- **THEN** each prints the umask it was started with

#### Scenario: After the next login

- **WHEN** the umask of the systemd user manager, of `plasmashell` and of a new interactive shell is read from `/proc/<pid>/status` (a live test)
- **THEN** each is `0027`

#### Scenario: The live session holds no key

- **WHEN** `systemctl --user show-environment` and the environment of the terminal process are reduced to names and counted against the names of the user's private file (a live test, the list held in memory)
- **THEN** both counts are 0

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
