## MODIFIED Requirements

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

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
