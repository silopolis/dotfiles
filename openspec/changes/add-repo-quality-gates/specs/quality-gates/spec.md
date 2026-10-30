## ADDED Requirements

### Requirement: Whole-tree check passes

The repository SHALL pass its full check suite at every commit on `main`.

#### Scenario: Full check

- **WHEN** `hk check --all` runs at the repository root
- **THEN** it exits 0

### Requirement: Shell sources are checked

Staged shell files and rendered shell templates SHALL pass shellcheck and the repository's shfmt settings.

#### Scenario: Broken shell is refused

- **WHEN** a staged rc file contains a syntax error and `hk run pre-commit` runs
- **THEN** the hook fails and names the file

### Requirement: Templates render

Staged templates that render without prompts SHALL render successfully.

#### Scenario: Broken template is refused

- **WHEN** a staged `.tmpl` file has an unclosed action and `hk run pre-commit` runs
- **THEN** the hook fails

### Requirement: Commit messages follow the convention

Commit messages SHALL match `type(domain[:subject]): summary` with a known domain and a subject of at most 80 characters.

#### Scenario: Bad message refused

- **WHEN** a commit is attempted with the message `update stuff`
- **THEN** the commit-msg hook refuses it

#### Scenario: Brew hook message accepted

- **WHEN** the brew hook commits a Brewfile change
- **THEN** its generated message passes the commit-msg check

### Requirement: Specs stay valid

Changes to `openspec/` SHALL keep `openspec validate --all --strict` passing.

#### Scenario: Invalid spec refused

- **WHEN** a staged spec lacks a scenario under a requirement and `hk run pre-commit` runs
- **THEN** the hook fails

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
