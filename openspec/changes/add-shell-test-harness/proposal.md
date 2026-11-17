## Why

The proof of this repository's shell code is three test harnesses that were built in a scratch directory outside the repository: one for the install scripts (`make-install-scripts-idempotent`, 155 checks), one for the `opencode` wrapper (`add-agent-env-wrapper`, 39 checks in three shells) and one for the shell startup (`fast-correct-shell-startup`).
Nobody else can run them, the next cleanup of the scratch directory would delete them, and they hard-code paths of worktrees that no longer exist.
The startup harness printed values for a render of the previous commit and a render of the working tree, and a person judged the difference by eye: it has no pass or fail.
The install-scripts harness reads the real chezmoi configuration and data, and the startup harness copies a file from the real home.

Several planned changes touch the shell startup or the scripts again (`correct-shell-environment`, `port-omalap-shell-aliases`, `manage-xdg-basics`, `add-machine-smoke-ci`) and need the same proof, with the same strictness, run by anyone with one command.
Source: the user's decision of 2026-11-17 at the end of the `fast-correct-shell-startup` session; the audit's change map (`docs/audits/2026-10-30-environment.md`, section 6, row 29, process) and its sections 2.3 (scripts) and 2.6 (shell startup) describe the code under test.

## What Changes

- **One test suite under `tests/`**, run by bats-core with one command, replacing the three scratch harnesses with the same checks and the same strictness:
  - bats-core 1.14.0 pinned in the repository `mise.toml`, with the helper libraries bats-support, bats-assert and bats-file pinned by tag and by the commit the tag resolves to, fetched by a mise task `test:deps` into a git-ignored directory;
  - levels `unit` (stubs, a scratch home, seconds), `smoke` (real shells on a scratch render, real tools in a sandbox) and `e2e` (defined, with no test yet), and the tests that read the real machine kept in `smoke/*-live.bats`, skipped unless `DOTFILES_TEST_LIVE=1`;
  - every test under `env -i` with a scratch home, `sudo` always a logging stub, and no test that applies, installs, uninstalls or writes outside its scratch directory;
  - shared setup written as plain shell scripts in `tests/helpers/`, with the bats glue apart, so that another runner can reuse them later;
  - a JUnit report from bats's own formatter in a git-ignored directory, scanned for canary values after each run;
  - synthetic fixtures built at run time: names, canaries, package lists and configuration come from helpers, so the committed files hold none of them as literals.
- **Tasks**: `mise run test` (unit and smoke), `mise run test:live`, `mise run test:deps`, and `mise run test:mutants`, which proves that each suite can fail by running it against a deliberately broken copy of the code under test and checking the failure count.
- **Ports**, one suite at a time: the wrapper (39 checks, the broken copy must fail 9), the shell startup (about 100 assertions, turned from printed values into assertions) and the install scripts (155 checks, plus the checks of the brew completions block that the old harness never covered).
  The live probe of `add-agent-env-wrapper` (a herdr tab and a probe agent) stays a manual check.
- **`AGENTS.md`**: the bullet that says the proof of a script is a harness kept outside the repository, with its three sub-bullets, is replaced by a pointer to the suite and the command that runs it; the descriptions of isolated mode and live read-only mode move to `tests/README.md`.
- **Specs**: the new capability `shell-test-harness`; three requirements of `install-scripts` that say "the harness" are reworded to name the suite's modes; the preamble of `agent-environment` says the scenarios run in a scratch directory under the old scratch path, in text that sits outside any requirement, so no delta can reach it: it is edited by hand in the archive commit and declared here.
- **Process files**: a row in the audit's change map and an entry in the planned order of `TODO.md`.

## Capabilities

### New Capabilities

- `shell-test-harness`: how the repository's shell code is tested: the runner and its pins, the levels, the isolation rules, the opt-in tests that read the machine, the reports, the synthetic fixtures, and the proof that a suite can fail.

### Modified Capabilities

- `install-scripts`: the scenarios "Run each script on the provisioned laptop", "Declared value higher than the live one" and "Isolated runs cannot reach real tools" name the isolated and live read-only modes of the suite instead of an unnamed harness; no behaviour of the scripts changes.

## Impact

- New tree `tests/` at the repository root, outside `home/`: never a chezmoi target, no ignore entry.
  It holds the runner, the helpers, the fixtures and the `.bats` files; `tests/.lib/` and `tests/.reports/` are git-ignored (two `.gitignore` lines).
- `mise.toml` gains the `bats` pin and the tasks `test`, `test:live`, `test:deps` and `test:mutants`; `hk.pkl` is untouched.
- `mise install bats` and `mise run test:deps` write under the user's home and download from GitHub: they are the only installs of this change, run once with the user's go.
- Nothing is deployed and no source-state file changes: the code under test is not edited, so the suite proves what is already archived.
- `tests/global-mise-tasks/` (Python `unittest`, planned by `add-secret-tasks`, `add-repo-roadmap`, `add-agent-launch-tasks` and `add-incus-host-setup`) and `tests/machine/` (planned by `add-machine-lifecycle-test-infra`) keep their paths and their own runners; `tests/README.md` classifies them by level and no planned change is edited.
- `add-machine-smoke-ci` (planned) can run the suite later: the one-command entry point and the JUnit report are what it calls; no workflow is added here.
- The timing tests use GNU time when it is found at run time (never a hard-coded path) and `date` otherwise; GNU parallel runs the tests of `--jobs`, with its citation notice silenced for the run only.
- Not covered, on purpose: CI, the live probe of the wrapper, and a fast subset in the pre-commit hook (an open question in the design).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
