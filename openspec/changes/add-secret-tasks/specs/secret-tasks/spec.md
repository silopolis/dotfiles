## ADDED Requirements

In the scenarios below:

- "the fake provider" is `tests/global-mise-tasks/fake_provider.py`, an HTTP server on 127.0.0.1 with scripted answers per path that logs, for each request, the path and whether a credential was present, never the credential;
- "the fake chezmoi" is `tests/global-mise-tasks/fake_chezmoi.py`, a test double first on `PATH` that implements `cat`, `encrypt`, `source-path` and `apply` over a scratch directory (a reversible transform stands in for age) and logs every argument list;
- a "canary" is a synthetic string of 40 characters used as a key value, and a scenario that says "no output holds a canary" means that neither standard output, standard error, the fake chezmoi's argument log, the fake provider's log, nor any file under the scratch directory other than the fake ciphertext contains it;
- the scratch directory is under `/tmp/opencode` with mode 0700, `SECRET_TASKS_STORE` points inside it at a store whose `secrets/probes.toml` has entries for the synthetic variables `DEMO_VALID_KEY`, `DEMO_EXPIRED_KEY`, `DEMO_REJECTED_KEY` and `DEMO_DOWN_KEY` (each a different provider path or a closed port), and the environment file holds those four, `DEMO_OTHER_TOKEN` (no entry) and unrelated lines such as `export EDITOR=vi`;
- the source of the environment file is a scratch git repository, and `HERDR_ENV` is unset unless a scenario says otherwise.

### Requirement: The tasks are deployed and clean

The repository SHALL deploy the global file tasks `secret:check` and `secret:rotate` under `~/.config/mise/tasks/secret/` and their library under `~/.config/mise/lib/secret/`.
They SHALL be standard-library Python that compiles, SHALL hold no home path, user name, host name, credential or secret-variable name, and SHALL stop with exit 2 and a message when Python is older than 3.11.

#### Scenario: Tasks are listed

- **WHEN** `mise tasks ls --global` runs from a directory with no project config
- **THEN** it lists `secret:check` and `secret:rotate`

#### Scenario: Files compile and are executable

- **WHEN** `python3 -m py_compile` runs on every file under `home/dot_config/mise/tasks/secret/` and `home/dot_config/mise/lib/secret/`, and `stat -c '%a' ~/.config/mise/tasks/secret/*` runs
- **THEN** the first exits 0 and the second shows an executable mode for each task

#### Scenario: Targets match the source

- **WHEN** `chezmoi diff --exclude=externals,scripts ~/.config/mise/tasks/secret ~/.config/mise/lib/secret` runs
- **THEN** it prints nothing

#### Scenario: Nothing machine-specific and no real variable name

- **WHEN** `rg -n -e "$HOME" -e "$USER" home/dot_config/mise/tasks/secret home/dot_config/mise/lib/secret tests/global-mise-tasks` runs, and the variable names of the real probe table are searched in `git ls-files` with `rg -n -F -f` (run locally, the list never printed)
- **THEN** both print nothing

### Requirement: The probe table comes from the private store only

The tasks SHALL read the probe table from `secrets/probes.toml` in the private store: `$SECRET_TASKS_STORE`, else `$XDG_DATA_HOME/chezmoi-private`, else `~/.local/share/chezmoi-private`.
Each entry SHALL name a variable, an HTTPS URL (plain HTTP only for `127.0.0.1` and `::1`), an optional method (`GET` or `HEAD`), an authentication form (`bearer`, `header:<Name>` or `query:<param>`), the statuses that mean valid (default 200), the error codes that mean expired and a timeout of at most 30 seconds.
`secret:check` SHALL exit 2 and check nothing when the store, the table or the environment file is missing or invalid.

#### Scenario: The override wins

- **WHEN** `SECRET_TASKS_STORE` points at a scratch store while the default location also holds a table with other entries
- **THEN** `secret:check` reports the variables of the scratch table only

#### Scenario: Missing table

- **WHEN** `secret:check` runs with a store that has no `secrets/probes.toml`
- **THEN** it exits 2, names the missing file, prints no status line, and the fake provider's log is empty

#### Scenario: Invalid entry

- **WHEN** the table has an entry with a plain `http://` URL to a non-loopback host, another with a timeout of 99, and another with an unknown authentication form
- **THEN** `secret:check` exits 2 and names each invalid entry by position and field, with no value, and the fake provider's log is empty

### Requirement: secret:check reports one status per variable

`secret:check` SHALL decrypt the environment file in memory with `chezmoi cat <target>` (default target `~/.config/env`, `--target` to change it, `--source` passed through as `chezmoi -S`), SHALL make at most one request per probed variable, one after the other, and SHALL print one line per reported variable: its name and one of `valid`, `expired`, `rejected`, `unreachable` or `no probe`.
The reported variables SHALL be those with a table entry and every other exported name that ends in `_KEY`, `_TOKEN`, `_SECRET` or `_PASSWORD`.
It SHALL exit 0 only when every probed variable is `valid`, 1 when at least one probed variable is not, and 2 when nothing could be checked.
It SHALL never print a value, a prefix of a value, a length or a hash.

#### Scenario: Every status in one run

- **WHEN** the fake provider answers 200 to the first entry, 401 with the expired error code to the second, 403 with another code to the third, and the fourth entry points at a closed port
- **THEN** `secret:check` prints exactly five lines (`DEMO_VALID_KEY valid`, `DEMO_EXPIRED_KEY expired`, `DEMO_REJECTED_KEY rejected`, `DEMO_DOWN_KEY unreachable`, `DEMO_OTHER_TOKEN no probe`), exits 1, and `export EDITOR=vi` is not listed

#### Scenario: All valid

- **WHEN** the table and the file hold only the valid entry and the other token
- **THEN** it exits 0

#### Scenario: Unreachable does not stop the others

- **WHEN** the first entry points at a closed port and the second at a path that answers 200
- **THEN** the first line says `unreachable`, the second says `valid`, and the fake provider's log has one request for the second

#### Scenario: A value that uses shell expansion

- **WHEN** a probed variable's value is written as `"$(command)"` in the file
- **THEN** its line says `no probe`, and no command is run (a marker file the command would create does not exist)

#### Scenario: Decryption failure

- **WHEN** the fake chezmoi's `cat` exits 1
- **THEN** `secret:check` exits 2, prints one line naming the failed step, and makes no request

### Requirement: Requests are hardened

A request SHALL carry the credential only in the header or query parameter the table names, in memory, SHALL follow no redirect, SHALL use the table's timeout (at most 30 seconds), and SHALL never be retried.
An answer SHALL map to a status as follows: a status in the entry's valid list is `valid`; 401 or 403 with a JSON error code (`error.code`, else `code`) in the entry's expired codes is `expired`; any other 4xx, a redirect or an unreadable body is `rejected`; a timeout, a connection or certificate error, 429 or 5xx is `unreachable`.
No error message SHALL contain the request, its headers, its query or any part of a body.

#### Scenario: A redirect is not followed

- **WHEN** the fake provider answers 302 with a `Location` on a second loopback server
- **THEN** the status is `rejected` and the second server received 0 requests

#### Scenario: Timeout is bounded

- **WHEN** the fake provider waits 5 seconds and the entry's timeout is 1
- **THEN** the status is `unreachable` and the run took less than 4 seconds

#### Scenario: No key in any argument list

- **WHEN** `secret:check` runs with canary keys
- **THEN** the task's own argument list, the fake chezmoi's argument log and the arguments of every process started during the run hold no canary

#### Scenario: A provider that echoes the credential

- **WHEN** the fake provider answers 500 with a body that contains the credential it received
- **THEN** the status is `unreachable` and no output holds a canary

### Requirement: secret:rotate refuses what it cannot do safely

`secret:rotate <variable>` SHALL refuse, exit 1 and change nothing when standard input or output is not a terminal, when the variable is missing from the file or appears on more than one line, when the new value is empty, has control characters or surrounding whitespace, when the probe of the new value is not `valid`, and when the variable has no table entry and `--no-validate` is not given.
It SHALL read the new value only with hidden input from the terminal, never from an argument, an environment variable or a pipe, and SHALL ask for confirmation before writing unless `--yes` is given.

#### Scenario: No terminal

- **WHEN** `secret:rotate DEMO_EXPIRED_KEY` runs with a pipe as standard input
- **THEN** it exits 1 with a message that a terminal is required, the source file is unchanged (same hash), and the fake provider's log is empty

#### Scenario: New value is not valid

- **WHEN** it runs through a pseudo-terminal, a canary is typed and the fake provider answers 401 with the expired error code
- **THEN** it exits 1, the source file is unchanged, the fake chezmoi was never called with `encrypt`, and no output holds the canary

#### Scenario: Unknown or duplicated variable

- **WHEN** the variable is absent from the file, and in a second run appears on two lines
- **THEN** both runs exit 1, name the problem, ask for no value, and leave the source file unchanged

#### Scenario: Bad values

- **WHEN** an empty value, a value with a newline-like control character and a value with a trailing space are typed in three runs
- **THEN** each run exits 1 and leaves the source file unchanged

#### Scenario: Variable without a probe

- **WHEN** `secret:rotate DEMO_OTHER_TOKEN` runs without `--no-validate`, and again with it
- **THEN** the first exits 1 saying there is no probe, and the second goes on and says it did not validate the value

#### Scenario: Declined

- **WHEN** the confirmation is answered `n`
- **THEN** it exits 1 and the source file and the target are unchanged

### Requirement: secret:rotate replaces one line and leaves nothing behind

After a valid new value and a confirmation, `secret:rotate` SHALL build the new content in memory, pipe it to `chezmoi encrypt`, replace the source file through a temporary file in the same directory (mode 0600, removed on every exit path), verify with `chezmoi cat` that exactly one line differs and that its value matches the new one, apply that single target with `chezmoi apply --exclude=scripts`, stage the source file with `git add`, and print a proposed commit message that names no variable.
It SHALL write the new value as `export NAME='value'` (a quote written as `'\''`), keeping the original `export ` prefix or its absence.
It SHALL NOT commit, push, restart or signal any process, and SHALL write no plaintext file.

#### Scenario: Happy path

- **WHEN** it runs through a pseudo-terminal for `DEMO_EXPIRED_KEY`, a canary is typed, the probe answers 200 and the confirmation is `y`
- **THEN** it exits 0; decrypting the new source with the fake chezmoi shows exactly one line changed, whose value hashes to the canary's hash, and every other line byte-identical; the fake chezmoi's log has one `apply --exclude=scripts` with one target; `git diff --cached --name-only` in the source repository prints the source file only; `git rev-list --count HEAD` is unchanged; and no output holds the canary

#### Scenario: The proposed message names no variable

- **WHEN** the run of the happy path ends
- **THEN** the output line that starts with `chore(` is `chore(chezmoi:secrets): rotate an encrypted secret` and contains no variable name

#### Scenario: Quoting round trip

- **WHEN** the typed value holds a single quote, a dollar sign, a backquote and a space inside
- **THEN** `sh -c '. <decrypted line file>; printf %s "$DEMO_EXPIRED_KEY"' | sha256sum` equals the hash of the typed value (the decrypted copy is made by the test in its own scratch file)

#### Scenario: Failure at the verify step

- **WHEN** the fake chezmoi corrupts the output of `cat` after the source was replaced
- **THEN** it exits 1, restores the source file (same hash as before), applies nothing, stages nothing, and `ls -A` of the source directory shows no temporary file

#### Scenario: Interrupt

- **WHEN** SIGINT is sent while the task waits for the hidden value
- **THEN** it exits non-zero, the source file is unchanged and no temporary file remains

#### Scenario: No plaintext on disk

- **WHEN** the happy path has run
- **THEN** `rg -c -F` of the canary and of an unchanged secret value over the whole scratch directory finds them in no file except the fake ciphertext, and `find` shows no file named like a temporary plaintext

### Requirement: The holders of the old value are listed

After a rotation, `secret:rotate` SHALL list the processes of the current user whose start environment still holds the old value of the variable, comparing in memory and printing for each the process id, the command name, the working directory and, when exactly one herdr pane has that foreground working directory, its pane id.
It SHALL print that the list covers the environment at process start only, SHALL never print the old or the new value or a hash, and SHALL signal and restart nothing.

#### Scenario: A holder is listed and an innocent process is not

- **WHEN** a `sleep` is started with the old value in its environment, another `sleep` without it, and the rotation of that variable then runs through a pseudo-terminal with a fake `herdr` that lists one pane at the first process's working directory
- **THEN** the output lists the first process with its pane id and not the second, both processes are still alive afterwards, and no output holds a canary

#### Scenario: Unreadable process information

- **WHEN** `/proc` cannot be read (the test points the task at a missing proc directory)
- **THEN** the task prints a one-line message that the scan was skipped and still exits 0

### Requirement: A real age round trip

The rotation SHALL work with the real `chezmoi` and a real age identity.

#### Scenario: Throwaway identity

- **WHEN** a scratch chezmoi source, destination and configuration are made with a throwaway identity from `age-keygen`, the scratch environment file is encrypted into the source, and `secret:rotate` runs through a pseudo-terminal against a fake provider that answers 200
- **THEN** `chezmoi cat` of the scratch target gives content whose rotated line hashes to the typed value and whose other lines are unchanged, the target mode is 0600, and `age-keygen` missing makes the test report a skip with the reason

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
