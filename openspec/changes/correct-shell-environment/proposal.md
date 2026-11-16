## Why

`fast-correct-shell-startup` was narrowed on 2026-11-16 to the part that makes shell startup silent and fast.
What it left out is the half that decides what environment a shell provides: `PATH`, locale, which secrets are exported and to whom, the shell's umask, and what a non-interactive login shell (the desktop session) loads.
Audit findings F18, F21, F23 and the environment points of F33.
This change is a proposal only: no design, no tasks, nothing applied yet.

## What moves in

From the draft of `fast-correct-shell-startup`, with their open questions:

- **Clean `PATH`** (F18): the requirement "Clean PATH" and the task "`PATH` helper (prepend without duplicates, keep inherited); `.local/bin` first; aqua fix".
- **Working locale** (F21): the requirement "Working locale" and the task "Locale defaults (no `LC_ALL`; no `setlocale` warning)".
- **Opt-in token exposure** (F23): the requirement "Opt-in token exposure" and the task "Token loader as decided; tools that need tokens tested".
  It is also the backlog study "Secrets held by the desktop session" in `TODO.md`, which says what the study must settle before any change.
- **Decisions to take with the user** (task 1.2 of the draft): the token exposure mechanism, the shell umask, the locale.
- **Smaller points of F33**: syntax highlighting loads last, the shell umask is decided.
- **The interactive guard of `shellrc`** (task 2.2 of the draft): it is commented out, and restoring it as drafted would stop the desktop session from loading anything, see below.

Bash login on a bare terminal (F22) stayed in `fast-correct-shell-startup`.

## What the review of 2026-11-16 found for this change

- **The desktop session is a login shell of this configuration.**
  The display manager runs `zsh /etc/sddm/Xsession`, which sources `~/.zprofile` (the same file as `~/.profile`) without being interactive, and the environment it leaves goes to the systemd user manager: every graphical process inherits what `rc.d` exports, tokens included.
  `fast-correct-shell-startup` leaves that pass as it is, so the session's environment does not change under it.
- **A better version of "`profile` is environment-only"** is the main design question here.
  As drafted it would give the desktop login a pass of about 40 ms instead of several seconds, but the session would lose what the interactive parts set (mise on `PATH`, tool variables), the private environment file would stay exported there, and a shell-local guard is needed so the environment part does not run twice in an interactive login shell.
  The user wants the better version designed here, together with the token study.
- **`rc.d/040-env_path_base.sh` replaces `PATH`** instead of keeping the inherited value, so the draft requirement "keep inherited entries" does not describe today's behaviour; the second pass of a login shell hid this because it started from the same base.
- **The live `rc.d` has two files that the source does not manage**; one of them is an old copy of `050-env_path_user.sh`, which prepends the user's bin directories a second time.
- **`rc.d/020-env_defaults.sh` forces `LC_ALL`**, and defaults `LANG` to `en_US.UTF-8`, which is not generated here: a shell started without `LANG` (`env -i`, a bare terminal, ssh) makes bash print `setlocale` warnings.
  The tests of `fast-correct-shell-startup` set `LANG` as the desktop session does, so this case stays out of their counts.

## Open questions (carried over)

- Token exposure mechanism: a loader function sourcing the encrypted file in the current shell only, per-directory loading through direnv or mise `[env]`, per-command wrappers, or the key files and keyring options of the backlog study.
- Shell umask: keep 002, align with chezmoi's 027, or Debian's 022.
- Locale: generate `en_US.UTF-8` (needs sudo, needs the user's go) or default `LANG` to a locale that exists with English messages through `LANGUAGE`.
- What a non-interactive login shell loads, and whether `shellrc` gets its interactive guard back once the desktop session no longer depends on it.
- Order: it should run after the study of secrets held by the desktop session, or include it.

## Capabilities

### New Capabilities

- `shell-environment`: which environment a shell provides (`PATH`, locale, exported secrets, umask) and what each kind of shell loads.

### Modified Capabilities

None.

## Impact

- `home/dot_config/shell/` (`profile`, `shellrc`, `rc.d/0*`, `rc.d/020`, `rc.d/930`), possibly a managed `~/.zshenv`.
- Tools that read tokens from the environment, and the desktop session's inherited environment.
- Depends on `fast-correct-shell-startup` (load order, single pass) and on the credential decisions already taken: the wrapper `add-agent-env-wrapper` stays as it is.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
