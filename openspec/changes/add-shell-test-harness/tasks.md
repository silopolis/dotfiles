## 1. Proposal and process files

- [x] 1.1 Proposal, design, specs and tasks written, the brief copied into the change folder (`openspec validate add-shell-test-harness --strict`, `test -f openspec/changes/add-shell-test-harness/brief.md`)
- [x] 1.2 Row 29 in the audit's change map and a sub-item in the planned order of `TODO.md` (`rg -n 'add-shell-test-harness' docs/audits/2026-10-30-environment.md TODO.md`)
- [x] 1.3 `openspec validate --all --strict`, then propose the commit message `docs(chezmoi:spec): propose a bats test harness for the shell code` and wait for the user's validation (`openspec validate --all --strict`)

## 2. Tools and pins (with the user's go, once)

- [x] 2.1 Say in the pane what will be installed and downloaded (`mise install aqua:bats-core/bats-core`, `mise run test:deps`), and wait for the go (the user's answer in the pane)
- [x] 2.2 `mise.toml`: the pin `"aqua:bats-core/bats-core" = "1.14.0"` and the four tasks `test`, `test:live`, `test:deps`, `test:mutants` (`mise tasks ls | rg -c '^test'` prints 4)
- [x] 2.3 `.gitignore`: `tests/.lib/` and `tests/.reports/` (`git check-ignore tests/.lib tests/.reports` prints both)
- [x] 2.4 `mise install aqua:bats-core/bats-core` (`mise exec -- bats --version` prints `Bats 1.14.0`); the short name `bats` installs a second copy under `installs/bats`
- [x] 2.5 `tests/deps.txt` with the three libraries, their tags and commits, and `tests/deps.sh`: anonymous shallow clone under `env -i` with a scratch home, commit check, move into place, no network when already at the pin (`mise run test:deps && for d in tests/.lib/*; do git -C $d rev-parse HEAD; done`)
- [x] 2.6 The strict pin fails as specified: a wrong commit in a scratch copy, an offline run with `tests/.lib` removed, an offline run with the libraries present (`https_proxy=http://127.0.0.1:9 mise run test:deps` exits 0 when present and non-zero with a library named when absent; the scratch copy exits non-zero with both commits in its message)

## 3. Runner, helpers and the harness's own tests

- [x] 3.1 `tests/helpers/common.sh`, `scratch.sh`, `synth.sh`: repository root and `DOTFILES_TEST_SOURCE`, tool lookup, GNU time resolver, `env -i` runner, pseudo-terminal runner, names and canaries built from parts, the name that `010-env_user.sh` unsets read from the file (`bash -n tests/helpers/*.sh && shellcheck -s bash tests/helpers/*.sh`)
- [x] 3.2 `tests/helpers/bats/load.bash` and `setup_suite.bash`: library loading, `require_tool`, `require_shell`, `require_live`, each a skip that names what is missing (`bats --count tests/unit/harness.bats` prints a number above 0 once 3.4 is done)
- [x] 3.3 `tests/run.sh`: scratch home, `PARALLEL=--will-cite` for the one process, secret-named variables removed from the bats process, `--jobs` (serial for a live run or without GNU parallel, a `jobs: <n>` line), JUnit report into `tests/.reports/`, canary scan of the report and the output, run from any directory (`cd / && /path/to/tests/run.sh` prints the same counts as from the root)
- [x] 3.4 `tests/unit/harness.bats`, the port of the old self-test: a stub logs and answers from a fixture, `sudo` logs and does not elevate, a live-mode call outside the allow-list is refused and logged, isolated mode refuses a real directory, `env -i` hides a synthetic secret-named variable, the leaked-canary check fails a run on a scratch copy (`bats tests/unit/harness.bats` passes)
- [x] 3.5 The skip for a missing tool, a missing library at load and a missing shell build (`PATH` without `shellcheck` gives a `<skipped` that names it; a missing library fails the file)

## 4. Port the wrapper suite (first: the pattern for the others)

- [x] 4.1 `tests/unit/agent-env.bats`: the 13 per-shell checks in zsh, system bash and Homebrew bash, registered per shell with `bats_test_function` and named `zsh ...`, `bash ...`, `brewbash ...`; the synthetic set and stub built at run time; the canary scan (`bats --count --filter '^(zsh|bash|brewbash) ' tests/unit/agent-env.bats` prints 39)
- [x] 4.2 The scenarios the driver did not cover: `bash -n` and `zsh -n`, no secret-like name in the file, the documentation line in `AGENTS.md`, an interactive zsh on the scratch render defines the function in `tests/smoke/` (`bats tests/unit/agent-env.bats tests/smoke/agent-env-interactive.bats` passes)
- [x] 4.3 `tests/smoke/agent-env-live.bats`: the deployed target equals the source, the lowercase-name count, the names of the user's environment file against the source (counts only) (`DOTFILES_TEST_LIVE=1 bats tests/smoke/agent-env-live.bats` passes, `bats tests/smoke/agent-env-live.bats` reports 3 skipped)
- [x] 4.4 The broken copy: `tests/mutants/wrapper/broken.sh` and its entry in `tests/mutants/README.md` (a run against it reports exactly 9 failures, 3 per shell)
- [x] 4.5 Compare with the old driver: 39 passes in the same three shells on the same code, and the same 9 failures on the broken copy (`tests/run.sh` prints the counts, `DOTFILES_TEST_SOURCE=<scratch copy with the broken file> bats tests/unit/agent-env.bats` prints 9 failures)

## 5. Port the shell startup suite

- [x] 5.1 `tests/helpers/render.sh`: generated configuration with synthetic data and the `[env]` table copied from the template, stub `aqua`, empty destination of mode 0750 with `.config`, restricted apply, render of a git ref with `git archive`; the launcher fixture (`bash -n tests/helpers/render.sh && shellcheck -s bash tests/helpers/render.sh`)
- [x] 5.2 Rebuild the two state snippets that were not staged (`snip/zsh-state.zsh`, `snip/bash-state.bash`) from the session export, as helpers that print names only (`dt_list_names`, `dt_list_login_names` and `dt_list_desktop` of `tests/helpers/compare.sh`, and the snippets of the behaviour tests) (`rg -c 'zsh-state|bash-state' memory/sessions/202611161513-fast_correct_shell_startup.md` shows the source)
- [x] 5.3 `tests/unit/completion-cache.bats`: the 17 checks of the cache helper in zsh and in bash, with synthetic tools (`bats --count tests/unit/completion-cache.bats` prints 34 or more)
- [x] 5.4 `tests/unit/aliases.bats`: the 9 checks of the alias fixes in zsh and in bash with stub tools and a scratch source path, and shellcheck at error level on the aliases file (`bats --count tests/unit/aliases.bats` prints 19 or more)
- [x] 5.5 `tests/smoke/startup-silent.bats` (9) and `startup-single.bats` (7): bytes and passes of `rc.d` under a pseudo-terminal and without one, the debug line on standard error only, the dump header stable over alternating starts (`bats --count tests/smoke/startup-silent.bats tests/smoke/startup-single.bats` prints 17: the silent file holds the nine byte counts and the debug scenario, 10 tests)
- [x] 5.6 `tests/smoke/startup-behaviour.bats` (15 invariants) and `startup-cache.bats` (8, stub tools): the private environment and the unset name, the `opencode` function, the desktop replay, login `PATH`, `fpath`, registrations, the bare-terminal bash login, the repository's aliases and functions (`bats --count tests/smoke/startup-behaviour.bats tests/smoke/startup-cache.bats` prints 23)
- [x] 5.7 `tests/smoke/startup-compare.bats`: the five comparisons against `DOTFILES_TEST_BASE_REF` with `DOTFILES_TEST_BASE_ALLOW` (`DOTFILES_TEST_BASE_REF=HEAD bats tests/smoke/startup-compare.bats` passes, and without the variable it reports 5 skipped that name it)
- [x] 5.8 `tests/smoke/startup-live.bats`: the two timing thresholds (medians of at least 7 alternating rounds under a pseudo-terminal, GNU time by path or `date`) and the cache with real tools in two shells (`DOTFILES_TEST_LIVE=1 bats tests/smoke/startup-live.bats` passes)
- [x] 5.9 Mutants of the startup suite: cache keyed on the name only, a generator that prints, `profile` sourcing `rc.d` twice; the expected counts written to `tests/mutants/README.md` (each mutant makes at least its expected number of tests fail)
- [x] 5.10 Compare with the old inventory: unit 53, smoke 40 (the inventory said 39: the debug scenario is a test of its own), compare 5, live 4 (`bats --count` for the startup files adds up to 102)

## 6. Port the install scripts suite

- [x] 6.1 `tests/helpers/harness.sh` and `tests/helpers/stub`: isolated and live read-only modes ported from `run.sh` and the stub, curated utility directory built from `command -v` of the base utilities, no hard-coded path, the environment table from the generated configuration, the real home only when the mode is live (`bash -n tests/helpers/harness.sh tests/helpers/stub && shellcheck -s bash tests/helpers/harness.sh tests/helpers/stub`)
- [x] 6.2 `tests/helpers/fixtures.sh` and `tests/fixtures/`: stub tool responders with state in the scratch home, package lists generated from `home/dot_config/pipx/packages.json`, `home/.chezmoidata/*.yaml` and the mise config, `.vsix` archives built with `python3`; none over 4 KiB, none copied from a real listing (`find tests/fixtures -type f -size +4k` prints nothing); the renders and the data come from `tests/helpers/scripts.sh`, the fixtures from `tests/helpers/script-fixtures.sh`, and the pipx spec file is linked into the scratch home, never copied
- [x] 6.3 `tests/unit/install-scripts-isolated.bats`: the 61 isolated runs, in groups per script (prerequisites, limits, decrypt, brew, mise, pipx, krew, vim, bat, VSCodium), and the 17 call counts and 4 second runs (`bats --count tests/unit/install-scripts-isolated.bats` prints 85: the 61 isolated runs, the 17 call counts, the 4 second runs and the 3 tests of 6.4)
- [x] 6.4 The brew completions block: linked (no link call), not linked (one call), dry run (a `would run` line), the three tests the old suite lacked (`bats --filter 'completions' tests/unit/install-scripts-isolated.bats` passes with 3 tests)
- [x] 6.5 `tests/unit/install-scripts-render.bats`: the 31 render checks (tool-presence flips, `PATH` independence, bat inputs, the directory list, the helper, the trigger matrix, the Debian guard, the krew lists, no literal path, no escaped action), with the two `init-*` skipping when `hostnamectl` or `lscpu` is absent (`bats --count tests/unit/install-scripts-render.bats` prints 31 or more)
- [x] 6.6 `tests/unit/install-scripts-static.bats`: `bash -n` and `shellcheck -s bash` on the non-empty rendered scripts, two renders (`bats --count tests/unit/install-scripts-static.bats` prints 20, one per non-empty script and render, or the figure the render gives, recorded in the pane)
- [x] 6.7 `tests/smoke/mise-reshim.bats`: the 7 checks of the shim cleanup with the real `mise` binary in scratch directories, offline (`bats tests/smoke/mise-reshim.bats` passes, and it skips naming `mise` when absent)
- [x] 6.8 `tests/smoke/install-scripts-live.bats`: the ten live runs, the live call count, the bat scratch build, the vimrc, `mise install --dry-run-code`, the reshim preview; refused and `sudo` logs empty (`DOTFILES_TEST_LIVE=1 bats tests/smoke/install-scripts-live.bats` passes, 15 tests)
- [x] 6.9 Mutants of the install scripts: `run()` ignoring the dry-run variable, `need()` always succeeding, the limits script writing a lower value; counts in `tests/mutants/README.md` (each mutant makes at least its expected number of tests fail)
- [x] 6.10 Compare with the old suite: 155 checks plus 3 (`bats --count` over the install-scripts files adds up to 158: 85 + 31 + 20 + 7 + 15; every old case name appears in a test name, but `bat-live-scratch`, `vimrc-no-N` and `mise-pending`, which are the tests named `live ...` of the live file, and the README maps them)

## 7. The whole suite

- [ ] 7.1 `mise run test` in zsh and in bash, serial and with `--jobs` (the numbers of tests, failures and skips are equal in the two modes, and `tests/.reports/report.xml` parses)
- [ ] 7.2 `mise run test:live` (exit 0, `jobs: 1`, the home listing hash equal before and after, the sudo and refused logs empty)
- [ ] 7.3 `mise run test:mutants` (exit 0, `git status --porcelain` unchanged)
- [ ] 7.4 The real home is left alone and no `~/.parallel` appears (`ls -lR --time-style=full-iso ~/.config/shell ~/.config/chezmoi | sha256sum` before and after, `test -e ~/.parallel; echo $?`)
- [ ] 7.5 A missing tool and a missing second bash skip, with the message (`env PATH=<without shellcheck> tests/run.sh` exits 0 with a `<skipped` that names it)

## 8. Review the new files before each commit

- [ ] 8.1 The redaction tool, public profile, on the new files, counts only (`python3 ~/.config/nvim/scripts/session_redact.py --profile public --check <files>` prints 0 for every count)
- [ ] 8.2 The secret scanner on the tests (`gitleaks dir tests` exits 0)
- [ ] 8.3 No literal secret-looking name, no home path, no user name, no host, no private repository name (`rg -n -e 'DEMO_[A-Z_]*(KEY|TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL)' -e '/home/[a-z]+/' -e 'linuxbrew' tests` prints nothing)
- [ ] 8.4 Plain helpers hold no bats (`rg -n -e '^@test' -e '\bbats_' -e '\bload\b' -e 'BATS_' tests/helpers/*.sh tests/run.sh tests/deps.sh` prints nothing)

## 9. Documents

- [ ] 9.1 `tests/README.md`: the three levels as `###` headings, the isolated and live read-only modes, the four variables, the commands, the classification of `tests/global-mise-tasks/` and `tests/machine/`, the scenario table (`rg -c '^### (Unit|Smoke|E2E)' tests/README.md` prints 3, and the table rows equal `rg -c '^#### Scenario' openspec/specs/agent-environment/spec.md openspec/specs/shell-startup/spec.md openspec/specs/install-scripts/spec.md` summed)
- [ ] 9.2 `tests/mutants/README.md`: each mutant, the file it changes, the expected count (`test -f tests/mutants/README.md`)
- [ ] 9.3 Show the `AGENTS.md` wording of the design in the pane, then replace the bullet and its three sub-bullets after the user's go (`rg -n 'kept outside the repository' AGENTS.md` prints nothing, `rg -n 'mise run test' AGENTS.md` prints the line)

## 10. Close

- [ ] 10.1 `openspec validate add-shell-test-harness --strict` and `openspec validate --all --strict`; `/opsx-verify add-shell-test-harness` (both commands print `valid`)
- [ ] 10.2 Verify how `openspec archive` treats text outside requirement blocks on a scratch copy of the repository, before the real archive (`openspec archive add-shell-test-harness --yes` in the scratch copy, then `rg -n '^## Purpose|^In the scenarios below' <scratch>/openspec/specs/shell-test-harness/spec.md`)
- [ ] 10.3 Archive on the user's go (`openspec archive add-shell-test-harness --yes`), then check the merged specs: `shell-test-harness` keeps a Purpose and its preamble, no modeline sits inside a requirement, and the `agent-environment` preamble is edited by hand and no longer names the old scratch path (`rg -n '/tmp/opencode' openspec/specs/agent-environment/spec.md openspec/specs/shell-startup/spec.md openspec/specs/install-scripts/spec.md` prints nothing)
- [ ] 10.4 Tick the item in `TODO.md`; no cem checklist line names this change (`rg -n 'add-shell-test-harness' TODO.md`)
- [ ] 10.5 Rebase on `main`, `openspec validate --all --strict`, report with the last commit hash and the list of frictions (`git log -1 --format=%h`)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
