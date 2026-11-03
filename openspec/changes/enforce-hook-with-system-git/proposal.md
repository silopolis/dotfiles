## Why

The commit-time secret scan delivered by `harden-sensitive-targets` is installed as config-based git hooks (`hook.<name>.command` in the repository's git config), which only git 2.54 or newer reads.
This machine has two git binaries: brew's (2.55) enforces the hook, the system one (2.53) ignores it silently.
On 2026-10-31 a staged, generated token-shaped test string was committed with the system git without any refusal (undone before any push), while the same commit through brew's git was refused.
Any caller that resolves the system git therefore bypasses the scan with no warning.
The hk hook installer is shared by the whole fleet: darse, istc and cem install their hooks the same way (config hooks, no script shims), so they have the same gap on this machine.
Lookup on any repository: `git config --local --get-regexp '^hook\.'` lists config hooks, `/usr/bin/git --version` shows whether that git reads them.
Source: audit finding F12 (`docs/audits/2026-10-30-environment.md`), regression found after its change was archived.

Facts measured on 2026-11-03, before choosing a fix:

- Which callers reach the old git is narrower than first thought: applications started from the desktop session have brew and the mise shims on their `PATH` (read from the session's environment), so they already use brew's git 2.55 and the hook fires.
  The gap is any caller without brew on its `PATH` (an `env -i` login shell does not even find chezmoi, F22; cron and ssh commands are to be checked) and any caller that hard-codes `/usr/bin/git`.
- Brew's git is installed as a dependency, not on request, and is not in the Brewfile.
  Homebrew uses it for itself (`HOMEBREW_GIT`), and one installed formula (`soft-serve`) depends on it.
- The system git comes from apt: installed and candidate are both 2.53; the distribution has nothing newer.
- mise has no `git` entry in its registry; the only source it can reach is the `conda` backend (`conda:git`, 2.56.0 listed).
- Config hooks need git 2.54 or newer; script shims in `.git/hooks/` work with every git version (`hk install --help`).

## What Changes

1. **Evaluate where git should come from, first and read-only.**
   For each option below, record which git each caller resolves and whether a staged generated token-shaped string is refused.
   Callers to test: interactive zsh, bash login shell, a desktop-launched application's environment, `env -i` with a minimal `PATH`, cron or an ssh command (environment as they get it), `sudo`, and a direct `/usr/bin/git` call.
   - **A. Remove brew's git.**
     Blocked today by `soft-serve` and by Homebrew's own use of it (`brew` would fetch it again); it would leave only git 2.53, which ignores config hooks, so hooks would have to become shims anyway.
     Check what brew does when its git is missing, and whether the dependent formula can go.
   - **B. Provide an up-to-date git as a mise tool** (`conda:git`).
     Fits the install priority (mise first) and could replace brew's copy.
     Check what the build includes (https remotes, credential helper support, `git hook`, locale), how it updates, and whether it is on `PATH` for the callers above.
     It overlaps with `rationalize-package-ownership`, which owns brew versus mise decisions, so the choice is recorded there as well.
   - **C. Install hooks as script shims** (`hk install --legacy --mise`).
     Works with every git, whatever its source, so it can be combined with A or B.
     Check it fires exactly once with git 2.55 and that `git commit --only` still works.
   - **D. Do nothing about the binary and wait** for a distribution git of 2.54 or newer.
     Record why this leaves the gap open.
2. **Present the comparison to the user and choose.**
   The change does not pick an option on its own; removing brew's git, adding a mise tool or installing hooks outside this repository each need the user's explicit go.
3. **Implement the chosen option**, then prove the requirement with both binaries if two remain: a staged generated token-shaped string is refused by `/usr/bin/git commit` and by the `git` first on `PATH`, and a partial `git commit --only` still works.
4. **Record how a fresh clone gets the hook** (a mise task such as `hooks:install`, as cem has), since git hooks are not versioned.
5. **Signal darse and the fleet**: darse's template installs hooks with the default hk mode, so the same gap exists there (carried by the Lane A record `darse:T-065`, second finding; add the outcome of the evaluation to it if the record is still open).
6. **Amend the `secret-hygiene` requirement** "Commit-time secret scanning" with the scenario "refused with every git binary on the machine" (already drafted in this change's spec).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `secret-hygiene`: the commit-time scan must hold for every git binary on the machine.

## Impact

- Untracked files inside `.git/` change (hook shims); no tracked file except a task or script that records the install.
- Depending on the option chosen: a brew formula removed or kept, a mise tool added to the managed global mise configuration, `AGENTS.md` gaining one line on the hook install command for a fresh clone.
- Suggested priority: early, before the next change that makes many commits (`adopt-chezmoiroot`), because the gap is open for any caller without brew on its `PATH`.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
