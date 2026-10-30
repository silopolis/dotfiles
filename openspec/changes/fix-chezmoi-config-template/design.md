## Context

- `.chezmoi.toml.tmpl` (80 lines on commit `191ee9e`): prompts (lines 1-4), unused `$username` (5-10), includes `cpu`, `machine-type`, `gh-codespaces` (12-14), then `pager` and `color` (16-18), `[data]`, `[git]` with `commitMessageTemplate = "{{ promptString ... }}"` (30), `[env]`, `[update]`, `[diff]` with `diff.exclude` (51), `[edit]`, `[merge]`, empty hooks.
- The included templates end with `[data.cpu]`, `[data.machine]`, `[data.github]` tables, so anything placed after them without a new table header belongs to `[data.github]`.
- `dot_config/chezmoi/chezmoi.toml.tmpl` (56 lines) is a rendered copy plus `encryption` and `[age]`; it has no template actions; `chezmoi doctor` reports it as a suspicious entry.
- `chezmoi dump-config` on 2026-10-30: `diff.exclude: []`, pager `less`, umask 002 (from the process).
- The brew hook (`dot_config/shell/rc.d/110-pkg_brew.sh:63-91`) runs `chezmoi re-add` then commits; brew-file writes the Brewfile with its own mode, so `chezmoi status` keeps a mode-only entry.
- After `adopt-chezmoiroot`, all these paths are under `home/`.

## Goals / Non-Goals

**Goals:**

- `chezmoi init` alone produces a complete, correct config on any machine.
- Every key in the template has the effect it claims.

**Non-Goals:**

- Using the computed data in templates, profiles, distro data (change `fresh-machine-bootstrap`, cem `T-012`).
- Removing the unused prompts or `$username` lines (cleanup in `fresh-machine-bootstrap`, which decides which data stays).
- Mass-applying the new modes (change `reconcile-drift-and-supervised-apply`).

## Decisions

### Order inside the template

```toml
{{- /* prompts and variables */ -}}
encryption = "age"
umask = 0o027
pager = "bat"
color = true

[age]
  identity = "~/.config/chezmoi/key.age"
  recipient = "<public recipient, unchanged>"

{{ includeTemplate "cpu.toml.tmpl" . }}
...
[data]
...
```

`[age]` may come after the top-level keys or after the includes, since it is a table; the includes must follow every bare key.

### umask 027 in chezmoi only

It applies to what chezmoi writes and to how it computes expected modes; the shell's umask (002 today) is decided in `fast-correct-shell-startup`.
Alternatives considered: 022 (world-readable files, Debian default), 002 with `private_` everywhere it matters; 027 chosen by the user: the user's group holds only the user, so 027 mostly removes access for other system accounts.

### Regenerate, do not hand-edit, the config

After the template is fixed and the snapshot source file is deleted, `chezmoi init` (no `--apply`) rewrites `~/.config/chezmoi/chezmoi.toml`.
`promptStringOnce` reuses the existing `data` values, so no prompt appears when they are set.
A copy of the old config goes to `/tmp/opencode/chezmoi.toml.before` for the diff.

### Brew hook re-applies the Brewfile

After `chezmoi re-add "$target"`, the hook runs `chezmoi apply --exclude=scripts "$target"`, which only fixes the mode since contents are equal.
Alternative considered: `chmod` with a computed mode; rejected because it duplicates chezmoi's mode logic.

## Risks / Trade-offs

- [Risk] `chezmoi init` prompts or fails in a non-interactive session. → Run it in a terminal; check first with `chezmoi execute-template --init --promptString email=x,gitemail=x,firstname=x,name=x < .chezmoi.toml.tmpl`.
- [Risk] Deleting the snapshot source makes chezmoi think it should remove `~/.config/chezmoi/chezmoi.toml`. → It does not: removed sources are only forgotten, never deleted, unless listed in `.chezmoiremove`; verify with `chezmoi apply --dry-run --verbose ~/.config/chezmoi`.
- [Risk] Wrong recipient breaks decryption of every encrypted file. → Copy the recipient from the working config; check with `chezmoi cat` on one encrypted target before and after.
- [Risk] umask 027 makes a file unreadable for a service running as another user. → None found on 2026-10-30 (the display manager reads the avatar from its own copy); `reconcile-drift-and-supervised-apply` reviews the full list of mode changes before applying.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
