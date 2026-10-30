## Context

See the audit, section 2.6 (load order) and findings F06, F18 to F23, F33, with measured costs in F19.
Measured on 2026-10-30: `zsh -i -c exit` 2.5 to 3.6 s, `zsh -l -i -c exit` 7.0 s; tmux `default-shell` is `/bin/zsh`, which starts login shells.

## Goals / Non-Goals

**Goals:**

- Interactive zsh startup at most 1.0 s (median of 5), login shells within 10 % of it.
- Silent, error-free startup.
- Predictable `PATH` and locale.

**Non-Goals:**

- New aliases (change `port-omalap-shell-aliases`).
- Changing the prompt or plugins beyond load order.

## Decisions

### Profile is environment-only

`profile` exports `CURRENT_SHELL`, XDG and `PATH`-related variables, and sources nothing interactive; `~/.zshrc` and `~/.bashrc` keep loading `shellrc`.
For bash login shells, `profile` sources `~/.bashrc` when interactive (Debian's convention), since bash reads only one of them.

### Cached completions

A helper `_cached_completion <tool> <command...>` writes the completion script to `$XDG_CACHE_HOME/shell/completions/<shell>/<tool>` when missing or older than the tool's binary (`[ "$bin" -nt "$file" ]`), then sources it.
Alternative considered: lazy wrappers per command (define a stub that loads the completion on first use); kept for tools whose completion is slow to generate and rarely used (localstack).

### Token exposure (to confirm with the user first)

Options:

- a loader function (`secrets on`) that sources the encrypted environment into the current shell only;
- per-directory loading through direnv or mise `[env]` with age-encrypted values;
- per-command wrappers for the few tools that need a token.

Default proposal: loader function plus wrappers for `gh` and the AI tools; nothing exported at startup.

### Shell umask

Options: keep 002, align with chezmoi's 027, or Debian's 022; decided with the user in this session, applied in `profile`.

## Risks / Trade-offs

- [Risk] Tools that read tokens from the environment break silently. → List them first (`grep` the token variable names locally in tool configs); test each.
- [Risk] Cached completions go stale after an upgrade that keeps the binary's mtime. → Cache key includes the tool's `--version` output hash when cheap.
- [Risk] Removing `LC_ALL` changes the language of messages and sorting. → Set `LANG` and the `LC_*` categories explicitly to generated locales; compare `locale` before and after.

## Open Questions

- Token exposure mechanism (above).
- Shell umask value.
- Generate `en_US.UTF-8` (needs sudo) or default to `fr_FR.UTF-8` for `LANG` with English messages through `LANGUAGE`?

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
