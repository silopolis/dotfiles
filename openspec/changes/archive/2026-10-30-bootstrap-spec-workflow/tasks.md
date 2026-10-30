## 1. Baseline

- [x] 1.1 Snapshot `chezmoi status` and `chezmoi managed` before any edit (`chezmoi status > /tmp/opencode/cm-status-before.txt`)
- [x] 1.2 Write `docs/audits/2026-10-30-environment.md` from the read-only audit (`grep -c '^- \*\*F[0-9]' docs/audits/2026-10-30-environment.md`)

## 2. OpenSpec and agent guide

- [x] 2.1 `openspec init --tools opencode .` (`ls .opencode/command/opsx-apply.md`)
- [x] 2.2 Fill `openspec/config.yaml` with context and rules (`python3 -c "import yaml; yaml.safe_load(open('openspec/config.yaml'))"`)
- [x] 2.3 Ignore opencode's plugin SDK files in `.gitignore` (`git check-ignore .opencode/package.json`)
- [x] 2.4 Write root `AGENTS.md` (`test -s AGENTS.md`)
- [x] 2.5 Add `AGENTS.md`, `docs`, `openspec` to `.chezmoiignore` (`chezmoi managed | grep -cE '^(AGENTS|docs|openspec)'` prints 0)

## 3. Changes

- [x] 3.1 Scaffold the changes of the audit's change map (`openspec list`)
- [x] 3.2 Write full artifacts for the near-term changes, proposals and specs for the others (`openspec validate --all --strict`)

## 4. Checks and close

- [x] 4.1 Target state unchanged (`chezmoi status | diff - /tmp/opencode/cm-status-before.txt`)
- [x] 4.2 Public-writing pattern check on `AGENTS.md`, `docs/`, `openspec/`
- [x] 4.3 Archive this change (`openspec archive bootstrap-spec-workflow --yes`)
- [x] 4.4 Propose the commit messages to the user (the commits are made after validation)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
