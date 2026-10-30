## Context

- Omarchy's bash defaults (aliases, functions) were sourced from its own install tree on the old laptop; copies are in the restic archive, and the old `~/.bashrc` is in `~/Archives/omalap-2026-10/`.
- The list of entries to port is in cem's checklist 4.1; clash rule: this machine wins (`a`, `n`).
- Current alias file: `dot_config/shell/aliases` (about 171 aliases and 14 functions); broken entries listed in audit F32.

## Goals / Non-Goals

**Goals:**

- Every ported entry works in bash and zsh, or is restricted to one shell on purpose.
- No alias shadows a system command unintentionally.

**Non-Goals:**

- Reorganizing the whole alias file (possible later split by domain).
- Startup speed (done in `fast-correct-shell-startup`).

## Decisions

### Where ported entries go

Functions longer than a few lines go to their own `rc.d` file per domain (`810-func_git.sh`, `820-func_ssh.sh`, ...); one-line aliases go into `aliases` under a section per domain.

### Shadowing check

Before adding an alias, `type -a <name>` in both shells; an alias that hides a binary is only kept if intended, with a comment.

## Risks / Trade-offs

- [Risk] Omarchy functions assume Arch tools or paths. → Port behaviour, not text; guard optional tools with `command -v`.
- [Risk] A short alias (`c`, `t`, `g`) collides with a future tool. → The shadowing check; document each one-letter alias.

## Open Questions

- Keep `icat` for kitty and rename it (the Sleuth Kit's `icat` matters on Kali)?

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
