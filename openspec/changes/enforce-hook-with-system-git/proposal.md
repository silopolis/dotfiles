## Why

The commit-time secret scan delivered by `harden-sensitive-targets` is installed as config-based git hooks (`hook.<name>.command` in the repository's git config), which only git 2.54 or newer reads.
This machine has two git binaries: brew's (2.55) enforces the hook, the system one (2.53) ignores it silently.
On 2026-10-31 a staged, generated token-shaped test string was committed with the system git without any refusal (undone before any push), while the same commit through brew's git was refused.
Any tool that calls the system git (an IDE, a GUI client, a script with an absolute path) therefore bypasses the scan with no warning.
The hk hook installer is shared by the whole fleet (darse's template pins hk and ships the same hooks), so every repository set up this way is exposed on machines whose git is older than 2.54.
Lookup on any repository: `git config --local --get-regexp '^hook\.'` lists config hooks, `/usr/bin/git --version` shows whether that git reads them.
Source: audit finding F12 (`docs/audits/2026-10-30-environment.md`), regression found after its change was archived.

## What Changes

- Install the hook so that every git binary on the machine runs it: legacy script shims in `.git/hooks/` (`hk install --legacy --mise`) instead of, or in addition to, config hooks; check that it fires exactly once with git 2.55.
- Prove it with both binaries: a staged generated token-shaped string is refused by `/usr/bin/git commit` and by brew's `git commit`, and a partial `git commit --only` still works.
- Decide where the install step is recorded so a fresh clone gets it (a mise task such as `hooks:install`, as cem has), since git hooks are not versioned.
- Signal darse and the fleet: darse's template installs hooks with the default hk mode, so the same gap exists there (carried by the Lane A record `darse:T-065`, second finding).
- Amend the `secret-hygiene` requirement "Commit-time secret scanning" with the scenario "refused with every git binary on the machine".

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `secret-hygiene`: the commit-time scan must hold for every git binary on the machine.

## Impact

- Untracked files inside `.git/` change (hook shims); no tracked file except a task or script that records the install.
- `AGENTS.md` may gain one line on the hook install command for a fresh clone.
- Suggested priority: early, before the next change that makes many commits (`adopt-chezmoiroot`), because the gap is open for any non-brew git.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
