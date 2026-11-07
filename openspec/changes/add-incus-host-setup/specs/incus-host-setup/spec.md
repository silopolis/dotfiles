## ADDED Requirements

In the scenarios below, `<task>` is `home/dot_config/mise/tasks/sys/virt/incus/executable_setup`, run with `bash`.
Unless a scenario says otherwise, it runs with a stub directory first on `PATH` holding stubs for `sudo`, `apt-get`, `dpkg-query`, `usermod`, `getent`, `id`, `stat`, `systemctl`, `curl`, `gpg` and `incus`, and with `OS_RELEASE_FILE` pointing to a scratch file.
Each stub appends its command line to one log file, `sudo` also saves its standard input, and each stub answers from a scratch state file, so that no real system is touched and no real network is used.
"The bare host" is state that describes no `incus` package, no `incus` command, no LXD, no storage pool, no managed network and a user in neither Incus group, on a Kali system.
The scenarios of the requirements "Guests reach the network while Docker runs", "The default group is enough to run guests" and the btrfs pool scenario run live on a host where the real task has run; they are the acceptance of the defaults and use catalog images only.

### Requirement: Setup reports what exists before it acts

Every mode of `<task>` SHALL first print a report of: every `incus` on `PATH` with its path, version and source (apt package, brew, mise or other), flagging any client that is not `/usr/bin/incus` as shadowing; the apt package with its version and origin (distribution archive, Zabbly repository or none); the daemon's unit state and server version; whether LXD is present; the storage pools with their drivers; the managed networks; the invoking user's membership in the `incus` and `incus-admin` groups, in the group database and in the current session; and whether Docker is present.
With `--json` the report SHALL be one JSON object with the keys `clients`, `package`, `daemon`, `lxd`, `storage_pools`, `networks`, `groups` and `docker`.

#### Scenario: Report on the bare host

- **WHEN** `<task> --check --json` runs against the bare host
- **THEN** it exits 1 and `jq -r '[.clients, .package, .daemon, .lxd, .storage_pools, .networks, .groups, .docker] | length'` on its output prints 8

#### Scenario: Shadowing client from brew

- **WHEN** `<task> --check --json` runs with a stub `incus` first on `PATH` in a directory named `linuxbrew/bin`
- **THEN** `jq -r '.clients[0] | "\(.source) \(.shadowing)"'` on its output prints `brew true`

#### Scenario: LXD is reported

- **WHEN** `<task> --check --json` runs against stubs that describe `/var/lib/lxd` as present
- **THEN** `jq -r '.lxd'` on its output prints `true`

#### Scenario: Package origin is reported

- **WHEN** `<task> --check --json` runs against stubs that describe an installed `incus` package whose apt origin is `Zabbly`
- **THEN** `jq -r '.package.origin'` on its output prints `zabbly`

### Requirement: Check and dry run change nothing and never call sudo

`<task> --check` SHALL change nothing, never call `sudo`, and exit 0 when the host is ready and 1 when it is not.
`<task> --dry-run` SHALL print each step it would take, never call `sudo`, and exit 0.

#### Scenario: Check on a ready host

- **WHEN** `<task> --check` runs against stubs that describe an installed Incus at the minimum version, a storage pool, a managed network and a user in the `incus` group
- **THEN** it exits 0 and the stub log holds no `sudo` line

#### Scenario: Check on the bare host

- **WHEN** `<task> --check` runs against the bare host
- **THEN** it exits 1, its output names the package, the initialisation and the group as missing, and the stub log holds no `sudo` line

#### Scenario: Dry run takes no step

- **WHEN** `<task> --dry-run` runs against the bare host
- **THEN** it exits 0, prints the steps package, initialisation and group in that order, and the stub log holds no `sudo` line

### Requirement: Setup installs and initialises a bare host

On a host with no Incus, `<task>` SHALL take these steps in this order, each only when needed: install the `incus` package with apt, run `incus admin init --preseed`, and add the invoking user to the `incus` group, or to `incus-admin` with `--group incus-admin`.
It SHALL tell the user that a new login session or `newgrp` is needed for the group.
Outside the Debian family, read from the file named by `OS_RELEASE_FILE` or else `/etc/os-release`, it SHALL change nothing and exit 2.

#### Scenario: Real run on the bare host

- **WHEN** `<task>` runs against the bare host
- **THEN** it exits 0 and the stub log holds, in this order, an `apt-get install` line naming `incus`, an `incus admin init --preseed` line, and a `usermod -aG incus` line, each preceded by `sudo`

#### Scenario: Admin group on request

- **WHEN** `<task> --group incus-admin` runs against the bare host
- **THEN** the stub log holds a `usermod -aG incus-admin` line and none for `incus`

#### Scenario: Second run changes nothing

- **WHEN** `<task>` runs again against stubs that now describe the finished state
- **THEN** it exits 0 and the stub log holds no `sudo` line

#### Scenario: Another system

- **WHEN** `OS_RELEASE_FILE=<file with ID=fedora and no ID_LIKE> <task>` runs
- **THEN** it exits 2 and the stub log is empty

### Requirement: The storage driver follows the filesystem

The preseed passed to `incus admin init --preseed` SHALL create a storage pool named `default` that uses the `btrfs` driver when `/var/lib/incus` is on btrfs and the `dir` driver otherwise, and the task SHALL NOT use `incus admin init --minimal`.

#### Scenario: Btrfs host

- **WHEN** `<task>` runs against the bare host with a `stat` stub that reports `btrfs` for `/var/lib/incus`
- **THEN** the preseed saved from the `incus` stub's standard input holds `driver: btrfs`

#### Scenario: Other filesystem

- **WHEN** the same run uses a `stat` stub that reports `ext2/ext3`
- **THEN** the saved preseed holds `driver: dir`

#### Scenario: Laptop pool is btrfs

- **WHEN** `incus storage list --format csv -c nd` runs on the btrfs laptop after the real run of the task
- **THEN** its output holds `default,btrfs`

#### Scenario: Minimal init is never used

- **WHEN** `rg -n -e '--minimal' <task>` runs
- **THEN** it prints nothing

### Requirement: An existing Incus is reported and never changed

When any Incus is already present, whatever its source, `<task>` SHALL NOT install over it, upgrade it, downgrade it, switch it to another source, initialise it again or modify, clean or delete any storage pool, network, profile, project or instance.
Below the minimum version (default `7.0`, option `--min-version`), `<task> --check` SHALL exit 1 and a real run SHALL exit 1, both without any change.
An installed daemon with no storage pool and no managed network SHALL be initialised; any pool or managed network SHALL prevent initialisation.
Group membership SHALL be added only when the run itself installed or initialised Incus, or with `--add-user`.
When `--source` names a source other than the installed package's origin, the run SHALL exit 1 and name that origin.

#### Scenario: Initialised Incus, user outside the group

- **WHEN** `<task>` runs against stubs that describe an installed Incus at the minimum version with a storage pool, a managed network, a profile, a project and an instance, and a user in neither group
- **THEN** it exits 0, its output says the user is not in a group and how to add the user, and the stub log holds no line for `sudo`, `apt-get`, `usermod` or `incus admin init`

#### Scenario: Explicit request to add the user

- **WHEN** `<task> --add-user` runs against the same stubs
- **THEN** the stub log holds one `usermod -aG incus` line preceded by `sudo` and nothing else that writes

#### Scenario: Below the minimum version

- **WHEN** `<task> --check` and `<task>` run against stubs that describe an installed Incus at 6.0
- **THEN** both exit 1, name the version and the minimum, and the stub log holds no `sudo` line

#### Scenario: Installed but never initialised

- **WHEN** `<task>` runs against stubs that describe an installed daemon at the minimum version with no storage pool and no managed network, and a user in neither group
- **THEN** the stub log holds an `incus admin init --preseed` line preceded by `sudo`, no `apt-get` line, and no `usermod` line

#### Scenario: A pool or a network blocks initialisation

- **WHEN** `<task>` runs against stubs that describe an installed Incus with one managed network and no storage pool
- **THEN** the stub log holds no `incus admin init` line

#### Scenario: Nothing destructive is ever called

- **WHEN** every scenario of this requirement has run and the stub log is searched with `rg -n -e 'delete' -e 'remove' -e 'purge' -e 'upgrade' -e 'edit' -e 'unset'`
- **THEN** it prints nothing

#### Scenario: Another source is not switched to

- **WHEN** `<task> --source zabbly-lts-7.0` runs against stubs that describe an installed Incus whose origin is the distribution archive
- **THEN** it exits 1, its output names the distribution archive, and the stub log holds no `sudo` line

### Requirement: The Zabbly source is limited, verified and written once

`--source zabbly-lts-7.0` and `--source zabbly-stable` SHALL be accepted only on Debian 12 and 13 and Ubuntu 22.04, 24.04 and 26.04, read from `OS_RELEASE_FILE`; elsewhere, including Kali and non-LTS Ubuntu, they SHALL exit 2 without any change.
The task SHALL compare the fingerprint of the downloaded repository key with `4EFC 5906 96CB 15B8 7C73  A3AD 82CC 8797 C838 DCFD` before it trusts the key, and SHALL write the key and the channel's `.sources` file only when they differ from what exists.

#### Scenario: Kali is refused

- **WHEN** `<task> --source zabbly-stable` runs against the bare host on a Kali system
- **THEN** it exits 2, its output says Zabbly does not support that system, and the stub log holds no `sudo` line

#### Scenario: Non-LTS Ubuntu is refused

- **WHEN** the same run uses an `OS_RELEASE_FILE` with `ID=ubuntu` and `VERSION_ID="25.10"`
- **THEN** it exits 2 and the stub log holds no `sudo` line

#### Scenario: Wrong fingerprint

- **WHEN** `<task> --source zabbly-lts-7.0` runs on Ubuntu 24.04 with a `gpg` stub that prints another fingerprint
- **THEN** it exits 1, its output names the mismatch, and the stub log holds no `tee` line and no `apt-get` line

#### Scenario: Channel is written, then the package installed

- **WHEN** `<task> --source zabbly-lts-7.0` runs on Ubuntu 24.04 against the bare host with a `gpg` stub that prints the published fingerprint
- **THEN** the stub log holds, in this order, a `tee` line for `/etc/apt/keyrings/zabbly.asc`, a `tee` line for `/etc/apt/sources.list.d/zabbly-incus-lts-7.0.sources`, an `apt-get update` line and an `apt-get install` line naming `incus`, and the saved `.sources` text names the `lts-7.0` repository path

#### Scenario: Second run writes nothing

- **WHEN** the same run repeats against stubs whose files already hold that key and that `.sources` text
- **THEN** the stub log holds no `tee` line

### Requirement: Guests reach the network while Docker runs

On a host where Docker is running, a guest launched after the setup SHALL reach the network through the Incus bridge.

#### Scenario: Container resolves a name

- **WHEN** `systemctl is-active docker` prints `active`, `incus launch images:debian/trixie/cloud net-probe` runs after the setup, and `incus exec net-probe -- getent hosts deb.debian.org` runs once cloud-init has finished
- **THEN** it exits 0, and `incus delete --force net-probe` removes the probe

### Requirement: The default group is enough to run guests

A user added to the `incus` group by the task, and not to `incus-admin`, SHALL be able, in their own project, to launch a system container and a virtual machine, run commands in them, and snapshot and restore them.

#### Scenario: Container

- **WHEN** a user in the `incus` group and not in `incus-admin` runs `incus launch images:debian/trixie/cloud grp-ct`, then `incus exec grp-ct -- true`
- **THEN** both exit 0

#### Scenario: Virtual machine

- **WHEN** the same user runs `incus launch images:debian/trixie/cloud grp-vm --vm`, then `incus exec grp-vm -- true` once the agent answers
- **THEN** both exit 0

#### Scenario: Snapshot and restore

- **WHEN** the same user runs `incus snapshot create grp-ct s1`, creates a file in the container, then runs `incus snapshot restore grp-ct s1`
- **THEN** both commands exit 0 and the file no longer exists in the container, and `incus delete --force grp-ct grp-vm` removes the probes

#### Scenario: Not root-equivalent

- **WHEN** `id -nG` runs for that user
- **THEN** its output holds `incus` and does not hold `incus-admin`

### Requirement: The setup is tested without touching the system

`<task>` SHALL pass `shellcheck -x`, and the scenarios of this capability that use stubs SHALL be run by `tests/global-mise-tasks/test_incus_setup.py` with its stubs in `tests/global-mise-tasks/incus_stubs/`, using the standard library only, leaving no file outside its scratch directory under `/tmp/opencode`.

#### Scenario: Shellcheck is clean

- **WHEN** `shellcheck -x <task>` runs
- **THEN** it exits 0

#### Scenario: Suite passes and leaves nothing

- **WHEN** `python3 -m unittest discover -s tests/global-mise-tasks -p 'test_incus_setup.py'` runs at the repository root
- **THEN** it exits 0 and `ls /tmp/opencode | grep -c incus-setup` prints 0

#### Scenario: Nothing machine-specific

- **WHEN** `rg -n -e "$HOME" -e "$USER" <task> tests/global-mise-tasks/test_incus_setup.py tests/global-mise-tasks/incus_stubs` runs
- **THEN** it prints nothing

