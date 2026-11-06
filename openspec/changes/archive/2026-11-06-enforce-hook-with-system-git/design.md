## Context

The pre-commit secret scan from `harden-sensitive-targets` is installed as a config-based hook (`hook.hk-pre-commit.command`, through `mise x`), which only git 2.54 or newer reads.
The machine has brew's git 2.55 and the system git 2.53 (`/usr/bin/git`, apt, no newer candidate).

Measured on 2026-11-06, read-only on the live repository, test commits in a scratch clone (`/tmp/opencode/hooktest`, mode 0700, no remote):

| Caller | git it resolves | mise on `PATH` |
| --- | --- | --- |
| interactive zsh, zsh login | brew 2.55 | yes |
| desktop session (plasmashell, `systemd --user`) | brew 2.55 | yes (shims) |
| bash login shell, with or without `env -i` | `/usr/bin/git` 2.53 | no |
| zsh with sshd's default `PATH` (`/etc/environment`) | `/usr/bin/git` 2.53 | no |
| `env -i` with `PATH=/usr/bin:/bin` | `/usr/bin/git` 2.53 | no |
| cron | no user crontab today | |
| `sudo` | not tested (needs a password) | |

Commit of a staged generated token-shaped string, by hook mode:

| Hook mode | brew git, session env | `/usr/bin/git`, session env | `/usr/bin/git`, `env -i` | brew git, `env -i` |
| --- | --- | --- | --- | --- |
| config hook, `mise x` (live repository today) | refused, file named | **accepted** | **accepted** | refused, `mise: not found` |
| shim, `hk install --legacy --mise` | refused, file named | refused, file named | refused, `mise: not found` | refused, `mise: not found` |
| shim, `hk install --legacy` | refused, file named | refused, file named | refused, file named | refused, file named |

With the plain `--legacy` shim: a clean commit passes with both binaries and under `env -i`, hk runs once per commit, and `git commit --only -- <file>` commits that file and keeps an unstaged edit elsewhere.
`HK=0` still skips the hook on purpose.
`hk install` switches modes cleanly: `--legacy` removed the config hook, and a later config install removed the shim, so only one mode is ever present.

Other facts: brew's git is a dependency (not on request) of `soft-serve` and of Homebrew itself (`HOMEBREW_GIT`); mise can reach git only through `conda:git` (2.52 to 2.56 listed); no global `hook.*` entry exists.
cem and darse install config hooks without `mise x` (cem task `hooks:install` runs `hk install`), so `/usr/bin/git` skips their scan too.

## Goals / Non-Goals

**Goals:**

- The scan refuses a staged secret whichever git binary makes the commit and whatever the caller's `PATH`.
- A fresh clone gets the hook with one documented command.
- darse and the fleet learn about the gap and the fix.

**Non-Goals:**

- Changing where git comes from (removing brew's git, adding `conda:git`): left to `rationalize-package-ownership`.
- Fixing bash login startup (F22): `fast-correct-shell-startup`.
- Changing cem or darse here: they get a signal, not a commit.
- A global hook install (`hk install --global` needs 2.54 too).

## Decisions

### Install the hook as a script shim (option C)

`hk install --legacy` writes `.git/hooks/pre-commit`, which every git version runs.
The user chose it on 2026-11-06 from the comparison above.

Alternatives:

- A, remove brew's git: blocked by `soft-serve` and Homebrew's own use, and the remaining 2.53 ignores config hooks anyway.
- B, git 2.56 from mise (`conda:git`): needs an install, a check of the build, and is on `PATH` only where mise is; it would not cover a hard-coded `/usr/bin/git`.
- D, wait for the distribution: leaves the gap open for an unknown time.

### Without `--mise`

The plain shim appends the mise shims directory to `PATH` before calling `hk`, so it works when mise is not on `PATH` (`env -i`, bash login, ssh).
With `--mise` the shim calls `mise x` and fails when mise is not found: the commit is refused, but so is every clean commit from such a caller, with an unhelpful message.
The shim holds an absolute path to the shims directory; it lives under `.git/` (not tracked, not public) and the task below regenerates it.

### A repository task records the install

`mise.toml` gains `[tasks."hooks:install"]` running `hk install --legacy`, as cem names it.
`AGENTS.md` gains one line under Commands: run `mise run hooks:install` after a fresh clone.
Git hooks are not versioned, so this task is the only record.

### Signal the fleet

Nothing is written to darse: its record `darse:T-065` (second finding, open on its own unmerged branch) already points at this change, and reads the outcome from this `design.md` (the measured table and the one-flag fix, which closes the gap for cem and darse too).
Row 20 of the audit's change map records that pointer; darse stays the sole judge of what it changes.
The note that brew's git stays, and why, goes to `rationalize-package-ownership`.

## Risks / Trade-offs

- [hk changes the shim format or drops `--legacy`] → The task and `hk.pkl` pin hk 2.10.0; the spec scenario "Refused with every git binary" is rerun when hk is bumped.
- [A tool deletes or overwrites `.git/hooks/pre-commit`] → `mise run hooks:install` restores it; hk refuses to overwrite a hook it did not write unless `--force`.
- [Someone sets `core.hooksPath`] → git would ignore `.git/hooks/`; none is set today, the check `git config --get core.hooksPath` is part of the verification.
- [`sudo git commit` and cron were not tested] → No cron job commits today; `sudo` is not used for commits in this repository; noted as open.
- [`HK=0` bypasses the scan] → Deliberate escape hatch, kept as in `harden-sensitive-targets`.
- Nothing is written outside `$HOME`, nothing uses sudo, nothing is uninstalled; the only deletion is the local config hook entry, which `hk install --legacy` removes by itself and `hk install --mise` puts back (rollback).

## Migration Plan

1. Add the task to `mise.toml` and the line to `AGENTS.md`.
2. Run `mise run hooks:install` in the live repository; check `git config --local --get-regexp '^hook\.'` prints nothing and `.git/hooks/pre-commit` exists.
3. Replay the spec scenarios in a fresh scratch clone with both binaries and under `env -i`.
4. Rollback: `rm .git/hooks/pre-commit && hk install --mise` restores today's config hook.

## Open Questions

- Does the cron or ssh environment differ from sshd's default `PATH`? Assumed equal, checked again if a job ever commits.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
