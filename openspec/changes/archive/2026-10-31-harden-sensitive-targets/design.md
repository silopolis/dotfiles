## Context

- Encryption is age; decrypted targets get their mode from the source name, so an `encrypted_` file without `private_` is deployed with the default mode (0664 with the current umask 002).
- On 2026-10-30, three encrypted targets were 0600 and one was 0664.
  Lookup: `chezmoi managed --include=encrypted --path-style=absolute | xargs stat -c '%a %n'`.
- The history has never been scanned; the repository has been public for its whole life (297 commits on 2026-10-30).
- hk 2.10.0 is the latest release on 2026-10-31; its builtins include `gitleaks` and `detect_private_key`.
  cem pins hk 1.56.1 and moves on its own schedule; mise pins versions per repository, so the two can differ.
- hk 1.56.1's `gitleaks` builtin runs `gitleaks dir` on the staged file names; `gitleaks dir` takes one path and silently scans the whole working tree when given several.
  hk 2.x adds `scan = "staged"`, which runs `gitleaks git --pre-commit --staged` and reads exactly what is staged.
- `which -a chezmoi` lists `~/.local/bin/chezmoi` (v2.62.2) before brew's (v2.72.1); upstream is v2.73.3.

## Goals / Non-Goals

**Goals:**

- No decrypted secret readable by another account.
- A known-clean history, or a known list of what leaked.
- Commits that add a secret are refused locally.
- One chezmoi version in use.

**Non-Goals:**

- Narrowing which processes see the tokens (F23, change `fast-correct-shell-startup`).
- Rotating tokens (tracked in cem "Later steps").
- Other quality hooks (shellcheck, commit grammar): change `add-repo-quality-gates`.
- Moving chezmoi to mise: change `rationalize-package-ownership` (its open question, settled on 2026-10-31: brew now, mise later).
- Cloning the Neovim repository: change `fix-chezmoi-config-template`.

## Decisions

### Rename, do not chmod

Add `private_` to the source name (`git mv`) and apply only that target with `--exclude=scripts`.
A manual `chmod` would be undone on the next apply.
Order of attributes in the name: `encrypted_private_<name>.age` (chezmoi's documented order).

### gitleaks through hk, pinned by mise

- `mise.toml` at the repository root pins `hk = "2.10.0"` and `gitleaks = "8.30.1"` (check with `mise latest gitleaks`).
- `hk.pkl` amends hk 2.10.0's `Config.pkl`.
  Top-level `steps` declares `gitleaks` (scan of the working tree) and `detect_private_key`, which gives the `check` hook.
  An explicit `pre-commit` hook overrides `gitleaks` with `scan = "staged"`, so a commit is judged on exactly what is staged.
- `hk install --mise` installs the hook so that it runs through `mise x`: the tools are found without shell activation (GUI git clients, the brew hook's `git commit`).
- `mise trust` is needed once for the new `mise.toml`.
- Alternative considered: hk 1.56.1 like cem; rejected because its gitleaks step scans the whole tree on multi-file commits, and an allowlist in `.gitleaks.toml` does not depend on the hk version, so the repositories can still share rules.
- Alternative considered: betterleaks (also an hk builtin); gitleaks chosen because it is the established default.
- Alternative considered: pre-commit (Python); rejected, hk is already the fleet's hook manager.

### History scan first, read-only

`gitleaks git --redact --report-path /tmp/opencode/gitleaks-history.json` on the full history, before installing the hook.
The report stays outside the repository and is shown to the user in redacted form only.
Armored age files may produce false positives; if so, an allowlist for `*.age` paths goes into `.gitleaks.toml`, never a blanket disable.

### Which chezmoi stays

Brew's, upgraded to the latest release (`command brew upgrade chezmoi`, which bypasses the brew-file wrapper function), because brew-file already tracks it in the Brewfile and the brew hook would otherwise rewrite it.
Check first that no script or alias calls `~/.local/bin/chezmoi` by path (`grep -rn 'local/bin/chezmoi'` in the source).

### Neovim copy is only reported

F05 is checked, not fixed, here: the remote now exists.
The external that clones it moved to `fix-chezmoi-config-template`, because the repository location comes from configuration data that only `chezmoi init` can add to the local config.
This change never writes in `~/.config/nvim`, since another session may be working there.

## Risks / Trade-offs

- [Risk] The history scan finds a real secret. → Stop; tell the user which kind (without the value); the secret is rotated first; a history rewrite is a separate change with its own approval, since it changes every commit hash of a public repository.
- [Risk] Removing `~/.local/bin/chezmoi` breaks a non-interactive `PATH` that lacks brew (cem checklist rule 10 notes that ssh sessions need brew on `PATH`). → `env -i HOME=$HOME PATH=/usr/bin:/bin bash -lc 'command -v chezmoi'` already fails today (bash login shells load nothing, F22), so nothing gets worse; the needed `PATH` is documented in `AGENTS.md` until `fast-correct-shell-startup` fixes F22.
- [Risk] The rename makes chezmoi see a new target state and the old one removed. → It is the same target path; `chezmoi diff` shows only a mode change; verified before apply.
- [Risk] hk's git stash during pre-commit interferes with the brew hook's `git commit --only`, which commits through a temporary index. → Tested in the scratch clone (task 3.4); if it misbehaves, turn the stash off for that hook (`stash = "none"`, check the value in the hk documentation), which is safe because the staged scan does not read the working tree.
- [Trade-off] hk 2.x here and 1.x in cem until cem moves; the two repositories migrate independently.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
