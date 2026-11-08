## ADDED Requirements

### Requirement: Neovim location is configuration

The host, owner and repository of the Neovim configuration SHALL come from chezmoi data kept in the local config, never from a tracked file.

#### Scenario: Data keys

- **WHEN** `chezmoi data --format=json | jq -c '.nvim | keys'` runs after `chezmoi init`
- **THEN** it prints `["host","owner","repo"]`

### Requirement: Neovim configuration from its own repository

The Neovim configuration SHALL be cloned from its repository by a chezmoi external that never overwrites local work.

#### Scenario: Missing directory is cloned

- **WHEN** `~/.config/nvim` does not exist, the data is set, a GitHub CLI login file exists, and `chezmoi apply --include=externals --exclude=scripts ~/.config/nvim` runs
- **THEN** the repository is cloned there and the URL of its `origin` remote equals the one built from the configured host, owner and repository

#### Scenario: Existing clone keeps its work

- **WHEN** `~/.config/nvim` exists with local commits or uncommitted changes and `chezmoi apply --include=externals --exclude=scripts -R --force ~/.config/nvim` runs
- **THEN** `git -C ~/.config/nvim status -sb` lists the same changes, and `HEAD` is unchanged or advanced only by a fast-forward

#### Scenario: No data, no external

- **WHEN** `nvim.owner` or `nvim.repo` is empty and `chezmoi managed | grep -c '^\.config/nvim$'` runs
- **THEN** it prints 0

#### Scenario: No clone and no GitHub login

- **WHEN** the data is set, `~/.config/nvim` does not exist, `~/.config/gh/hosts.yml` does not exist, and `chezmoi managed | grep -c '^\.config/nvim$'` runs
- **THEN** it prints 0 and one warning says the Neovim external was skipped

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
