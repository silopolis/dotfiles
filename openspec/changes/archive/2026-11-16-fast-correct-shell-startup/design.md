## Context

See the audit, section 2.6 (load order) and findings F06, F19, F20 and F33.
The numbers of the audit date from 2026-10-30; the ones below were measured again on 2026-11-16, before any change (`/tmp/opencode/shell-startup/baseline.txt`, kept outside the repository).

Medians, no terminal, stdin from `/dev/null`, timed with `date +%s.%N` (GNU `time` is not installed), alternating runs because startup varies by hundreds of milliseconds between runs minutes apart:

| Shell | Median |
| --- | --- |
| `zsh -i`, 7 consecutive runs | 3.6 s |
| `zsh -i`, 7 alternating rounds | 4.9 s |
| `zsh -l -i` | 9.2 s |
| `bash -i` / `bash -l -i` | 3.4 s / 3.2 s |

What each source costs (zsh, inside the shell, median of 5):

| Source | Cost |
| --- | --- |
| `localstack completion` | 1631 ms |
| `brew completions link` (`110-pkg_brew.sh`) | 667 ms |
| `brew --prefix rustup` (`220-lang_rust.sh`, goes through the brew-file wrapper that 110 defines) | about 470 ms |
| infracost completion, with the right syntax | 386 ms (the broken call exits early at 32 ms) |
| minikube completion | 340 ms |
| four `chezmoi source-path` calls | 127 ms |
| gh, kubectl, glab, kind, docker completions | 119, 88, 87, 74, 52 ms |
| compinit (its `compaudit` alone 103 ms) | 118 ms |
| compinit with a rebuilt dump | 1.5 to 2.4 s |
| `mise activate`, syntax highlighting | 76 ms, 38 ms |
| everything else | under 20 ms each |

Two facts differ from the audit:

- compinit does not run twice because of `/etc/zsh/zshrc`: that file calls it only when `os-release` says Ubuntu, and this machine is Kali.
  The costly double is the login shell's second `rc.d` pass: it adds the brew directories to `fpath` again, the completion dump then lists 2332 files instead of 2075, and compinit rebuilds the dump in every login shell and again in the next normal one.
- The two `can't change option: zle` errors come from `fzf --zsh` and only when there is no terminal (an agent, a script running `zsh -i -c`); with a terminal they do not appear.

Whole-startup figures do not include the first prompt: direnv (60 ms), mise's hook (41 ms) and starship (19 ms) run before the first prompt, not inside `-c exit`.
That is a known gap of the method, listed with the other tools in the results.

Who reads `profile` (`~/.zprofile` and `~/.profile` are the same file):

- the display manager: SDDM runs `zsh /etc/sddm/Xsession`, which sources `~/.zprofile` without being interactive; whatever that leaves in the environment goes to the systemd user manager, so every graphical process inherits it;
- every tmux pane (`default-shell` is zsh), a console login, `zsh -l`: interactive login shells;
- `zsh -l -c cmd`: rare.

Today `profile` runs all of `rc.d` in each of those cases.

## Goals / Non-Goals

**Goals:**

- Interactive zsh startup at most 1.0 s (median of at least 7 alternating runs, in a terminal), login zsh at most 150 ms above the interactive median.
- No byte on standard output or standard error at startup unless debugging is requested, in zsh and bash, login or not.
- Each interactive shell loads `rc.d` once.
- Nothing the user, the desktop session or an agent depends on changes.

**Non-Goals:**

- Anything of the environment half: `PATH`, locale, tokens, umask, highlighting order, `shellrc` guard, what a non-interactive login shell loads (`correct-shell-environment`).
- New aliases (`port-omalap-shell-aliases`), the prompt, plugins beyond load order, brew packages.
- `rc.d/010-env_user.sh` and `rc.d/445-tools_opencode.sh`: speed work may move or cache around them, but their behaviour is kept and tested.
- A `compinit -C` fast path and a managed `~/.zshenv` with `skip_global_compinit`: the target is met without them (see Alternatives).

## Decisions

### `profile` changes for interactive login shells only

```sh
case $- in
  *i*)  # interactive login: the shell's own rc file loads rc.d once
        # zsh reads ~/.zshrc next; bash reads only this file, so ask for ~/.bashrc (Debian's convention)
        ;;
  *)    # non-interactive login (desktop session, zsh -l -c): unchanged
        ;;
esac
```

- The desktop session keeps today's full pass, so its `PATH`, mise entries, private environment and everything else it inherits are exactly what they are now.
- Interactive login shells get one pass instead of two: tmux panes no longer pay for the second pass, and the completion dump stops being rebuilt when login and normal shells alternate.
- Alternative considered, as drafted: `profile` environment-only for every login shell.
  It would make the desktop login fast and quiet, but the session would lose what the interactive parts set (mise on `PATH`, tool variables), the private environment file would stay exported there (the file is an environment part, and its behaviour is out of scope), and it needs a shell-local guard so the environment part does not run twice.
  The user chose to keep this change to the interactive case and to design the better version with the token study, in `correct-shell-environment`.
- `~/.config/zsh/zshrc` stays, as the loader of the non-interactive login path; only its banner changes.
  `~/.config/bash/bashrc` gets the `${XDG_CONFIG_HOME:-$HOME/.config}` fallback it lacked.

### Debug output instead of banners

`SHELL_RC_DEBUG` (any non-empty value) makes `profile` and `zsh/zshrc` print one line each and `shellrc` one line per `rc.d` pass, on standard error, each `shellrc` line containing the text `rc.d` so a count is possible.
Standard error, not standard output: a debug line must not end up in the output of a command that starts a shell.

### Cached completions

`_cached_completion <tool> <command...>` (new file `home/dot_config/shell/rc.d/335-shell_completion_cache.sh`, after compinit, before the aliases) makes `$XDG_CACHE_HOME/shell/completions/<shell>/<tool>` usable and sets `_CC_FILE` to it; the caller sources it:

```sh
_cached_completion kubectl kubectl completion "$CURRENT_SHELL" && . "$_CC_FILE"
```

- Sourcing is done by the caller, at the top level: `source` inside a function would make top-level `typeset`/`local` statements of a completion script local to the function in zsh.
- The file starts with a line `#cached-completion: <real path of the tool>`.
  It is used when the tool still resolves to that file (`[ "$bin" -ef "$recorded" ]`: no subprocess) and is not newer than the cache file.
  A brew upgrade moves the symlink to a new Cellar directory, a mise install to a new version directory: the key changes and the file is regenerated.
- Regeneration is silent (standard error discarded, standard input from `/dev/null`), the output goes to a temporary file in the same directory and is moved into place, so a tmux session opening several panes at once never sources a half-written file.
  A command that fails or prints nothing caches nothing, and an older cache file stays in use.
- `SHELL_COMPLETION_REFRESH=1` forces regeneration; deleting the cache directory does the same.
- With `SHELL_RC_DEBUG` set, each regeneration prints one line on standard error (`completion cache: regenerated <tool>`), which the tests count; nothing else prints.
- Limits, accepted: a tool replaced in place by its package manager with an older modification time (apt), and a tool behind a mise shim (the shim resolves to mise itself), keep their cache until it is refreshed.
  The cached scripts of all eight tools ask the tool for completions when TAB is pressed (cobra's `__complete`, click's `_COMPLETE`), so an old copy stays correct for the tool's flags.
- Alternative considered: lazy wrappers that load a completion on first use, for tools whose completion is slow and rarely used (localstack); not needed once the script is a file of a few kilobytes, which sources in a few milliseconds.
- infracost is called as `env INFRACOST_SKIP_UPDATE_CHECK=true infracost completion <shell>`: with that variable its update notice does not print.

### `chezmoi source-path` at use time

The four aliases that expand the source path at definition (`cmll`, `cmlla`, `cmmkdir`, `cmtouch`; `cmcd` already does it at use) become single-quoted, so `chezmoi source-path` runs when the alias is used.
It costs nothing at startup, prints no error on a machine where chezmoi is not installed yet, and expands to the same words as before (`cmmkdir` and `cmtouch` keep their odd trailing slash: the aliases are not this change's business).
Alternative: one call at startup stored in a variable (about 32 ms per start), as the draft said.

### Errors of `aliases`

The user asked on 2026-11-16 for the shellcheck errors of the file to be fixed with this change, and for the `cmmkdir` and `cmtouch` slash and `convert_to_png` to be fixed too:

- `mkcd` is a function (SC2142), with `&&` between `mkdir` and `cd` and quoted arguments.
- `cmmkdir` and `cmtouch` are functions that run in a subshell inside `$(chezmoi source-path)`, so `cmmkdir dot_config/x` makes that directory in the source state; as aliases ending in a slash they expanded to `mkdir -p <source>/ dot_config/x`, which left the argument in the current directory.
- `gbc`, `gbbc` and `gqrb` take one branch name and use `$1`, quoted; `vagrant-libvirt` passes `"$@"`.
- `convert_to_png` takes the directory from `$1` and checks it by hand: `${1:?}` ends a `zsh -c` shell, and `$&` was the literal text.
- Not done, left for `port-omalap-shell-aliases`: bash-only syntax of the file (`function br {`), the warnings under error level, and the other broken functions (`vbx_create`).

### `brew completions link` once, in the brew script

`brew completions state` already reports that completions are linked, and Homebrew keeps that state and relinks on install, upgrade and update: the call at every startup is redundant.
`run_onchange_after_10-brew.sh.tmpl` runs `brew completions link` only when `brew completions state` does not say they are linked, so it is idempotent and the brew hook keeps working as before.
It runs at the next supervised apply, not at deployment of the shell targets.

### Constant rustup prefix

`PATH="$(brew --prefix rustup)/bin:$PATH"` becomes the directory `$HOMEBREW_PREFIX/opt/rustup/bin`, added when it exists: the same value `brew --prefix rustup` prints for an installed formula, without starting brew and its wrapper.

### fzf only with the line editor

`source <(fzf --zsh)` loads only when the line editor is on and a controlling terminal can be opened (`[[ -o zle ]] && { : < /dev/tty; } 2> /dev/null`): the integration binds keys and widgets and sets the `zle` option, which zsh refuses without a controlling terminal, and `[[ -o zle ]]` alone reads "on" there.
Opening `/dev/tty` is the test because the check is about the terminal, not about standard input: a shell started from a terminal with standard input redirected keeps the integration.

### Shell state of `fpath`

`typeset -U fpath` before the additions of `110-pkg_brew.sh`, and the `$?` tests of that file that always read 0 become plain directory tests: a re-sourced `~/.zshrc` no longer duplicates entries and no longer changes the dump.

### Test method

A driver kept outside the repository (`/tmp/opencode/shell-startup/`), run against scratch destinations, never against the real configuration:

- the source at its previous commit and the working tree are rendered into two scratch directories (`chezmoi -S <source> apply --destination <scratch> --exclude=scripts,externals,encrypted`, after a dry run);
- every shell starts under `env -i` with the scratch directory as `HOME` and `XDG_CONFIG_HOME`, and mise's directories pointed into it;
- a synthetic private environment file with `DEMO_` names, and one synthetic value under the name that `010-env_user.sh` unsets, stand in for the real one;
- checks are counts and exit statuses, and the replay of the display manager's call (`emulate -R zsh; . ~/.zprofile` under `env -i`) compares the exported variable names before and after.

## Risks / Trade-offs

- [Risk] A mistake in `profile` could leave interactive login shells with nothing loaded, or change the desktop session.
  → The driver runs `zsh -l -i`, `bash -l -i` and the replayed display manager call before and after; `profile` is deployed last, the rollback is one command that also works from a text console.
- [Consequence, accepted] The `PATH` of an interactive login shell changes: it now equals the one of a normal interactive shell.
  The old second pass re-ran `120-pkg-aqua.sh` with `AQUA_BIN_DIR` already set, which appended `/bin` again, so a login shell had a nonexistent `aquaproj-aqua/bin/bin` entry and the real aqua directory further down the list.
  The tools in that directory now win over brew's as they do in a normal shell.
  The bug itself (F18) is in `correct-shell-environment`.
- [Risk] A cached completion script behaves differently from `source <(...)`.
  → The driver compares the completion functions and registrations (`_comps`, `functions`) of the old and the new startup, and checks that each cached tool completes.
- [Risk] Two shells regenerate the same cache file at once.
  → Temporary file plus move; the last one wins, with the same content.
- [Risk] A tool upgrade that the key does not see leaves a stale completion script.
  → Documented limit, `SHELL_COMPLETION_REFRESH=1`, and the scripts are dynamic.
- [Trade-off] The desktop login still loads the interactive parts it never uses: the cache makes that pass fast, and the better split is `correct-shell-environment`.

## Open Questions

None left in this change; the ones about `PATH`, locale, tokens and umask moved with their requirements.

## Results

Measured on 2026-11-16 on the laptop, after the six shell targets were deployed one by one (`rc.d/335`, `aliases`, `110` and `220`, `330` and `420-tools_fzf`, `shellrc` with `zsh/zshrc` and `environment`, `bash/bashrc` and `profile`).
Method: 8 alternating rounds of the four shell kinds under a pseudo-terminal (`script -qec`), one run each per round after a warm-up, timed with `date +%s.%N`, medians; load average under 1.

| Shell | Before | After |
| --- | --- | --- |
| `zsh -i -c exit` | 3.62 s (7 consecutive runs; 4.94 s in alternating rounds) | 0.19 s (0.18 to 0.24) |
| `zsh -l -i -c exit` | 9.24 s | 0.23 s (0.21 to 0.25), 40 ms above the interactive median |
| `bash -i -c true` | 3.36 s | 0.37 s (0.33 to 0.41) |
| `bash -l -i -c true` | 3.22 s | 0.43 s (0.39 to 0.47) |

The two zsh targets (at most 1.0 s, login at most 150 ms above interactive) are met with a wide margin; the baseline was taken without a terminal, the after figures under one, and the scratch comparison of the same two configurations under the same conditions gave 3.69 s to 0.26 s (`zsh -i`) and 6.84 s to 0.28 s (`zsh -l -i`).

What is left inside `rc.d` for zsh (median of 5, in the shell): 166 ms in total, of which `800-aliases.sh` 53 ms, `415-tools_mise.sh` 35 ms, `330-shell_completion.sh` 24 ms (compinit), `930-highlighting.sh` 16 ms, `110-pkg_brew.sh` 10 ms, `990-prompt.sh` 6 ms, `030-env_current_shell.sh` 5 ms (the `ps` call).
Nothing else is above 4 ms.

Not timed by `-c exit`, so not in the table: the first prompt, where direnv's hook (about 60 ms), mise's hook (about 41 ms) and starship (about 19 ms) run.
Those belong to the tools and the prompt, outside this change.

What did the work, from the baseline costs: the second `rc.d` pass of login shells and the completion dump it rebuilt (1.5 to 2.4 s each), `localstack completion` (1.6 s), `brew completions link` (0.67 s), `brew --prefix rustup` (0.47 s), and the infracost, minikube, gh, kubectl, glab, kind and docker completions (about 1.1 s together), now read from cache files.

Checks kept in `/tmp/opencode/shell-startup/` (outside the repository): zero bytes at startup in six shell kinds with and without a terminal, one `rc.d` pass per shell kind, a stable completion dump over alternating login and normal starts, 34 cache-helper cases in zsh and bash, the private environment and the `opencode` function unchanged, and the replay of the display manager's call giving the same variables on the real home before and after `profile` (103 variables, same hash of names and values).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
