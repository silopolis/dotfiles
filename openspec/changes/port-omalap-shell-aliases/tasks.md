<!-- Draft tasks: refine at the start of the session (/opsx-continue port-omalap-shell-aliases), after `fast-correct-shell-startup` is archived. -->

## 1. Source material

- [ ] 1.1 Extract the Omarchy bash aliases and functions from the archive (cem `docs/how-to/archive.md`) into `/tmp/opencode/omarchy-shell/`
- [ ] 1.2 Table of entries: name, Omarchy definition, existing definition here, decision (port, skip, rename); validated by the user

## 2. Port

- [ ] 2.1 Aliases (`zsh -n`, `bash -n`; `alias <names>` in both shells)
- [ ] 2.2 Functions, one `rc.d` file per domain, zsh compatibility checked for each
- [ ] 2.3 Shadowing check (`type -a <name>` in both shells)

## 3. Fixes (F32)

- [ ] 3.1 Fix or drop each broken entry; guard optional tools

## 4. Close

- [ ] 4.1 Apply the shell targets alone (`--exclude=scripts`); startup time still within the `shell-startup` limit
- [ ] 4.2 Tick cem checklist 4.1; validate, verify, archive

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
