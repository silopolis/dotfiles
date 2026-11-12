## ADDED Requirements

### Requirement: The config keeps local settings of the install scripts

The template SHALL copy `tools.search.extra` and `tools.search.override` from the existing data into a `[data.tools.search]` table, as empty lists when there are none, so that `chezmoi init` keeps hand-written values, and SHALL prompt for neither.

#### Scenario: Existing values are kept

- **WHEN** `chezmoi --override-data '{"email":"x","gitemail":"x","firstname":"x","name":"x","features":{"incus":false},"nvim":{"host":"github.com","owner":"","repo":""},"tools":{"search":{"extra":["/opt/x/bin"],"override":["/only/bin"]}}}' execute-template --init < home/.chezmoi.toml.tmpl` output is parsed as TOML
- **THEN** `data.tools.search` equals those two lists

#### Scenario: Defaults are empty lists

- **WHEN** the same command runs without the `tools` key and with standard input not attached to a terminal
- **THEN** `data.tools.search` holds two empty lists, and no other table of `data` changes (`github` still lists only `is_codespaces`)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
