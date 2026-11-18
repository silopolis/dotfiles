# Brief: build the change add-shell-test-harness

Written by the orchestrator agent of this repository, for the agent that leads this change (suggested name `chezmoi-tests-lead`).
The change does not exist yet: the decisions below were taken with the user on 2026-11-17 at the end of the `fast-correct-shell-startup` session, and your first jobs are to check them against the tree and to turn them into the change.
This file is the operational complement to the change, not a replacement for it: once the proposal exists, its artifacts are the contract and this file says how to work.
It sits in your worktree's `.state/briefs/add-shell-test-harness/brief.md`, which is git-ignored and is deleted with the worktree: your proposal commit copies it to `openspec/changes/add-shell-test-harness/brief.md`.

## Where you work

- Repository: this one, in a worktree under `~/Work/trees/` on branch `feat/shell-test-harness`, started from `main`.
  The orchestrator creates the worktree and your herdr tab and gives you the exact path in the first message; if you find yourself in the main checkout, stop and say so.
- Your tab sits in the herdr workspace of this repository, next to the tabs of the user and of the orchestrator: do not close, rename or type into a tab you did not open.
- You start in plan mode on a review, then the user switches you to build mode.
  The read-only guard may ask for approval on commands it does not know yet; the user answers in your pane.
- Everything chezmoi reads lives under `home/` (`.chezmoiroot`); `tests/` sits at the repository root, outside it, so it is never a chezmoi target and needs no ignore entry.
- Your process holds none of the secret-named variables (agents started through the `opencode` function are stripped), but a command can still print private values: never print the environment, `chezmoi data`, `chezmoi dump-config` or an unfiltered herdr listing, and use counts or hashes when you need a fact about a variable.

## What the change is

Today the proof of this repository's shell code is three harnesses that were built in `/tmp/opencode`, outside the repository, and would be lost at the next cleanup: nobody else can run them.
The change brings them into the repository as one test suite, under one runner, with the same strictness they had.

Decisions already taken with the user (check them, propose adjustments, do not reopen them without a reason):

1. **Runner**: bats-core 1.14.0 (the latest release on 2026-11-17), installed through mise (`aqua:bats-core/bats-core`) and pinned in the repository `mise.toml`.
2. **Helper libraries**: bats-support, bats-assert and bats-file (latest tags on 2026-11-17: v0.3.0, v2.2.4, v0.4.0), pinned and fetched by a mise task `test:deps` into `tests/.lib`, which is git-ignored.
   Propose how the pin is made strict (tag, and the commit it resolves to, checked after the fetch) and what the task does offline or when GitHub answers 401 (a variable that this machine no longer holds was once sent to `gh`; `mise` uses the keyring login through its `credential_command`).
3. **Layout**: `tests/` by level, with `unit`, `smoke`, `e2e`, `helpers` and `fixtures`.
   Propose the definition of each level (a suggestion: unit uses stubs and a scratch home and runs in seconds; smoke starts real shells on a scratch render or calls real read-only tools; e2e applies into a scratch destination or a disposable machine and is opt-in).
4. **Three suites to port** (sources below, staged for you in `.state/tmp/old-harness/`, see "What exists").
5. **Reports and portability**: JUnit output from bats's own formatter into a git-ignored directory, and the shared setup written as plain shell scripts in `tests/helpers/` (no bats-only logic in them), so that pytest can join later without a rewrite; pytest itself is not added now.
6. **Tools the user just installed through brew**: GNU parallel (for `bats --jobs`) and GNU time.
   - GNU time: `time` is a reserved word in bash and zsh, so call the binary by path, resolved at run time from the brew prefix (`$(brew --prefix gnu-time)/bin/time`, which also exists in brew's `bin`), never as a hard-coded machine path; keep `date +%s.%N` as the fallback when it is absent.
   - GNU parallel prints a citation notice and creates `~/.parallel` on a first run (seen in a scratch home on 2026-11-17): set `PARALLEL=--will-cite` for each run of the suite, never export it from a shell startup file, and run the suite with a scratch home.
   - A test that needs a tool which is absent skips with a message that names it.
7. **`AGENTS.md`**: the bullet that says the proof of a script is a harness kept outside the repository (Commands section, with its three sub-bullets) is replaced; show the new wording in your pane before you write it.
   The descriptions of isolated mode and live read-only mode move to a short `tests/README.md`, and `AGENTS.md` keeps a pointer and the command that runs the suite.
8. **Fixtures are reviewed for private content before any commit** (see "Fixtures").

## What exists to port

All of it is scratch and none of it is in the repository.
The orchestrator copied the scripts (never the output directories) into your worktree, under `.state/tmp/old-harness/{shell-startup,agent-env,scripts-test}/`, so that you read them without a permission prompt; the originals stay in `/tmp/opencode` and are not yours to read or change.
That copy is git-ignored and goes with the worktree: porting means writing the tests into `tests/`, not moving files.

- Shell startup: `.state/tmp/old-harness/shell-startup/` holds a shared `lib.sh`, the checks `t-silent.sh`, `t-single.sh`, `t-behaviour.sh`, `t-cache.sh`, `t-cache-live.sh`, `t-aliases.sh`, `t-timing.sh`, a `unit-body.sh` and a stub opencode; they prove the spec `shell-startup` (silent startup, one `rc.d` pass, cached completions, the behaviour of the secret-handling startup file and of the opencode function kept).
  The directory also holds about 85 MB of rendered copies and outputs: ignore those.
- opencode wrapper: `.state/tmp/old-harness/agent-env/driver.sh` (39 checks in zsh, system bash and brew bash, every shell under `env -i`, synthetic `DEMO_` variables with canary values, counts never names, and a deliberately broken copy that must fail 9 of them), `syn.sh` and a stub binary; they prove the spec `agent-environment`.
  The live probe of that change (a herdr tab, a probe agent, a count by process id) is a manual check, not a test: do not automate it.
- Install scripts: `.state/tmp/old-harness/scripts-test/` holds `run.sh` (one rendered script under the harness, isolated or live), `stub`, `render.sh`, `all.sh` (about 550 lines, 155 checks), a `fix/` tree of about 120 fixture files, `selftest/` and two reshim helpers; they prove the spec `install-scripts`.
  - Isolated mode puts logging stubs for `sudo`, `apt-get`, `brew`, `pipx`, `mise`, `kubectl`, `codium` and the other tools first on `PATH` with a scratch `HOME` and standard input from `/dev/null`, so a script can only call stubs; live read-only mode lets an allow-list of read-only queries reach the real tools, refuses and logs everything else, and keeps `sudo` a logging stub; a script passes when it exits 0 and both logs are empty.
  - It hard-codes `/tmp/opencode/scripts-test` and the path of a worktree that no longer exists: those are the first things that must become relative to the repository (the staged copy keeps them as they were).
- Before porting, list which of these checks depend on this machine (installed tool versions, the real home, the brew prefix) and say which of them belong in smoke or e2e and which in unit.

## Fixtures

The repository is public and a fixture is a file that stays in its history for good.

- Prefer synthetic fixtures built by a helper at run time (a scratch `HOME`, generated package lists, `DEMO_` variables, canary values built in memory) over copied files.
- Do not copy a real `chezmoi dump`, `chezmoi managed`, `brew` or `pipx` listing, an installed-extension list, a rendered `.chezmoi.toml`, a shell history, or anything under the old `out/` directories (they hold copies of real outputs).
- Before each commit that adds a fixture or a test: run the redaction tool over the new files (`python3 ~/.config/nvim/scripts/session_redact.py --check <files>`, counts only, public profile; it reads files, not directories), `gitleaks dir` on `tests/`, and scans for home paths, host names, addresses and the names of sibling repositories other than darse, cem, bosco, greffe and the Neovim configuration repository; show the counts in your pane.
- A canary value must not look like a key: in an earlier change the commit hook flagged a synthetic canary.
  If it happens again, change the shape of the canary or build it at run time; do not edit `.gitleaks.toml` or add an allow-list entry without asking the user.

## Safety rules for the tests themselves

- A test never touches the real home, the real chezmoi state or the real destination: each runs under `env -i` with a scratch home from `BATS_TEST_TMPDIR`, and `chezmoi apply` only targets a scratch destination created by chezmoi itself (a pre-created directory with another mode than 0750 made it fail before).
- No test applies, installs, uninstalls or calls `sudo`: `sudo` is always a logging stub, and `CHEZMOI_SCRIPTS_DRY_RUN` is never set on a real `chezmoi apply`.
- The tests that read the real machine (live read-only mode, the real startup timing, the real completion cache) are opt-in through an environment variable named in `tests/README.md`, only read, and skip by default.
- The tests print counts, statuses and test names, never the name or the value of a real variable.
- Do not change brew packages (the brew hook commits the Brewfile by itself, in a checkout that is not yours), and do not touch `hk.pkl`: whether a fast subset runs in the pre-commit hook is a question for the user, to put in the design as an open question.

## Overlaps to settle in plan mode

- `add-secret-tasks` (planned, not built) puts Python `unittest` tests under `tests/global-mise-tasks/`, and `add-machine-lifecycle-test-infra` (planned, not built) puts a machine harness under `tests/machine/`.
  Say where those paths sit in the new layout and which level each belongs to; do not move or edit those changes, and ask the user if the layout needs them to change.
- `add-machine-smoke-ci` (planned) would run the suite in CI: leave CI out, and keep the JUnit output and the one-command entry point easy for it to call.

## Read first, in this order

1. `AGENTS.md` (safety rules, writing for a public repository, the conventions, the zsh pitfalls).
2. The three archived changes that produced the suites: `openspec/changes/archive/2026-11-12-make-install-scripts-idempotent/` (design, tasks, spec `install-scripts`), `openspec/changes/archive/2026-11-16-add-agent-env-wrapper/` (spec `agent-environment`) and `openspec/changes/archive/2026-11-16-fast-correct-shell-startup/` (spec `shell-startup`), and the three main specs under `openspec/specs/`.
3. The three harnesses above, to see what each check proves.
4. `mise.toml`, `hk.pkl`, `.gitignore` at the root, and `openspec list` (the planned changes named above).
5. The bats-core documentation for 1.14 (usage of `--report-formatter junit`, `--jobs`, `load`, `setup_file`), through `webfetch`, and the README of each helper library at the pinned tag.
6. After reading, say in a few lines what in these decisions does not hold against the tree.

## What to do

1. Plan mode: the review above; an inventory of the checks of the three suites with the level each belongs to and the ones that cannot be portable; the proposal for the layout and the helper split; the decisions you need from the user.
   Edit nothing tracked; the baseline outputs you need go in `.state/tmp/` (mode 0700, git-ignored).
2. Build mode, step 1, the change: `/opsx-propose add-shell-test-harness` with the decisions above as input, one capability per suite or one `shell-test-harness` capability, your choice.
   Add the audit change map row (the next free number, after 28) and the `TODO.md` planned-order entry, copy this brief into the change folder, validate (`openspec validate --all --strict`), and propose the commit; the user reads the proposal before you apply it.
3. Build mode, step 2, `/opsx-apply add-shell-test-harness`, task by task.
   - First install the tools: `mise install bats` and `mise run test:deps` write under the user's home and download from GitHub, so say in your pane what you will run and wait for the user's go once; they are the only installs you make.
   - Port one suite at a time, in this order: the opencode wrapper (smallest, the pattern for the others), the shell startup, the install scripts.
   - For each suite show that the ported tests can fail: keep the deliberately broken copy for the wrapper suite, and a mutation of the code under test for the other two; a suite that cannot fail is not a proof.
   - Run the whole suite in zsh and in bash where the code under test runs in both, with `--jobs` once the tests are independent, and compare the counts with the old harnesses (39, the startup checks, 155).
4. Verify (`/opsx-verify`), then archive on the user's go; after the archive check that the merged spec kept its Purpose and has no stray modeline inside a requirement (the archive has done both before).
5. Rebase on `main`, run `openspec validate --all --strict`, and report with the last commit hash; the orchestrator fast-forwards `main`.
   You never merge and never push.

## chezmoi in a worktree

- This worktree is not chezmoi's default source: every chezmoi command takes `-S <worktree>`; check first that `chezmoi -S <worktree> source-path` prints `<worktree>/home`.
- chezmoi comes from brew: if a shell lacks it, run `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` first.
- Never run a full `chezmoi apply`, never `chezmoi init`; this change deploys nothing, because `tests/` is repository tooling.

## Rules

- Public repository: no secret values, no private hosts or IP addresses, no employer or client details, no private repository names.
  Names of secret variables: only publicly well-known ones (a provider's documented convention), never a name specific to this workstation; tests use `DEMO_` names only.
  Name only darse, cem, bosco, greffe and the Neovim configuration repository; call any other "a fleet repository".
- Markdown: one sentence per line, no em or en dashes, no emoji, sentence-case headings, the vim modeline as the last line.
- Shell: tests are bash because bats is; the code under test keeps its own rule (POSIX-compatible where bash and zsh both source it).
  An agent's shell is zsh: see the four habits in `AGENTS.md`, and the zsh habits that bit earlier leads (`2>&1 >/dev/null | next` also pipes standard output, `print '--- x'` reads an option).
- Commits: propose the message first (`type(domain:subject): imperative lowercase summary`, English, subject at most 80 characters; domain `test` or `chezmoi:spec` and `chezmoi:docs` for the process files), commit only after the user validates it, with `/home/linuxbrew/.linuxbrew/bin/git commit` so the hook output is visible.
  Never push.
- Anything that uses sudo, writes outside `$HOME`, installs, uninstalls or deletes needs the user's explicit go.
- Your scratch and logs go in `.state/tmp/` of your worktree, not in `/tmp/opencode`; `.state/journal.md` is the orchestrator's, do not write to it.
- In every herdr listing, select fields with `jq` (name, status, pane id, tab id); herdr JSON nests agent fields under `.result.agent`, tab fields under `.result.tab`, and `herdr pane read` output is not JSON.

## Reporting

- Report with one short line each time, at five points: reading done, review ready (with the inventory counts), a suite ported (with its counts against the old harness), verify result, blocked (say on what).
  Send it with `herdr agent prompt chezmoi-orch "<one line>"` when `herdr agent get chezmoi-orch` succeeds.
  Agent names can be lost when herdr restarts: when that fails, find the pane of the tab labelled `orch` in the workspace of this repository (`herdr tab list --workspace <id>`, then `herdr agent list` with `jq`) and prompt it by pane id, checking the tab label before you rely on it.
  `herdr agent prompt` refuses a blocked agent: when the orchestrator waits for the user, write the line in your own pane as well.
- Keep a list of every friction you meet with the tooling, and send it with the last report.
- When a command or diagnostic of yours makes a private value inferable in your transcript, say so in the report, so that the export of your session is masked before it is committed.
- Your session export is done at the end, when the user asks, following `memory/sessions/README.md`.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
