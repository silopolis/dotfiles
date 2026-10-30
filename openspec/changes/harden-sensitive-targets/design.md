## Context

- Encryption is age; decrypted targets get their mode from the source name, so an `encrypted_` file without `private_` is deployed with the default mode (0664 with the current umask 002).
- On 2026-10-30, three encrypted targets were 0600 and one was 0664.
  Lookup: `chezmoi managed --include=encrypted --path-style=absolute | xargs stat -c '%a %n'`.
- The history has never been scanned; the repository has been public for its whole life (297 commits on 2026-10-30).
- hk 1.56.1 is already used through mise (it is pinned in cem because hk 2.x cannot load 1.x `hk.pkl` files); its builtins include `gitleaks` and `detect_private_key`.
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
- Moving chezmoi to mise: change `rationalize-package-ownership`.

## Decisions

### Rename, do not chmod

Add `private_` to the source name (`git mv`) and apply only that target with `--exclude=scripts`.
A manual `chmod` would be undone on the next apply.
Order of attributes in the name: `encrypted_private_<name>.age` (chezmoi's documented order).

### gitleaks through hk, pinned by mise

- `mise.toml` at the repository root pins `hk = "1.56.1"` and `gitleaks` at the current release (check with `mise latest gitleaks`).
- `hk.pkl` amends hk 1.56.1's `Config.pkl` and declares `gitleaks` and `detect_private_key` for `pre-commit` and `check`, the same layout as cem's `hk.pkl`.
- `mise trust` is needed once for the new `mise.toml`.
- Alternative considered: betterleaks (also an hk builtin); gitleaks chosen because it is the established default and both repositories can share the rule set.
- Alternative considered: pre-commit (Python); rejected, hk is already the fleet's hook manager.

### History scan first, read-only

`gitleaks git --redact --report-path /tmp/opencode/gitleaks-history.json` on the full history, before installing the hook.
The report stays outside the repository and is shown to the user in redacted form only.
Armored age files may produce false positives; if so, an allowlist for `*.age` paths goes into `.gitleaks.toml`, never a blanket disable.

### Which chezmoi stays

Brew's, upgraded to the latest release (`brew upgrade chezmoi`), because brew-file already tracks it in the Brewfile and the brew hook would otherwise rewrite it.
Check first that no script or alias calls `~/.local/bin/chezmoi` by path (`grep -rn 'local/bin/chezmoi'` in the source).

## Risks / Trade-offs

- [Risk] The history scan finds a real secret. → Stop; tell the user which kind (without the value); the secret is rotated first; a history rewrite is a separate change with its own approval, since it changes every commit hash of a public repository.
- [Risk] Removing `~/.local/bin/chezmoi` breaks a non-interactive `PATH` that lacks brew (cem checklist rule 10 notes that ssh sessions need brew on `PATH`). → Check `ssh`-style use with `env -i HOME=$HOME PATH=/usr/bin:/bin bash -lc 'command -v chezmoi'` and document it in `AGENTS.md` if it changes.
- [Risk] The rename makes chezmoi see a new target state and the old one removed. → It is the same target path; `chezmoi diff` shows only a mode change; verified before apply.
- [Trade-off] Pinning hk 1.x delays hk 2.x; both repositories move together later.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
