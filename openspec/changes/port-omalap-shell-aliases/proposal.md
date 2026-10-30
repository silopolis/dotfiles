## Why

A year of habits on the Omarchy laptop came with its aliases and functions, now missing on this machine, while the existing alias file carries broken or risky entries (cem checklist 4.1; audit finding F32).
It comes after `fast-correct-shell-startup` because both edit the same files.

## What Changes

- Port the Omarchy aliases into `dot_config/shell/aliases` (or a new `rc.d` file): `c cx cy h t g gcm gcam gcad mup ff eff sff open .. ... ....`, the zoxide `cd` wrapper, `l ll lA la lt`; on a name clash the existing definition wins (`a`, `n`).
- Port the functions: rsync helper, ssh reconnect, ssh port forwarding, git worktrees, tmux, herdr, `try` (scratch repositories under `~/Work/tries`).
- Check each port in both bash and zsh.
- Fix or drop the broken entries of F32 (`aptu`, `genpw`, `lt` and `check_language`, `icat`, double `k`, `AWS_PAGER`, `vbx_create`, `convert_to_png`, `egrep` and `fgrep`, double `br`).

## Capabilities

### New Capabilities

- `shell-aliases`: which aliases and functions exist, in which shells, and the rules for adding one.

### Modified Capabilities

None.

## Impact

- `dot_config/shell/aliases`, possibly new `dot_config/shell/rc.d/8NN-*.sh` files.
- Source material: the Omarchy laptop's shell files, in the restic archive and in `~/Archives/omalap-2026-10/` (lookup in cem `docs/how-to/archive.md`).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
