## Why

The Neovim configuration repository is developed in a checkout that Neovim reaches through its own application name, `nvim-dev`: the profile `~/.config/nvim-dev` is a symlink to that checkout, and `NVIM_APPNAME=nvim-dev nvim` starts on it.
A command that does this is useful in panes and scripts that do not read the shell's aliases, so on 2026-11-18 a session of the Neovim repository wrote `~/.local/bin/nvim-dev`, a short POSIX script, at the user's request.
Nothing in this repository manages it: a fresh machine has no such command, and the user's machine holds a file that no source explains.
On 2026-11-24 the user decided to manage the script alone, with no alias line, after part 1 of `correct-shell-environment`, and the Neovim repository's orchestrator expects to be told when it is done.

## What Changes

- The script becomes a managed file, `home/dot_local/bin/executable_nvim-dev`, next to `awsenv`.
  Its code is the six lines that exist; its comment said "Not managed by chezmoi", which stops being true, and is the only line that changes.
- A new requirement of `neovim-config` says what the command does: it runs `nvim` with `NVIM_APPNAME=nvim-dev` and the caller's arguments unchanged, returns the status of `nvim`, and refuses with a message that names the missing path when the profile does not exist.
  It never creates the profile or the clone: the checkout is the Neovim repository's business, and this repository clones nothing for it.
- A bats file proves the scenarios with a stub `nvim` under `env -i`, and one mutant proves that the missing-profile checks can fail.
- No alias line: a later alias would shadow the command in shells that read the aliases file, and the command already works everywhere.
- No design document: one file, no choice left open after the user's decision, no new mechanism.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `neovim-config`: a requirement for the development command is added.

## Impact

- New: `home/dot_local/bin/executable_nvim-dev`, `tests/unit/nvim-dev.bats`, one mutant (`tests/mutants/nvim-dev/no-refusal.sed` and its row), rows in the scenario table of `tests/README.md`.
- Applying the target is a single-target apply with `--exclude=scripts`, after the user's go: the file exists with a mode of 0755, and chezmoi's umask makes it 0750 (the drift that `reconcile-drift-and-supervised-apply` also meets); the first apply changes that mode and the comment line.
- The Neovim repository's orchestrator is told once the target is applied.
- The purpose line of `neovim-config` is extended by hand after the archive, because `openspec archive` rewrites only the requirements.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
