## ADDED Requirements

In the scenarios below, `<project>` is the harness project: the value of `MACHINE_PROJECT` when set, otherwise `dotfiles-test`, or, for a user confined by the restricted `incus` group, the one project that user can see.
Scenarios that run an engine need a host where `incus info` succeeds (see the change `add-incus-host-setup`).

### Requirement: Targets are described in one list

The repository SHALL hold `tests/machine/targets.toml` with a `[defaults]` table that sets `chezmoi_version`, and one table per target that sets `name`, `kind`, `image`, `ci`, `cpus`, `memory` and `disk`, and optionally `config` (a table of Incus instance options passed at launch) and `cloud_init` (the list of cloud-init snippets to merge, default `["base"]`).
`kind` SHALL be `container`, `vm` or `host`, and `image` SHALL start with `images:`, `oci:` or be a local alias.
Only `kind = "container"` with an `images:` image is implemented: every command except `machine:list` SHALL exit 2 with a message that says "not implemented yet" when the target needs any other kind or image form.
Every command SHALL accept `--targets <file>` to read another list, so that scenarios can use scratch lists.
`machine:list --json` SHALL print one JSON object per target with at least `name`, `kind`, `image`, `ci` and `config`.

#### Scenario: First target exists

- **WHEN** `mise run machine:list --json | jq -r '.[] | "\(.name) \(.kind)"'` runs at the repository root
- **THEN** its output holds `kali-container container`

#### Scenario: Instance options default to empty

- **WHEN** `mise run machine:list --json | jq -c '.[] | select(.name == "kali-container") | .config'` runs
- **THEN** it prints `{}`

#### Scenario: Unknown kind is refused

- **WHEN** `mise run machine:list --targets <scratch list with kind = "pod">` runs
- **THEN** it exits 2 and its error names the target and the field `kind`

#### Scenario: Reserved kinds are listed but not run

- **WHEN** `mise run machine:list --targets <scratch list with kind = "vm">` runs, then `mise run machine:up <that target> --targets <same list>` runs
- **THEN** the first exits 0 and lists the target, and the second exits 2 with an error that says "not implemented yet" and names the kind

#### Scenario: Reserved image forms are listed but not run

- **WHEN** `mise run machine:up <target whose image is "oci:docker:library/debian:12"> --targets <scratch list>` runs
- **THEN** it exits 2 with an error that says "not implemented yet" and names the image form, and `incus list --project <project> --format csv -c n` is the same before and after

### Requirement: One interface for the guest lifecycle

The root `mise.toml` SHALL define the tasks `machine:list`, `machine:up`, `machine:run`, `machine:snapshot`, `machine:restore` and `machine:down`.
`machine:up <target>` SHALL create a running guest for the target, or reuse a running guest of that target, wait until the agent answers and cloud-init has finished, and print the guest name on standard output.
Messages and logs SHALL go to standard error.

#### Scenario: Tasks are listed

- **WHEN** `mise tasks ls` runs at the repository root
- **THEN** it lists the six `machine:` tasks

#### Scenario: Up creates a ready guest

- **WHEN** `mise run machine:up kali-container` runs
- **THEN** it exits 0, prints one name that starts with `kali-container-`, and `incus exec <name> --project <project> -- cloud-init status` prints `status: done`

#### Scenario: Up twice reuses the guest

- **WHEN** `mise run machine:up kali-container` runs a second time
- **THEN** it exits 0, prints the same name, and `incus list --project <project> --format csv -c n | grep -c '^kali-container-'` prints 1

#### Scenario: Down on nothing is a no-op

- **WHEN** `mise run machine:down kali-container` runs twice in a row
- **THEN** both runs exit 0 and the second one reports that no guest exists

#### Scenario: Snapshot and restore

- **WHEN** `machine:snapshot kali-container clean` runs, then a file is created in the guest, then `machine:restore kali-container clean` runs
- **THEN** both commands exit 0 and the file no longer exists in the guest

### Requirement: Missing or unreachable engine is reported, not hidden

The engine command SHALL be `incus`, or the command named by the environment variable `MACHINE_ENGINE` when it is set.
When that command cannot be found, every command except `machine:list` SHALL exit 127 and name it.
When it is found but `<engine> info` fails, those commands SHALL exit 1 and their error SHALL name `mise run sys:virt:incus:setup`.

#### Scenario: No engine

- **WHEN** `MACHINE_ENGINE=incus-absent mise run machine:up kali-container` runs
- **THEN** it exits 127 and its error names `incus-absent`

#### Scenario: Engine present but not reachable

- **WHEN** `MACHINE_ENGINE=<stub whose info exits 1 with "permission denied"> mise run machine:up kali-container` runs
- **THEN** it exits 1 and its error names `mise run sys:virt:incus:setup`

### Requirement: Guests are isolated from other instances

Every guest SHALL live in the harness project, carry the instance key `user.dotfiles-machine` set to its target name, and have a name made of the target name, a dash and a short identifier.
When the user may create projects, the harness project SHALL be `dotfiles-test`, created on first use; a user confined to a project of their own SHALL get guests in that project.
`machine:down <target>` SHALL print the names it is going to delete and SHALL delete only guests of the harness project that carry the key.

#### Scenario: Project is created on first use

- **WHEN** `mise run machine:up kali-container` runs for a user in the `incus-admin` group on a host where `dotfiles-test` does not exist
- **THEN** `incus project list --format csv | cut -d, -f1` lists `dotfiles-test`

#### Scenario: Guests are marked

- **WHEN** `incus config get <name> user.dotfiles-machine --project <project>` runs against a guest made by `machine:up kali-container`
- **THEN** it prints `kali-container`

#### Scenario: Other instances survive

- **WHEN** an instance named `kali-container-sentinel` exists in the `default` project, another named `kali-container-keep` without the key exists in the harness project, and `mise run machine:down kali-container` runs for a user in the `incus-admin` group
- **THEN** `incus list --project default --format csv -c n` still lists the first, `incus list --project <project> --format csv -c n` still lists the second, and `incus list --project <project> --format json | jq '[.[] | select(.config["user.dotfiles-machine"] == "kali-container")] | length'` prints 0

#### Scenario: Deletions are announced

- **WHEN** `mise run machine:down kali-container` runs while a guest of that target exists
- **THEN** its standard error lists the guest name before the guest disappears from `incus list --project <project>`

#### Scenario: Restricted access works

- **WHEN** `mise run machine:up kali-container` runs for a user who is in the `incus` group and not in `incus-admin`
- **THEN** it exits 0 and `incus list --format csv -c n` lists the printed name

### Requirement: Guests run as a user unlike the host's

Guests SHALL be provisioned by cloud-init from `tests/machine/cloud-init/base.yaml` with a non-root user `tester` that has passwordless sudo, and with `git`, `curl`, `ca-certificates` and `sudo` installed.
The user name SHALL differ from the name of the user who runs the harness.

#### Scenario: Tester can sudo

- **WHEN** `incus exec <name> --project <project> -- su - tester -c 'sudo -n true'` runs against a guest made by `machine:up`
- **THEN** it exits 0

#### Scenario: Tools are present

- **WHEN** `incus exec <name> --project <project> -- su - tester -c 'command -v git curl'` runs
- **THEN** it exits 0 and prints two paths

#### Scenario: Tester is not the host user

- **WHEN** `test "$(id -un)" != tester` runs on the host
- **THEN** it exits 0

### Requirement: The guest receives the repository as committed

`machine:run <target> <stage> [--commit <ref>]` SHALL deliver the repository to the guest as a `git bundle` of the requested commit (default `HEAD`), cloned to `/home/tester/.local/share/chezmoi`, before the stage starts.
Uncommitted and untracked files SHALL NOT reach the guest.

#### Scenario: Default is HEAD

- **WHEN** `mise run machine:run kali-container smoke` runs
- **THEN** it exits 0 and `incus exec <name> --project <project> -- git -C /home/tester/.local/share/chezmoi rev-parse HEAD` prints the output of `git rev-parse HEAD` on the host

#### Scenario: Older commit

- **WHEN** `mise run machine:run kali-container smoke --commit HEAD~1` runs
- **THEN** the guest clone's `rev-parse HEAD` prints the output of `git rev-parse HEAD~1` on the host

#### Scenario: Working tree stays out

- **WHEN** an untracked file `scratch-untracked.txt` and a modification to a tracked file exist on the host and `mise run machine:run kali-container smoke` runs
- **THEN** `incus exec <name> --project <project> -- git -C /home/tester/.local/share/chezmoi status --porcelain` prints nothing and `test ! -e /home/tester/.local/share/chezmoi/scratch-untracked.txt` exits 0 in the guest

### Requirement: No real secret enters a guest

The harness SHALL NOT copy anything from `~/.config/chezmoi`, `~/.ssh` or any other key store into a guest.

#### Scenario: Guest holds no host key material

- **WHEN** `mise run machine:run kali-container smoke` has run and `incus exec <name> --project <project> -- sh -c 'test -e /home/tester/.config/chezmoi/key.age -o -d /home/tester/.ssh'` runs
- **THEN** it exits 1

#### Scenario: Host-side code never touches key stores

- **WHEN** `rg -n -e '\.ssh' -e 'key\.age' -e '\.config/chezmoi' tests/machine/machine.py tests/machine/engine_incus.py` runs
- **THEN** it prints nothing

### Requirement: A stage is a script run in the guest

A stage SHALL be an executable file `tests/machine/stages/<name>.sh` that `machine:run` copies to `/home/tester/stages/<name>.sh` in the guest and runs there as `tester` through a login shell, with `EXPECTED_COMMIT` and `CHEZMOI_VERSION` set.
`machine:run` SHALL exit 0 when the stage exits 0 and a non-zero code otherwise, and SHALL write the stage output to `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-machine-tests/` in a file whose name holds the target and stage names.
A stage name with no file SHALL make `machine:run` exit 2 and list the stages that exist.

#### Scenario: Environment reaches the stage

- **WHEN** a stage `env` that prints `$EXPECTED_COMMIT` and `$CHEZMOI_VERSION` is added to `tests/machine/stages/` in a scratch clone and `mise run machine:run kali-container env` runs there
- **THEN** its output holds the host's `git rev-parse HEAD` and the `chezmoi_version` from `targets.toml`

#### Scenario: Failure propagates

- **WHEN** a stage `fail` that runs `exit 3` is added to `tests/machine/stages/` in a scratch clone and `mise run machine:run kali-container fail` runs there
- **THEN** it exits non-zero and the log file records exit status 3

#### Scenario: Unknown stage

- **WHEN** `mise run machine:run kali-container no-such-stage` runs
- **THEN** it exits 2 and its error lists `smoke`

#### Scenario: Log is kept

- **WHEN** `mise run machine:run kali-container smoke` finishes
- **THEN** `ls "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-machine-tests/" | grep -c 'kali-container.*smoke'` prints at least 1

### Requirement: The smoke stage proves the plumbing and applies nothing

The stage `smoke` SHALL pass only when the guest's init system reports `running` or `degraded`, the guest clone is at `EXPECTED_COMMIT`, chezmoi at `CHEZMOI_VERSION` is installed from the official installer, and `chezmoi source-path` ends with `/home`.
It SHALL NOT run `chezmoi apply` or `chezmoi init --apply`.

#### Scenario: Smoke passes on a container

- **WHEN** `mise run machine:run kali-container smoke` runs
- **THEN** it exits 0 and, in the guest, `su - tester -c 'chezmoi --version'` prints the version set in `targets.toml`

#### Scenario: Source path ends in home

- **WHEN** `su - tester -c 'chezmoi --source ~/.local/share/chezmoi source-path'` runs in the guest
- **THEN** its output ends with `/home`

#### Scenario: Nothing was applied

- **WHEN** `test ! -e /home/tester/.config/shell` runs in the guest after smoke
- **THEN** it exits 0

#### Scenario: Wrong commit fails

- **WHEN** `incus exec <name> --project <project> -- su - tester -c 'EXPECTED_COMMIT=0000000000000000000000000000000000000000 CHEZMOI_VERSION=<version> /home/tester/stages/smoke.sh'` runs after a passing `machine:run kali-container smoke`
- **THEN** it exits non-zero and its output names the expected and the actual commit

### Requirement: The harness is tested tooling that follows the fleet stack

The harness SHALL be a Python project in `tests/machine/` with a committed `pyproject.toml` and `uv.lock`, tested with `pytest` against a fake engine so the tests need no engine, with engine calls kept in `tests/machine/engine_incus.py`.
The harness files SHALL hold no home path, user name, host name or credential, since they ship in a public repository.

#### Scenario: Lock file is current

- **WHEN** `uv lock --check --project tests/machine` runs
- **THEN** it exits 0

#### Scenario: Tests pass without an engine

- **WHEN** `MACHINE_ENGINE=incus-absent uv run --project tests/machine pytest` runs
- **THEN** it exits 0

#### Scenario: Engine calls stay in one module

- **WHEN** `rg -n "['\"]incus['\"]" tests/machine --glob '*.py' --glob '!engine_incus.py' --glob '!test_*.py'` runs
- **THEN** it prints nothing

#### Scenario: Lint is clean

- **WHEN** `ruff check tests/machine` and `shellcheck -x tests/machine/stages/*.sh` run
- **THEN** both exit 0

#### Scenario: Nothing machine-specific

- **WHEN** `rg -n -e "$HOME" -e "$USER" tests/machine` runs
- **THEN** it prints nothing

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
