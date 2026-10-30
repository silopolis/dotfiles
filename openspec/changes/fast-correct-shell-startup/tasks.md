<!-- Draft tasks: refine at the start of the session (/opsx-continue fast-correct-shell-startup); decide the open questions of design.md with the user first. -->

## 1. Measure

- [ ] 1.1 Baseline timings (5 runs, interactive and login) and `zprof` profile; save to `/tmp/opencode/shell-baseline.txt`
- [ ] 1.2 Decide with the user: token exposure mechanism, shell umask, locale

## 2. Load order

- [ ] 2.1 `profile` environment-only; bash login sources `~/.bashrc` when interactive (`SHELL_RC_DEBUG=1` single pass)
- [ ] 2.2 `bash/bashrc` and `shellrc` use `${XDG_CONFIG_HOME:-$HOME/.config}`; interactive guard restored (`env -i ... bash -l -i -c 'alias cm'`)
- [ ] 2.3 Banners behind `SHELL_RC_DEBUG` (`zsh -i -c exit 2>&1 | wc -c` prints 0)

## 3. Speed

- [ ] 3.1 Cached-completion helper; move kubectl, minikube, kind, gh, glab, localstack, infracost (fixed call) to it
- [ ] 3.2 `brew completions link` out of startup (into the brew script or the brew hook)
- [ ] 3.3 One `chezmoi source-path` call for the `cm*` aliases
- [ ] 3.4 `skip_global_compinit=1` in a managed `~/.zshenv`; compinit once with a cached dump
- [ ] 3.5 Re-measure (target 1.0 s median)

## 4. Environment

- [ ] 4.1 `PATH` helper (prepend without duplicates, keep inherited); `.local/bin` first; aqua fix (`uniq -d` empty, nested shell same length)
- [ ] 4.2 Locale defaults (no `LC_ALL`; no `setlocale` warning)
- [ ] 4.3 Token loader as decided; tools that need tokens tested
- [ ] 4.4 Syntax highlighting last; shell umask as decided

## 5. Close

- [ ] 5.1 `zsh -n`, `bash -n`, `shellcheck` on every changed file; apply the shell targets alone (`--exclude=scripts`)
- [ ] 5.2 Record before and after timings in this change; validate, verify, archive

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
