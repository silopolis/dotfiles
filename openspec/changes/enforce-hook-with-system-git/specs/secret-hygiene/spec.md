## MODIFIED Requirements

### Requirement: Commit-time secret scanning

A pre-commit hook SHALL refuse commits that add secrets or private keys, whichever git binary on the machine makes the commit.

#### Scenario: A secret is refused

- **WHEN** a staged file in a scratch clone contains a token-shaped test string and `hk run pre-commit` runs
- **THEN** the hook fails and names the file

#### Scenario: A private key is refused

- **WHEN** a staged file in a scratch clone contains a private-key header and `hk run pre-commit` runs
- **THEN** the hook fails and names the file

#### Scenario: Refused with every git binary

- **WHEN** a staged generated token-shaped string is committed in a scratch clone once with `/usr/bin/git commit` and once with the `git` first on `PATH`
- **THEN** both commits fail, name the file and add no commit

#### Scenario: A partial commit keeps unstaged work

- **WHEN** a scratch clone has an unstaged edit in one file and `git commit --only -m test -- <other file>` commits another file
- **THEN** the commit succeeds and the unstaged edit is still in the working tree

#### Scenario: A normal commit passes

- **WHEN** `hk check --all` runs on the clean tree
- **THEN** it exits 0

#### Scenario: Tools are pinned

- **WHEN** `mise ls --current` runs at the repository root
- **THEN** it lists `hk` and `gitleaks` at the versions pinned in `mise.toml`

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
