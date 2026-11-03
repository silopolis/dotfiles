## Why

The Neovim repository keeps the user's private spell words, and the terms its session export script redacts, in one directory outside every repository: `~/.local/share/chezmoi-private`.
That directory is now a clone of a private repository, and nothing deploys it on another machine.
Its location must stay out of this public repository, like the Neovim repository's.
Neovim also writes a compiled spell list (`<lang>.utf-8.add.spl`) next to each project word list, and nothing ignores it globally, so it shows as untracked in projects.
Source: request of the Neovim repository (session S16), 2026-11-03.
It follows the Neovim external of `fix-chezmoi-config-template` (audit `docs/audits/2026-10-30-environment.md`, F05 and section 2.8) and is row 23 of the change map.

## What Changes

- Ask once (`promptStringOnce`) for the store's location: `private.host` (default `github.com`), `private.owner`, `private.repo`.
  The values are kept as a `[data.private]` table in the local chezmoi config only, never in this repository.
- Add a `git-repo` external for `.local/share/chezmoi-private` with the same shape and guard as the Neovim one:
  - `refreshPeriod = "0"` and `pull.args = ["--ff-only"]`, so an apply never pulls over local work;
  - it exists only when owner and repository are set, and when the machine already has the clone or has a GitHub CLI login file; otherwise a warning says it was skipped;
  - `private = true`, so that the clone root is 0700, if chezmoi applies that attribute to a `git-repo` target; otherwise the umask 027 of `fix-chezmoi-config-template` is the rule.
- Add `*.add.spl` to the managed global git ignore file (`~/.config/git/ignore`).
- `fresh-machine-bootstrap` task 4.3 also checks that this external is skipped without GitHub access (edited with this proposal).

## Capabilities

### New Capabilities

- `private-store`: where the private store comes from, how its location stays out of this repository, and how it is skipped and kept private.

### Modified Capabilities

- `neovim-config` (created by `fix-chezmoi-config-template`): compiled spell lists are ignored by git everywhere.

## Impact

- `home/.chezmoi.toml.tmpl` (three questions, one data table), new `home/.chezmoiexternals/private-store.toml.tmpl`, `home/dot_config/git/ignore` (paths after `adopt-chezmoiroot`).
- `chezmoi init` asks three new questions once on each machine.
- The first apply that includes the external runs one `git pull --ff-only` in the existing store on this machine, like the Neovim external; it is applied when the store is clean and in sync.
- Order: after `adopt-chezmoiroot` and `fix-chezmoi-config-template`, whose data pattern and guard it reuses.
  The sender's merge of its session S16 waits until this change is applied.
- Same constraint as the Neovim external: the GitHub CLI login file stays unmanaged (`manage-gh-config`).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
