## ADDED Requirements

### Requirement: Compiled spell lists are ignored by git

The managed global git ignore file `~/.config/git/ignore` SHALL ignore Neovim's compiled spell lists (`*.add.spl`), and SHALL NOT ignore the word lists they are compiled from (`*.add`).

#### Scenario: Compiled list ignored

- **WHEN** `git check-ignore -v .spell/en.utf-8.add.spl` runs in a scratch repository with no ignore file of its own
- **THEN** it exits 0 and names `~/.config/git/ignore`

#### Scenario: Word list still tracked

- **WHEN** `git check-ignore -q .spell/en.utf-8.add` runs in the same repository
- **THEN** it exits 1

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
