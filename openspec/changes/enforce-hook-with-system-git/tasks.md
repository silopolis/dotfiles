## 1. Preconditions

- [x] 1.1 Recheck the facts the design relies on: two git binaries, hk pinned, no `core.hooksPath`, no global hook (`/usr/bin/git --version; git --version; mise ls --current hk; git config --get core.hooksPath; git config --global --get-regexp '^hook\.'` shows 2.53, 2.55, hk 2.10.0 and nothing for the last two)
- [x] 1.2 Remove the evaluation scratch clone (`rm -rf /tmp/opencode/hooktest && test ! -e /tmp/opencode/hooktest`)

## 2. Install the shim

- [x] 2.1 Add `[tasks."hooks:install"]` to `mise.toml` with a one-line description and `run = "hk install --legacy"` (`mise tasks ls | grep -c 'hooks:install'` prints 1)
- [x] 2.2 Run it in the live repository (`mise run hooks:install`; then `git config --local --get-regexp '^hook\.'` prints nothing and `test -x .git/hooks/pre-commit`)
- [x] 2.3 Add one line to `AGENTS.md` under Commands: after a fresh clone, run `mise run hooks:install` (`rg -n 'hooks:install' AGENTS.md`)

## 3. Prove the requirement

- [x] 3.1 Make a scratch clone in a 0700 directory, drop its remote, run `mise trust` and `mise run hooks:install` there (`test -x <clone>/.git/hooks/pre-commit`)
- [x] 3.2 Stage a generated token-shaped string (never printed) and commit with `/usr/bin/git`, with the `git` first on `PATH`, and with `/usr/bin/git` under `env -i HOME="$HOME" PATH=/usr/bin:/bin`; each is refused and names the file (`git -C <clone> rev-parse HEAD` unchanged after each try)
- [x] 3.3 Same with a private-key header (`git -C <clone> rev-parse HEAD` unchanged)
- [x] 3.4 With an unstaged edit in one file, `git commit --only -m test -- <other file>` succeeds and keeps the edit (`git -C <clone> diff --name-only` still lists the edited file)
- [x] 3.5 `hk check --all` passes on the clean tree, and `mise ls --current` lists hk and gitleaks at the pinned versions (`hk check --all; echo $?` prints 0)
- [x] 3.6 Delete the scratch clone (`test ! -e <clone>`)
- [x] 3.7 Propose commit `fix(git:hooks): install the secret scan as a shim every git runs` (`git show --stat HEAD` lists only `mise.toml` and `AGENTS.md`)

## 4. Signal

- [ ] 4.1 Add the outcome to darse's record `darse:T-065` (second finding) if still open: the measured table, and that `hk install --legacy` closes the gap for cem and darse too; otherwise record the signal in the change map row 20 (`rg -n 'T-065' docs/audits/2026-10-30-environment.md` or the record shows it)
- [ ] 4.2 Add to `openspec/changes/rationalize-package-ownership/` (proposal or design) that brew's git stays (soft-serve, `HOMEBREW_GIT`) and that `conda:git` is the only mise source (`rg -n 'conda:git' openspec/changes/rationalize-package-ownership/`)
- [ ] 4.3 Propose commit `docs(chezmoi:spec): record the hook fix for the fleet and package ownership` (`git show --stat HEAD`)

## 5. Close

- [ ] 5.1 `openspec validate enforce-hook-with-system-git --strict`; `/opsx-verify enforce-hook-with-system-git`
- [ ] 5.2 Archive (`openspec archive enforce-hook-with-system-git --yes`; `openspec list | grep -c enforce-hook-with-system-git` prints 0); mark row 20 of the change map done and archived, no cem checklist line to tick

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
