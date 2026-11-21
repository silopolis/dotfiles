## MODIFIED Requirements

### Requirement: The three ported suites keep their strictness

The suite SHALL hold the checks of the three scratch harnesses that it replaces, in zsh and in each bash build where the code under test runs in both, and `tests/README.md` SHALL map each scenario of `agent-environment`, `shell-startup`, `install-scripts` and `shell-environment` to the test file that proves it or to the reason it is manual (the live probe of a herdr-started agent, the documentation lines of `AGENTS.md`, the checks that only a new login proves).

#### Scenario: Counts against the old harnesses

- **WHEN** `bats --count` runs on the unit file of the wrapper, the smoke and unit files of the shell startup, and the unit and smoke files of the install scripts
- **THEN** the wrapper file counts 39 tests named per shell (13 for each of zsh, bash and a Homebrew bash), the startup files at least 101, and the install-scripts files at least 155

#### Scenario: Every scenario is mapped

- **WHEN** `rg -c '^#### Scenario' openspec/specs/agent-environment/spec.md openspec/specs/shell-startup/spec.md openspec/specs/install-scripts/spec.md openspec/specs/shell-environment/spec.md` runs and the rows of the scenario table of `tests/README.md` are counted
- **THEN** the number of rows equals the sum of the four counts

#### Scenario: Shell named in the test

- **WHEN** `bats --count --filter '^(zsh|bash|brewbash) ' tests/unit/agent-env.bats` runs
- **THEN** it prints 39

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
