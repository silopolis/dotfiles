## ADDED Requirements

### Requirement: Config generated from the template only

chezmoi's configuration SHALL be produced by `chezmoi init` from `.chezmoi.toml.tmpl`, and no managed target SHALL overwrite it.

#### Scenario: Config file is not managed

- **WHEN** `chezmoi managed | grep -c '^\.config/chezmoi/chezmoi\.toml$'` runs
- **THEN** it prints 0

#### Scenario: Doctor has no suspicious entry

- **WHEN** `chezmoi doctor` runs
- **THEN** no `suspicious-entries` warning is reported

#### Scenario: Data matches the machine

- **WHEN** `chezmoi data --format=json | jq -c '{c: .cpu, m: .machine}'` runs on a laptop
- **THEN** the machine type is `laptop` and the cpu counts equal `lscpu`'s cores and threads

### Requirement: Encryption configured by the template

The template SHALL set `encryption = "age"` and the `[age]` identity and recipient, so a freshly initialized machine can decrypt once the identity exists.

#### Scenario: Render without a stored config

- **WHEN** `chezmoi execute-template --init --promptString email=x,gitemail=x,firstname=x,name=x < .chezmoi.toml.tmpl` output is parsed as TOML
- **THEN** it has `encryption = "age"`, an `age.identity` and an `age.recipient`

#### Scenario: Encrypted targets still decrypt

- **WHEN** `chezmoi cat` runs on any encrypted target after `chezmoi init`
- **THEN** it exits 0

### Requirement: Every key takes effect

Top-level keys SHALL precede all tables and included templates, and each table key SHALL use chezmoi's documented name.

#### Scenario: Effective settings

- **WHEN** `chezmoi dump-config --format=json | jq -c '{u: .umask, p: .pager, d: .diff.exclude}'` runs
- **THEN** umask is 23 (octal 027), pager is `bat`, and diff exclude is `["externals"]`

#### Scenario: No data pollution

- **WHEN** `chezmoi data --format=json | jq '.github | keys'` runs
- **THEN** it lists only `is_codespaces`

#### Scenario: Init does not prompt when data exists

- **WHEN** `chezmoi init` runs on a machine whose config already holds the identity data
- **THEN** it asks no question

### Requirement: Restrictive deployment modes

chezmoi SHALL deploy with umask 027: files 0640, executables and directories 0750, private entries 0600 or 0700.

#### Scenario: Expected mode of a plain file

- **WHEN** a plain managed file is applied alone with `chezmoi apply --exclude=scripts <target>`
- **THEN** `stat -c '%a' <target>` prints 640

### Requirement: Brewfile stays in sync after brew changes

After brew changes the Brewfile, the brew hook SHALL leave both the source and the target in sync, mode included.

#### Scenario: No mode-only drift

- **WHEN** a brew install or uninstall through brew-wrap finishes and the hook has run
- **THEN** `chezmoi status ~/.config/brewfile/Brewfile` prints nothing

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
