## Why

An interactive zsh takes about 2.5 s to start and a login zsh about 7 s, and tmux opens login shells, so every new pane waits that long.
Startup also prints banners and an error, builds a long and partly duplicated `PATH`, forces a locale that is not generated, fails to load at all for bash login shells on a bare terminal, and exports every API token to every process (audit findings F06, F18 to F23, F33).

## What Changes

- Login shells load `rc.d` once: `profile` sets the environment only and no longer sources the interactive rc (F06).
- Completions that cost more than a few tens of milliseconds are cached in files regenerated when their tool changes, or loaded lazily; `brew completions link` leaves startup; the four `chezmoi source-path` calls become one (F19).
- `PATH` is built by prepending to the inherited value without duplicates; `~/.local/bin` comes first; the aqua directory bug is fixed (F18).
- The infracost completion call is fixed (F20).
- Locale defaults use generated locales and no longer force `LC_ALL` (F21).
- bash login shells find the shared rc without `XDG_CONFIG_HOME` set; empty globs no longer error (F22).
- API tokens are no longer exported to every shell: exposure becomes opt-in, through a mechanism chosen with the user (F23).
- Banners become debug output; compinit runs once; syntax highlighting loads last; the shell umask is decided (F33).

## Capabilities

### New Capabilities

- `shell-startup`: how fast and how cleanly bash and zsh start, and what environment they provide.

### Modified Capabilities

None.

## Impact

- `dot_config/shell/` (`profile`, `shellrc`, `rc.d/*`, `aliases`), `dot_config/bash/bashrc`, `dot_config/zsh/zshrc`, possibly a new `~/.zshenv`.
- New cache directory for generated completions (under `$XDG_CACHE_HOME`).
- Tools that relied on tokens in the environment need the chosen loader.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
