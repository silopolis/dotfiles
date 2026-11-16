# spec-workflow Specification

## Purpose

How work on this public dotfiles repository is planned, recorded and checked: a dated audit baseline with numbered findings, one OpenSpec change per unit of work, an agent guide with safety rules, and writing that is safe to publish.
## Requirements
### Requirement: Dated audit baseline

The repository SHALL keep dated audits under `docs/audits/`, each finding carrying a stable identifier that changes cite.

#### Scenario: A change cites its findings

- **WHEN** a session opens any change under `openspec/changes/`
- **THEN** its proposal names the audit findings (`Fnn`) it addresses, each identifier existing in `docs/audits/2026-10-30-environment.md`, or states that it is a process change with no finding

### Requirement: One OpenSpec change per unit of work

Work on this repository SHALL be planned, applied and archived as OpenSpec changes, one change per working session.

#### Scenario: Changes validate

- **WHEN** `openspec validate --all --strict` runs at the repository root
- **THEN** it exits 0

#### Scenario: A fresh session can start from the repository alone

- **WHEN** a session starts with no prior context
- **THEN** `AGENTS.md`, `openspec list` and the cited audit findings are enough to run `/opsx-apply <change>` or `/opsx-continue <change>`

### Requirement: Agent guide with safety rules

The repository SHALL have a root `AGENTS.md` stating where things live, how to check changes, and which operations need the user's explicit approval (full apply, sudo, writes outside `$HOME`, uninstalls, deletions, commits, pushes).

#### Scenario: Unsafe operations are listed

- **WHEN** `grep -c -E 'dry-run|sudo|commit' AGENTS.md` runs
- **THEN** it prints a count of at least 3

### Requirement: Public writing

Every committed file SHALL be safe to publish: no secret values, no token scopes, no private hosts or IP addresses, no employer or client details.
A committed file MAY name a secret variable only when the name is publicly well known, meaning a name that a provider documents as its convention and that public repositories already carry; a name specific to the workstation or chosen by the user SHALL stay out.
When in doubt, the file SHALL describe the variable and leave the name out.

#### Scenario: Documentation pattern check

- **WHEN** the documentation and spec files are searched for private IP ranges, email addresses other than the public author address, and token-like strings
- **THEN** nothing is found

#### Scenario: Variable names are public conventions

- **WHEN** `rg -o -w '[A-Z][A-Z0-9_]*(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY|ACCESS_?KEY)' --glob '!memory/**' --glob '!openspec/changes/archive/**' --glob '!docs/audits/**' .` runs
- **THEN** every name it prints is one that a provider documents as its convention, or a synthetic `DEMO_` name used by a test, and none is specific to the workstation

### Requirement: Repository files are not targets

Repository-level files (agent guide, docs, specs, tooling) SHALL never be deployed to the home directory.

#### Scenario: Managed list excludes repository files

- **WHEN** `chezmoi managed | grep -E '^(AGENTS\.md|docs|openspec)'` runs
- **THEN** it prints nothing

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->

