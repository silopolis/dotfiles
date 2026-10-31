## ADDED Requirements

### Requirement: Declarative AI tool settings are managed

The settings, agents and commands that define how the AI tools behave SHALL be declared in the source state.

#### Scenario: opencode config managed

- **WHEN** `chezmoi managed | grep -c '^\.config/opencode/opencode\.json$'` runs
- **THEN** it prints 1

### Requirement: No credentials or state in the repository

Credentials, sessions, databases, logs and caches of AI tools SHALL never be added to the source state.

#### Scenario: Secret scan on AI config sources

- **WHEN** the secret scanner runs on the AI tool sources
- **THEN** it reports nothing

#### Scenario: State folders ignored

- **WHEN** `chezmoi managed` is searched for session, log, cache or database paths of the AI tools
- **THEN** nothing is found

### Requirement: Agent shells show commit hook output

The output filter used by agent shells SHALL NOT rewrite `git commit`, so that a passing commit prints what its hooks reported.

#### Scenario: Commit is not rewritten

- **WHEN** `rtk rewrite "git commit -m test"` runs
- **THEN** it prints nothing and exits 1

#### Scenario: A passing commit shows hook output

- **WHEN** an agent shell commits a change through a repository whose pre-commit hook prints step results
- **THEN** the commit's output contains those step results, not only the short hash

#### Scenario: Machine state stays out of the source

- **WHEN** the rtk target in the source state is searched for telemetry consent keys
- **THEN** nothing is found

### Requirement: Provider keys are referenced, not stored

Managed AI configs SHALL reference provider keys through environment variables or a loader, never as literal values.

#### Scenario: No literal keys

- **WHEN** the rendered AI config targets are searched for key-shaped strings
- **THEN** nothing is found

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
