## ADDED Requirements

### Requirement: Machine description data

The config template SHALL compute data describing the machine, used by templates and by cem: distro id and family, machine type, cpu counts, profile, and the Homebrew prefix.

#### Scenario: Data keys present

- **WHEN** `chezmoi data --format=json | jq -c '{os: .os, machine: .machine, profile: .profile, brew: .brew}'` runs
- **THEN** every key has a value, and `os.like` contains `debian` on this laptop

#### Scenario: Profile asked once

- **WHEN** `chezmoi init` runs on a machine whose config already holds a profile
- **THEN** it does not ask for the profile again

#### Scenario: No dead template material

- **WHEN** `grep -L includeTemplate` is compared with the files in `.chezmoitemplates/`
- **THEN** every file in `.chezmoitemplates/` is used by at least one template or script

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
