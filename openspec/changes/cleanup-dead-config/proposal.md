## Why

Years of additions left dead or misleading material in the source state: ignore entries that do nothing, backup files deployed into `~/.config`, configs for tools that are absent or retired, misspelled theme targets, vendored bulk copies, a few risky defaults, and git settings tied to another OS (audit findings F29, F30, F31, F35, F37, F39, F40; cem checklist 4.2 to check).

## What Changes

- Remove ineffective `.chezmoiignore` entries and the stale `.chezmoiremove` line (F29).
- Remove leftovers from the source and their deployed copies: `vimrc.bak`, `packages.json.bak`, `tmuxline.conf`, unused alacritty files, the commented `cnf` external; delete the untracked swap file (F30).
- Decide for qterminal, hunspell and gh-copilot: remove the config, or install the tool; fix the qterminal template's misuse of `.chezmoi.gid`; remove the retired gh-copilot extension with the user's go (F31).
- Fix theme target names (`catppucin`, `catpuccin`), drop the unused delta theme file, review stale theme upstreams (F35).
- Trim vendored bulk: fabric patterns (an external or the tool's own update instead of a copy), kitty's 2000-line stock config reduced to the active settings (F37).
- Restrict kitty remote control to a socket (F39).
- git: credential helper without an absolute path, Linux-friendly `open` aliases, duplicate `lg`, unused coauthors and message files, consistent indentation; confirm checklist 4.2 is covered by commit `d624901` and tick it (F40).

## Capabilities

### New Capabilities

- `config-hygiene`: the source state holds only live, correct material.

### Modified Capabilities

None.

## Impact

- Deletions in the source and, with the user's go, of their deployed copies (`.chezmoiremove` entries for one apply).
- Small behaviour changes in kitty and git.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
