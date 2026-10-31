## ADDED Requirements

### Requirement: Decrypted secrets are private

Every target produced from an `encrypted_` source file SHALL be deployed with mode 0600 (directories holding only secrets 0700).

#### Scenario: Encrypted targets have mode 0600

- **WHEN** `chezmoi managed --include=encrypted --path-style=absolute | xargs stat -c '%a'` runs
- **THEN** every line is `600`

#### Scenario: Every encrypted source name is private

- **WHEN** `git ls-files | grep 'encrypted_' | grep -v 'private_'` runs
- **THEN** it prints nothing, except the bootstrap identity `key.txt.age`, which is not a target

### Requirement: Clean public history

The git history SHALL be scanned for secrets, and any finding SHALL be triaged with the user (false positive allowlisted, or secret rotated) before the change is archived.

#### Scenario: History scan

- **WHEN** `gitleaks git --redact --no-banner` runs at the repository root
- **THEN** it exits 0, or every finding is recorded as a reviewed allowlist entry in `.gitleaks.toml` or as a rotated secret

### Requirement: Commit-time secret scanning

A pre-commit hook SHALL refuse commits that add secrets or private keys.

#### Scenario: A secret is refused

- **WHEN** a staged file in a scratch clone contains a token-shaped test string and `hk run pre-commit` runs
- **THEN** the hook fails and names the file

#### Scenario: A private key is refused

- **WHEN** a staged file in a scratch clone contains a private-key header and `hk run pre-commit` runs
- **THEN** the hook fails and names the file

#### Scenario: A partial commit keeps unstaged work

- **WHEN** a scratch clone has an unstaged edit in one file and `git commit --only -m test -- <other file>` commits another file
- **THEN** the commit succeeds and the unstaged edit is still in the working tree

#### Scenario: A normal commit passes

- **WHEN** `hk check --all` runs on the clean tree
- **THEN** it exits 0

#### Scenario: Tools are pinned

- **WHEN** `mise ls --current` runs at the repository root
- **THEN** it lists `hk` and `gitleaks` at the versions pinned in `mise.toml`

### Requirement: One chezmoi binary

Exactly one chezmoi executable SHALL be on `PATH`, at the latest release when the change is applied.

#### Scenario: Single binary

- **WHEN** `which -a chezmoi | sort -u | wc -l` runs in an interactive shell
- **THEN** it prints 1

#### Scenario: Doctor reports the version as current

- **WHEN** `chezmoi doctor` runs
- **THEN** the `latest-version` check is `ok`

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
