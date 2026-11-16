## Why

An interactive zsh takes 3.6 s to start and a login zsh about 9 s (medians on 2026-11-16, details in design.md), and tmux opens login shells, so every new pane waits that long.
Startup also prints a banner on every start, and errors and notices on standard error: an unknown flag and an update notice from the infracost completion, two option errors from the fzf integration when there is no terminal, and an empty-glob error in bash.
Audit findings F06, F19, F20 and the banner part of F33.

The change was drafted on 2026-10-30 as one change for all of shell startup.
On 2026-11-16 it was narrowed to what makes startup silent and fast; the environment half (PATH, locale, tokens, umask) moved to `correct-shell-environment`, see "What moves out" below.

## What Changes

- **Silent startup.**
  - The banners of `profile`, `shellrc` and `zsh/zshrc` print on standard error only when `SHELL_RC_DEBUG` is set, one line per `rc.d` pass.
  - The fzf integration loads only when a controlling terminal exists, which removes the two option errors seen without one.
  - The infracost completion is called with its real syntax and without its update check.
  - The empty `completions.d` glob and a missing gcloud completion no longer print an error.
- **One `rc.d` pass per shell.**
  Interactive login shells no longer run `rc.d` through `profile`: zsh reads `~/.zshrc` next, and bash's `profile` sources `~/.bashrc`.
  Non-interactive login shells, among them the desktop session that the display manager starts through `~/.zprofile`, keep exactly today's pass, so the environment of the graphical session does not change (the improved version is `correct-shell-environment`).
- **Cached completions.**
  A helper, `_cached_completion`, writes the completion script of a tool under `$XDG_CACHE_HOME/shell/completions/<shell>/` and sources the file; the file is regenerated when it is missing, when the tool resolves to another file or is newer than the cache, or when the user asks.
  kubectl, minikube, kind, gh, glab, localstack, infracost and docker use it.
- **Work out of startup.**
  `brew completions link` moves to the brew install script, where it runs once; `chezmoi source-path` runs when a `cm*` alias is used, not at startup; `brew --prefix rustup` (a call through the brew-file wrapper) becomes the constant path it returns.
- **Errors of `aliases` fixed, added on 2026-11-16 at the user's request.**
  `mkcd` becomes a function (an alias cannot take an argument), `cmmkdir` and `cmtouch` become functions that work relative to the source path (the aliases ended in a slash, so their argument stayed in the current directory), `$@` and `$*` are quoted or replaced by `$1` in `gbc`, `gbbc`, `gqrb` and `vagrant-libvirt`, and `convert_to_png` reads its directory from `$1` (it read the literal `$&`) and prints a usage line without one.
  `shellcheck -s bash -S error` on the file reports nothing.
- **Startup-time method.**
  The `AGENTS.md` Commands line names a GNU `time` that is not installed here: it gets the method used for the measures.

## What moves out

To `correct-shell-environment` (proposal only, written in this session): the clean `PATH` (F18, with the aqua bug and the stray live `190` file), the locale (F21), the opt-in token exposure (F23), the shell umask, the order of syntax highlighting, the interactive guard of `shellrc`, and what a non-interactive login shell loads.
The requirements "Clean PATH", "Working locale" and "Opt-in token exposure" and the tasks 1.2, 2.2 (guard), 4.1 to 4.4 of the draft moved with them, with their open questions.
Bash login on a bare terminal (F22) stays here: the load-order fix makes it pass, and it is a check of this change.

## Capabilities

### New Capabilities

- `shell-startup`: how fast and how cleanly bash and zsh start, how many times they load the shared configuration, and what a start must leave as it was.

### Modified Capabilities

None.

## Impact

- `home/dot_config/shell/` (`profile`, `shellrc`, `environment`, `aliases`, `rc.d/110`, `220`, `330`, `420-tools_fzf`, one new `rc.d` file for the helper), `home/dot_config/zsh/zshrc`, `home/dot_config/bash/bashrc`, `home/.chezmoiscripts/run_onchange_after_10-brew.sh.tmpl`, `AGENTS.md`.
- New cache directory under `$XDG_CACHE_HOME` for generated completions; it holds nothing private and is safe to delete.
- Not changed, on purpose: what `rc.d/010-env_user.sh` exports and unsets and the order in which the private environment file is sourced, `rc.d/445-tools_opencode.sh`, aliases and functions other than the ones listed above, the prompt, plugins, brew packages.
- Deployment is one target at a time (`chezmoi apply --exclude=scripts <target>`), `profile` last because it affects the next desktop login; the brew script change runs at the next supervised apply.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
