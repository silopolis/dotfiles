## ADDED Requirements

### Requirement: Store location is configuration

The host, owner and repository of the private store SHALL come from chezmoi data kept in the local config, never from a tracked file of this repository.

#### Scenario: Data keys

- **WHEN** `chezmoi data --format=json | jq -c '.private | keys'` runs after `chezmoi init`
- **THEN** it prints `["host","owner","repo"]`

#### Scenario: Location absent from the repository

- **WHEN** `git grep -cF "$(chezmoi data --format=json | jq -r '.private | "\(.owner)/\(.repo)"')"` runs at the repository root, and the same string is searched in the change's commits with `git log -p <first>^..HEAD | grep -cF`
- **THEN** `git grep` prints nothing and exits 1, and `grep -c` prints 0 (the owner alone is public, as the owner of this repository; the pair is not)

### Requirement: Store cloned by a guarded external

The private store SHALL be cloned to `~/.local/share/chezmoi-private` by a `git-repo` external.
The external SHALL never overwrite local work, and SHALL exist only when the data is set and the machine has either the clone or a GitHub CLI login file.

#### Scenario: Missing store is cloned

- **WHEN** a scratch destination has a GitHub CLI login file and no store, the data is set, and `chezmoi apply --destination <scratch> --include=externals --exclude=scripts <scratch>/.local/share/chezmoi-private` runs
- **THEN** the store is cloned there, and `git -C <scratch>/.local/share/chezmoi-private remote get-url origin` matches the configured location (compared by the test, not printed)

#### Scenario: Existing store keeps its work

- **WHEN** the store has local commits or uncommitted changes and the same apply runs
- **THEN** `git -C ~/.local/share/chezmoi-private status -sb` lists the same changes, and `HEAD` is unchanged or advanced only by a fast-forward

#### Scenario: No data, no external

- **WHEN** `private.owner` or `private.repo` is empty and `chezmoi managed | grep -c '^\.local/share/chezmoi-private$'` runs
- **THEN** it prints 0

#### Scenario: No clone and no GitHub login

- **WHEN** the data is set, the destination has neither the store nor `~/.config/gh/hosts.yml`, and `chezmoi managed | grep -c '^\.local/share/chezmoi-private$'` runs
- **THEN** it prints 0 and a warning says the private store external was skipped

### Requirement: A clone is private

A clone of the store SHALL be readable by its owner only: root directory 0700 through the external's `private` attribute, or, when chezmoi does not apply it to `git-repo` targets, the modes given by chezmoi's umask 027, with the outcome recorded in the change's design.

#### Scenario: Fresh clone mode

- **WHEN** the store is cloned into a scratch destination by the external
- **THEN** `stat -c '%a'` on the clone root prints `700`, or `750` with the umask fallback recorded

#### Scenario: Existing store mode unchanged

- **WHEN** the external is applied to this machine's store
- **THEN** `stat -c '%a' ~/.local/share/chezmoi-private` prints `700` before and after

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
