## ADDED Requirements

In the scenarios below:

- "the suite" is the tests under `tests/` at the repository root, "a unit test" is a test file under `tests/unit/`, "a smoke test" one under `tests/smoke/`, and "a live test" one under `tests/smoke/` whose name ends in `-live.bats`;
- "the real home" is the home directory of the user who runs the suite, and "a scratch home" is a directory below `BATS_TEST_TMPDIR`;
- "a synthetic variable" has a name that starts with `DEMO_` and is built at run time, and "a canary" is a synthetic value of at least 20 characters built at run time that must never appear in any output;
- "the secret pattern" is the list of name fragments of the requirement "Secret-named variables are removed from the agent's environment" of the `agent-environment` capability, and a check that involves the names of the real environment holds them in memory and prints a count only;
- every `chezmoi` command takes `-S <worktree>` when run from a worktree;
- commands run at the repository root, in zsh unless they start with `bash`.

### Requirement: One command runs the suite

`mise run test` SHALL run the unit and smoke levels through `tests/run.sh`, which SHALL work from any directory, exit 0 when every test passes or is skipped, exit non-zero otherwise, and print the numbers of tests, failures and skips.

#### Scenario: Green run

- **WHEN** `mise run test` runs on the provisioned laptop
- **THEN** it exits 0, `tests/.reports/report.xml` exists, and `rg -c '<failure' tests/.reports/report.xml` finds no match

#### Scenario: A failing test fails the run

- **WHEN** `tests/run.sh` runs on a scratch copy of the suite that holds one test with a false assertion
- **THEN** it exits non-zero and the report holds exactly one `<failure`

#### Scenario: Any working directory

- **WHEN** `tests/run.sh` runs from `/` and from `tests/unit`
- **THEN** both runs report the same numbers of tests, failures and skips as a run from the repository root

#### Scenario: A level without a test file is not run

- **WHEN** `tests/run.sh` runs while `tests/e2e` does not exist
- **THEN** it exits 0 and does not report an empty suite as an error

### Requirement: The runner and its libraries are pinned

`mise.toml` SHALL pin `bats` to 1.14.0 through the aqua backend (`aqua:bats-core/bats-core`).
`tests/deps.txt` SHALL list bats-support, bats-assert and bats-file, each with its repository URL, its tag and the commit that the tag resolves to, and `mise run test:deps` SHALL leave `tests/.lib/<name>` at exactly that commit.
`tests/.lib/` and `tests/.reports/` SHALL be ignored by git.

#### Scenario: Runner version

- **WHEN** `rg -c 'bats-core/bats-core' mise.toml` and `mise exec -- bats --version` run
- **THEN** the first prints 1 and the second prints `Bats 1.14.0`

#### Scenario: Libraries at the pinned commits

- **WHEN** `mise run test:deps` has run and `git -C tests/.lib/<name> rev-parse HEAD` runs for each of the three libraries
- **THEN** each prints the commit that `tests/deps.txt` lists for that library

#### Scenario: A moved tag fails

- **WHEN** one commit of `tests/deps.txt` is changed in a scratch copy of the repository, `tests/.lib` is empty and `mise run test:deps` runs there
- **THEN** it exits non-zero, its message names the library, the tag and both commits, and no `tests/.lib/<name>` directory is left for that library

#### Scenario: Ignored directories

- **WHEN** `git check-ignore tests/.lib tests/.reports` runs
- **THEN** it prints both paths

### Requirement: Fetching the libraries needs no credential and no network once done

`mise run test:deps` SHALL fetch anonymously, with no credential helper, no prompt and no token, and SHALL do nothing when every library is already at its pinned commit.
When a library is missing and cannot be fetched, it SHALL exit non-zero, name the library, say that it must be run again online, and leave no partial directory.

#### Scenario: Already fetched, offline

- **WHEN** `https_proxy=http://127.0.0.1:9 mise run test:deps` runs after a successful run
- **THEN** it exits 0 and starts no clone

#### Scenario: Missing and offline

- **WHEN** `tests/.lib` is removed and `https_proxy=http://127.0.0.1:9 mise run test:deps` runs
- **THEN** it exits non-zero, names the first missing library, and `ls -A tests/.lib` lists nothing for it

#### Scenario: A stale token variable does not break the fetch

- **WHEN** a synthetic variable named after a GitHub token is exported with a canary value and `mise run test:deps` fetches into an empty `tests/.lib`
- **THEN** it exits 0, and the canary appears in no output

### Requirement: Tests are organised by level

`tests/` SHALL hold `unit/`, `smoke/`, `helpers/`, `fixtures/`, `mutants/`, `run.sh`, `deps.sh`, `deps.txt` and `README.md`, and no directory for a level that has no test yet.
`tests/README.md` SHALL define the levels:

- unit: one file or one rendered script runs under `env -i` with a scratch home, every tool it calls is a stub, nothing reaches the network, and a file takes seconds;
- smoke: real interactive shells start on a scratch render, or a real tool runs in a sandbox of scratch directories;
- e2e: an apply into a scratch destination or a disposable machine, opt-in.

It SHALL also classify `tests/global-mise-tasks/` and `tests/machine/` when those planned suites exist, without moving them.

#### Scenario: Directories

- **WHEN** `ls tests` runs
- **THEN** it lists `README.md`, `deps.sh`, `deps.txt`, `fixtures`, `helpers`, `mutants`, `run.sh`, `smoke` and `unit`, and no `e2e` while no e2e test exists

#### Scenario: Levels defined

- **WHEN** `rg -c '^### (Unit|Smoke|E2E)' tests/README.md` runs
- **THEN** it prints 3

#### Scenario: Unit tests start no terminal and apply nothing

- **WHEN** `rg -n -e 'script -qec' -e 'chezmoi.* apply' tests/unit` runs
- **THEN** it prints nothing

#### Scenario: Live tests are tagged

- **WHEN** `rg --files-without-match 'bats file_tags=.*live' tests/smoke/*-live.bats` runs
- **THEN** it prints nothing

#### Scenario: The other suites are classified

- **WHEN** `rg -n 'global-mise-tasks|machine' tests/README.md` runs
- **THEN** it prints the lines that give each of the two paths a level and its own runner

### Requirement: Tests are isolated from the machine

Every test SHALL run the code under test under `env -i`, with `PATH`, a scratch home and the variables that the test names, and SHALL NOT read or write the real home, the real chezmoi state or the real destination, except a live test, which only reads.
The suite SHALL check its own stubs and guards.

#### Scenario: The real home is left alone

- **WHEN** `ls -lR --time-style=full-iso ~/.config/shell ~/.config/chezmoi | sha256sum` and `test -e ~/.parallel; echo $?` run before and after `mise run test`
- **THEN** the hashes are equal and the two statuses are equal

#### Scenario: The environment is not inherited

- **WHEN** a synthetic variable that matches the secret pattern is exported to `tests/run.sh` and a test counts the names matching the pattern in the environment of the code under test
- **THEN** the count is `0`, and the canary appears in no output

#### Scenario: The harness checks itself

- **WHEN** `bats tests/unit/harness.bats` runs
- **THEN** it passes, and it proves that a stub logs its call and answers from a fixture, that `sudo` logs and exits without elevating, that a live-mode call outside the allow-list is refused and logged, and that isolated mode refuses a script whose `use_tool_dirs` lists a real directory

#### Scenario: The scratch destination starts empty

- **WHEN** the render helper of the smoke tests runs
- **THEN** its destination is a directory below the scratch directory of the test, with mode 0750, that held no entry before the apply, and the real home holds no entry that the apply wrote

### Requirement: A scratch render uses a synthetic configuration

The smoke tests that need a rendered home SHALL run `chezmoi apply` with `--config` on a generated configuration file, a `--destination` that is an empty scratch directory made beforehand (chezmoi does not create the root before a symlink target), a scratch `--persistent-state` and `--cache`, `--exclude=scripts,externals,encrypted`, and the shell targets only.
The generated configuration SHALL hold only synthetic data and no encryption setting, and SHALL NOT be rendered from `home/.chezmoi.toml.tmpl`, so that the render needs neither the real configuration nor `hostnamectl` and `lscpu`.
Tests that render `home/.chezmoi.toml.tmpl` itself SHALL skip when one of those two tools is absent.

#### Scenario: Synthetic data only

- **WHEN** the four identity keys `email`, `gitemail`, `name` and `firstname` of the generated configuration are read
- **THEN** each value starts with `demo-`, and the file holds no `encryption` or `age` key

#### Scenario: Neither scripts nor externals nor encrypted files

- **WHEN** the render has run
- **THEN** the destination holds no `.config/nvim` (an external) and no `.local/share/vsix` (written by a script), and no file ends in `.age`

#### Scenario: No dependence on the machine type

- **WHEN** the render helper runs with a `PATH` that holds neither `hostnamectl` nor `lscpu`
- **THEN** it exits 0

### Requirement: Nothing privileged runs

No test SHALL call `sudo`, install, uninstall or apply for real.
`sudo` SHALL be a logging stub in isolated and live modes, `chezmoi apply` SHALL be called only by the render helper, and `CHEZMOI_SCRIPTS_DRY_RUN` SHALL never be set on `chezmoi apply`.

#### Scenario: No direct sudo

- **WHEN** `rg -n '^\s*(run )?sudo ' tests/unit tests/smoke` runs
- **THEN** it prints nothing

#### Scenario: One place applies

- **WHEN** `rg -n 'chezmoi.* apply' tests` runs
- **THEN** it prints lines of `tests/helpers/render.sh` only, each with `--destination` and `--exclude=scripts,externals,encrypted`

#### Scenario: The dry-run variable is never applied

- **WHEN** `rg -n -e 'DRY_RUN.*apply' -e 'apply.*DRY_RUN' tests` runs
- **THEN** it prints nothing

### Requirement: Tests that read the machine are opt-in

A test that reads the real machine (the live read-only mode of the install scripts, the startup timing, the completion cache with real tools, the deployed targets, the lowercase-name count in the user's shell) SHALL be a live test and SHALL skip unless `DOTFILES_TEST_LIVE=1`, with a message that names the variable.
A live test SHALL only read, SHALL print counts, statuses and test names, and SHALL print no name or value of the real environment.
`mise run test:live` SHALL run the whole suite with the variable set.

#### Scenario: Skipped by default

- **WHEN** `mise run test` runs
- **THEN** every live test is reported skipped, and `rg -c 'DOTFILES_TEST_LIVE' tests/.reports/report.xml` prints at least 1

#### Scenario: A live run reads only

- **WHEN** `mise run test:live` runs with the home listing hash of the isolation scenario taken before and after
- **THEN** the hashes are equal, and the sudo log and the refused-command log of every live-mode run are empty

#### Scenario: No real name is printed

- **WHEN** the output of `mise run test:live` and the report are searched with `rg -c -F -f`, using the names of the exported variables that match the secret pattern as the list (held in memory, never printed)
- **THEN** the count is `0`

### Requirement: A missing tool skips the test

A test that needs a tool which is absent SHALL skip with a message that names the tool, and the run SHALL still exit 0.
The tests of a shell build that is absent (a Homebrew bash, for example) SHALL skip in the same way.

#### Scenario: Missing shellcheck

- **WHEN** `tests/run.sh` runs with a `PATH` that holds no `shellcheck`
- **THEN** it exits 0, and the report holds a `<skipped` whose message names `shellcheck` for each static-check test

#### Scenario: Missing second bash

- **WHEN** `tests/run.sh` runs on a machine where no Homebrew bash exists
- **THEN** the tests of that build are skipped with a message that names it, and the tests of zsh and of the system bash run

### Requirement: Reports are machine readable and scanned

`tests/run.sh` SHALL write a JUnit report to `tests/.reports/report.xml` with bats's `--report-formatter junit`, and SHALL fail when a canary value of the run appears in the report or in the output.

#### Scenario: Well-formed report

- **WHEN** `python3 -c 'import xml.etree.ElementTree as E; E.parse("tests/.reports/report.xml")'` runs after a run
- **THEN** it exits 0, and `rg -c '<testcase' tests/.reports/report.xml` equals the count printed by `bats --count -r tests/unit tests/smoke`

#### Scenario: A leaked canary fails the run

- **WHEN** `tests/run.sh` runs on a scratch copy of the suite that holds one test which prints a canary of the run
- **THEN** it exits non-zero and prints the number of matches, never the value

### Requirement: Parallel runs need no notice and no home file

`tests/run.sh` SHALL run the tests with `--jobs` when GNU parallel is found, SHALL set `PARALLEL=--will-cite` for that run only, and SHALL run the suite with a scratch home, so that it creates no `~/.parallel` and no shell startup file of the repository exports the variable.
Without GNU parallel, and when `DOTFILES_TEST_LIVE=1` (so that the timing tests share the machine with nothing), it SHALL run serially, and it SHALL print a line `jobs: <n>` before the first test.

#### Scenario: No file in the real home

- **WHEN** `test -e ~/.parallel; echo $?` runs before and after `mise run test` on a machine where that file does not exist
- **THEN** both print `1`

#### Scenario: Never exported by startup

- **WHEN** `rg -n 'will-cite' home` runs
- **THEN** it prints nothing

#### Scenario: Parallel equals serial

- **WHEN** the suite runs with `--jobs 1` and with the default number of jobs
- **THEN** the numbers of tests, failures and skips are the same

#### Scenario: No GNU parallel

- **WHEN** `tests/run.sh` runs with a `PATH` that holds no `parallel`
- **THEN** it exits 0 after a serial run and prints `jobs: 1`

#### Scenario: A live run is serial

- **WHEN** `DOTFILES_TEST_LIVE=1 tests/run.sh` runs on a machine with GNU parallel
- **THEN** its output holds `jobs: 1`, and a run without the variable holds `jobs:` followed by a number greater than 1 on a machine with at least two cores

### Requirement: Timing tests find GNU time at run time

The timing tests SHALL call GNU time by its path, resolved at run time (`$HOMEBREW_PREFIX/opt/gnu-time/bin/time`, then a `time` of the distribution whose `--version` names GNU), never by a path written in a file, and SHALL use `date +%s.%N` when none is found.

#### Scenario: No machine path

- **WHEN** `rg -n -e 'linuxbrew' -e '/home/[a-z]+/' tests` runs
- **THEN** it prints nothing

#### Scenario: Fallback

- **WHEN** a live timing test runs with no GNU time reachable
- **THEN** it still prints medians of at least 7 alternating runs, using `date`

### Requirement: Fixtures are synthetic and reviewed

The suite SHALL build names, canaries, package lists and configuration at run time, SHALL hold no copy of a real listing, and SHALL hold no home path, user name, host name, address or name of a private repository.
Before a commit that adds a test or a fixture, the redaction tool (public profile) and the secret scanner SHALL report nothing on `tests/`.

#### Scenario: Redaction tool

- **WHEN** `python3 ~/.config/nvim/scripts/session_redact.py --profile public --check` runs on the files of `tests/` (it reads files, not directories)
- **THEN** the counts of secrets, private terms, user identity, home paths, repository names, credential variable names, IP addresses, email addresses and git hosts are all 0

#### Scenario: Secret scanner

- **WHEN** `gitleaks dir tests` runs
- **THEN** it exits 0

#### Scenario: No literal secret-looking name

- **WHEN** `rg -n 'DEMO_[A-Z_]*(KEY|TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL)' tests` runs
- **THEN** it prints nothing

#### Scenario: Small fixtures only

- **WHEN** `find tests/fixtures -type f -size +4k` runs
- **THEN** it prints nothing

### Requirement: Helpers can be reused by another runner

The shared setup SHALL be plain shell scripts `tests/helpers/*.sh` that call no bats function, read no bats variable and use no `load`; the bats glue (library loading, skips, suite setup) SHALL be in `tests/helpers/bats/*.bash`.

#### Scenario: No bats in the plain helpers

- **WHEN** `rg -n -e '^@test' -e '\bbats_' -e '\bload\b' -e 'BATS_' tests/helpers/*.sh tests/run.sh tests/deps.sh` runs
- **THEN** it prints nothing

#### Scenario: Each helper parses and passes shellcheck

- **WHEN** `bash -n` and `shellcheck -s bash` run on every file of `tests/helpers/*.sh`, `tests/run.sh` and `tests/deps.sh`
- **THEN** every command prints nothing and exits 0

### Requirement: The three ported suites keep their strictness

The suite SHALL hold the checks of the three scratch harnesses that it replaces, in zsh and in each bash build where the code under test runs in both, and `tests/README.md` SHALL map each scenario of `agent-environment`, `shell-startup` and `install-scripts` to the test file that proves it or to the reason it is manual (the live probe of a herdr-started agent, the documentation lines of `AGENTS.md`).

#### Scenario: Counts against the old harnesses

- **WHEN** `bats --count` runs on the unit file of the wrapper, the smoke and unit files of the shell startup, and the unit and smoke files of the install scripts
- **THEN** the wrapper file counts 39 tests named per shell (13 for each of zsh, bash and a Homebrew bash), the startup files at least 101, and the install-scripts files at least 155

#### Scenario: Every scenario is mapped

- **WHEN** `rg -c '^#### Scenario' openspec/specs/agent-environment/spec.md openspec/specs/shell-startup/spec.md openspec/specs/install-scripts/spec.md` runs and the rows of the scenario table of `tests/README.md` are counted
- **THEN** the number of rows equals the sum of the three counts

#### Scenario: Shell named in the test

- **WHEN** `bats --count --filter '^(zsh|bash|brewbash) ' tests/unit/agent-env.bats` runs
- **THEN** it prints 39

### Requirement: A suite can fail

`mise run test:mutants` SHALL run each suite against a mutated copy of the code under test, chosen through `DOTFILES_TEST_SOURCE`, and SHALL fail unless the expected number of tests fails, so that a suite which cannot fail is not taken for a proof.
The mutated copies SHALL be built in a scratch directory from the source files and from the files of `tests/mutants/`, and SHALL never change the repository.
`mise run test` SHALL NOT run them.

#### Scenario: Broken wrapper

- **WHEN** the wrapper tests run against a copy whose `opencode` function is `opencode() { command env opencode "$@"; }`
- **THEN** exactly 9 tests fail, 3 in each shell

#### Scenario: Mutants of the other suites

- **WHEN** `mise run test:mutants` runs
- **THEN** each mutant of the shell startup and of the install scripts listed in `tests/mutants/README.md` makes at least its expected number of tests fail, and the command exits 0

#### Scenario: The repository is untouched

- **WHEN** `git status --porcelain` runs after `mise run test:mutants`
- **THEN** it prints nothing that was not there before

#### Scenario: Not in the default run

- **WHEN** `rg -c 'test:mutants' tests/run.sh` runs
- **THEN** it prints nothing

### Requirement: A change can be compared with another ref

With `DOTFILES_TEST_BASE_REF=<ref>`, the startup smoke tests SHALL render that ref into a second scratch destination without touching the working tree, and SHALL compare the names and values of the exported variables of a replay of the display manager's call (values of names that match the secret pattern excluded), the exported variable names of login shells, and the alias and function names of interactive shells; they SHALL fail when a difference is not listed in the file named by `DOTFILES_TEST_BASE_ALLOW` (one name per line), and SHALL skip without the variable, with a message that names it.

#### Scenario: Skipped without a ref

- **WHEN** `mise run test` runs without `DOTFILES_TEST_BASE_REF`
- **THEN** the comparison tests are skipped with a message that names the variable

#### Scenario: A tree equals itself

- **WHEN** `DOTFILES_TEST_BASE_REF=HEAD mise run test` runs on a clean tree
- **THEN** the comparison tests pass

#### Scenario: A difference is named

- **WHEN** `DOTFILES_TEST_SOURCE` points at a scratch copy of the repository with one extra alias, and `DOTFILES_TEST_BASE_REF=HEAD` is set
- **THEN** the alias comparison fails, its output names the alias and says `1`, and the other comparisons pass

### Requirement: The documentation names the suite

`tests/README.md` SHALL describe the levels, the isolated mode and the live read-only mode of the install-script harness, `DOTFILES_TEST_LIVE`, `DOTFILES_TEST_BASE_REF`, `DOTFILES_TEST_BASE_ALLOW` and `DOTFILES_TEST_SOURCE`, and the commands `mise run test`, `test:live`, `test:deps` and `test:mutants`.
`AGENTS.md` SHALL point to it and give the command that runs the suite, and SHALL NOT say that a harness is kept outside the repository.
The preamble of the `agent-environment` specification SHALL NOT name the old scratch path.

#### Scenario: README

- **WHEN** `rg -c -e 'DOTFILES_TEST_LIVE' -e 'DOTFILES_TEST_BASE_REF' -e 'DOTFILES_TEST_BASE_ALLOW' -e 'DOTFILES_TEST_SOURCE' -e 'mise run test' tests/README.md` runs
- **THEN** it prints at least 5

#### Scenario: AGENTS.md

- **WHEN** `rg -n 'kept outside the repository' AGENTS.md` and `rg -n 'mise run test' AGENTS.md` run
- **THEN** the first prints nothing and the second prints the line that gives the command

#### Scenario: The old scratch path is gone from the specs

- **WHEN** `rg -n '/tmp/opencode' openspec/specs/agent-environment/spec.md openspec/specs/shell-startup/spec.md openspec/specs/install-scripts/spec.md` runs after the archive
- **THEN** it prints nothing

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
