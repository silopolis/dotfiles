# agent-environment Specification

## Purpose
Which variables an agent started from the user's interactive shells may inherit: a shell function removes the secret-named variables from the agent's environment, leaves everything else alone, passes arguments and status through, keeps an explicit bypass, and is checked by counts, never by printing a name or a value.

## Requirements

In the scenarios below:

- the scenarios run from `tests/unit/agent-env.bats` of the `shell-test-harness` capability, and the scratch directory is a directory of mode 0700 below the temporary directory of the test; it holds a directory `bin` whose first file is a stub `opencode` that appends one line to a call log (a file in the scratch directory), prints, as one number, how many entries of its own `/proc/$$/environ` have a name matching the pattern (`tr '\0' '\n' < /proc/$$/environ | cut -d= -f1 | grep -Ec '(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY|ACCESS_?KEY|PRIVATE_?KEY|CREDENTIAL)'`), and prints its arguments, one per line, after a marker line;
- "the function" is the one defined by `home/dot_config/shell/rc.d/445-tools_opencode.sh`, loaded with `. <file>` in `zsh -c` or `bash -c` with `PATH` starting with that `bin`;
- each shell of a test starts under `env -i` with only `PATH`, `HOME` (a scratch directory) and the variables a scenario exports, so that the secret-named variables of the shell that runs the suite never enter a count;
- every `chezmoi` command takes `-S <worktree>` when run from a worktree, and the scenarios that read `~/.config/shell/rc.d/445-tools_opencode.sh` pass only after the target is deployed (task 5.1), while the others read the source file;
- "the synthetic set" is the exported variables `DEMO_API_KEY`, `DEMO_TOKEN`, `DEMO_DB_PASSWORD` (value with a space), `DEMO_APIKEY`, `DEMO_ACCESSKEY`, `DEMO_PRIVATE_KEY`, `DEMO_CREDENTIAL`, `DEMO_PASSWD` and `DEMO_SECRET_SAUCE`, each with a distinct canary value of 20 characters;
- the scenarios never print a name of a real variable or a value.

### Requirement: The function is defined in interactive shells

The repository SHALL deploy `~/.config/shell/rc.d/445-tools_opencode.sh`, which defines a function `opencode` in bash and in zsh and runs nothing when sourced.

#### Scenario: Defined in both shells

- **WHEN** `zsh -c '. ~/.config/shell/rc.d/445-tools_opencode.sh; whence -w opencode'` and `bash -c '. ~/.config/shell/rc.d/445-tools_opencode.sh; type -t opencode'` run
- **THEN** the first prints `opencode: function` and the second prints `function`

#### Scenario: Sourcing prints nothing and runs nothing

- **WHEN** the file is sourced in each shell with the stub on `PATH`
- **THEN** neither shell prints anything, and the stub's call log (a file the stub appends to) is empty

#### Scenario: Syntax and target

- **WHEN** `bash -n` and `zsh -n` run on the source file, and, once the target is deployed, `chezmoi -S <worktree> diff --exclude=externals,scripts ~/.config/shell/rc.d/445-tools_opencode.sh` runs
- **THEN** all three print nothing and exit 0

#### Scenario: Interactive shells load it

- **WHEN** a new interactive `zsh -i -c 'whence -w opencode'` runs
- **THEN** it ends with `opencode: function`

### Requirement: Secret-named variables are removed from the agent's environment

The function SHALL run the real `opencode` with `env -u NAME` for every exported variable whose name is made of uppercase letters, digits and underscores and contains one of `TOKEN`, `SECRET`, `PASSWORD`, `PASSWD`, `API_KEY`, `APIKEY`, `ACCESS_KEY`, `ACCESSKEY`, `PRIVATE_KEY`, `PRIVATEKEY` or `CREDENTIAL`.
The names SHALL be computed from the environment at each call, with no list of names in the file.

#### Scenario: The synthetic set is removed

- **WHEN** the synthetic set is exported and the function runs, in zsh and in bash
- **THEN** the stub prints `0` as its count of matching names, in both shells, and no canary value appears in the stub's output

#### Scenario: A variable added later is covered

- **WHEN** a variable `DEMO_LATER_TOKEN` is exported after the shell started and before the function runs
- **THEN** the stub's count is `0`

#### Scenario: No name is written in the file

- **WHEN** `rg -c 'DEMO_|_KEY=|_TOKEN=' home/dot_config/shell/rc.d/445-tools_opencode.sh` runs, and every name of the environment file is searched in the source file with `rg -c -F -f` (run locally, the list without empty lines, never printed, and a count instead of the matching lines, so a failure shows no name)
- **THEN** both print nothing

#### Scenario: A multi-line value does not break the call

- **WHEN** a variable `DEMO_NOTE` is exported with a value of two lines, the second starting with `DEMO_FAKE_TOKEN=`
- **THEN** the function exits with the stub's status and the stub's count is `0` or `1`, never an error from `env`

### Requirement: Everything else is left alone

The function SHALL NOT remove variables whose names do not match: sockets, paths, public values and lowercase or mixed-case names.
It SHALL NOT change the environment of the shell that called it.

#### Scenario: Non-matching names survive

- **WHEN** `SSH_AUTH_SOCK`, `XAUTHORITY`, `KITTY_PUBLIC_KEY`, `STARSHIP_SESSION_KEY` and `demo_lower_token` are exported with the synthetic set, and the function runs with a stub that prints which of them are present
- **THEN** the stub reports the first four present and `demo_lower_token` present, and the synthetic set absent

#### Scenario: The calling shell keeps its variables

- **WHEN** the function runs and the shell then prints, as a count, how many of the synthetic set it still holds
- **THEN** the count is the full size of the set

#### Scenario: No lowercase secret is hiding

- **WHEN** `env | cut -d= -f1 | grep -Eic '(token|secret|password|passwd|api_?key|access_?key|private_?key|credential)'` runs in an interactive shell of the user, and the same command with the uppercase pattern runs in `grep -Ec`
- **THEN** the two counts are equal (no lowercase or mixed-case secret-like name is set)

### Requirement: Arguments and status pass through

The function SHALL pass every argument to the real `opencode` unchanged, including arguments with spaces and quotes, and SHALL return its exit status.

#### Scenario: Arguments are unchanged

- **WHEN** the function runs with the arguments `-s`, `ses_demo`, `run`, `two words` and `--flag=1`
- **THEN** the stub prints exactly those five arguments, one per line

#### Scenario: Exit status

- **WHEN** the stub exits 7
- **THEN** the function returns 7, in both shells

#### Scenario: No recursion

- **WHEN** no real `opencode` is on `PATH`
- **THEN** the function returns 127 after one message from `env` that `opencode` is not found, in both shells, instead of calling itself

### Requirement: The bypass is explicit

`command opencode` SHALL run the real binary with the full environment, and AGENTS.md SHALL say so.

#### Scenario: Bypass keeps the environment

- **WHEN** the synthetic set is exported and `command opencode` runs with the stub
- **THEN** the stub's count is the size of the synthetic set

#### Scenario: Documented

- **WHEN** `rg -n 'command opencode' AGENTS.md` runs
- **THEN** it prints the line that documents the bypass

### Requirement: A herdr-started agent holds none of them

An agent that herdr starts in a pane SHALL hold no secret-named variable.

#### Scenario: Live agent process

- **WHEN** a new tab is created in the workspace, `herdr agent start probe --kind opencode --pane <its pane>` runs after the target is deployed, and the count `tr '\0' '\n' < /proc/<pid>/environ | cut -d= -f1 | grep -Ec '<pattern>'` runs with the pid from `herdr pane process-info --pane <its pane>`
- **THEN** the count is `0`, and the same count for the shell of that pane is greater than `0` while the environment file still sets variables

#### Scenario: opencode still works

- **WHEN** the same agent is running
- **THEN** `herdr agent get probe` reports it idle or working, `opencode models anthropic` run through the function prints at least one model id, and `opencode auth list` shows the stored providers

#### Scenario: The probe tab is removed

- **WHEN** the check is done and `herdr tab close <tab id>` runs
- **THEN** `herdr tab list --workspace <id>` shows only the tabs that existed before

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
