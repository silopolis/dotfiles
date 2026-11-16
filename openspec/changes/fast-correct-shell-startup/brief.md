# Brief: build the silent and fast part of fast-correct-shell-startup

Written by the orchestrator agent of this repository, for the agent that leads this work (suggested name `chezmoi-startup-lead`).
The change folder is the contract; this file says how to work and which part of the change is yours.
The change was drafted on 2026-10-30, before several things moved (see "What changed since the draft"), so part of your job in plan mode is to bring it up to date.

## Where you work

- Repository: this one, in a worktree under `~/Work/trees/` on branch `fix/fast-correct-shell-startup`, started from `main`.
  The orchestrator creates the worktree and your herdr tab and gives you the exact path in the first message; if you find yourself in the main checkout, stop and say so.
- Your tab sits in the herdr workspace of this repository, next to the tabs of the user and of the orchestrator: do not close, rename or type into a tab you did not open.
- You start in plan mode on a review, then the user switches you to build mode.
  The read-only guard may ask for approval on commands it does not know yet; the user answers in your pane.
- Everything chezmoi reads lives under `home/` (`.chezmoiroot`); the change and the audit use flat paths from before that, so read them with `home/` in front.
- Your process holds none of the secret-named variables (agents started through the `opencode` function are stripped), but a command can still print private values: never print the environment, `chezmoi data`, `chezmoi dump-config` or an unfiltered listing, and use counts or hashes when you need a fact about a variable.

## Your part of the change, and what stays out

The user's request: fix the pollution of interactive shell startup (banners and errors) and its time.

In scope:

- Measure first: baseline timings (interleaved runs, medians) and a `zprof` profile, saved outside the repository (task 1.1).
- A silent startup: no banner on stdout, no error and no notice on stderr, in an interactive zsh and an interactive bash (tasks 2.3 and the spec requirement "Silent startup"; audit F20 and the banner part of F33).
- Startup time: the load order of login shells (task 2.1, audit F06: login shells run `rc.d` twice), cached or lazy completions, `brew completions link` out of startup, one `chezmoi source-path` call, compinit once (tasks 3.1 to 3.5, audit F19 and the compinit part of F33), and the re-measure at the end.
- The `AGENTS.md` Commands line for startup time: it names a GNU `time` that is not installed here; replace it with the method you end up using.

Out of scope, for the user to decide separately:

- Token exposure (task 4.3, F23, the spec requirement "Opt-in token exposure"), the shell umask, the locale (F21), the `PATH` helper (F18), bash login on a bare terminal (F22) and the order of syntax highlighting.
  Token exposure is parked on purpose: it is a backlog study ("Secrets held by the desktop session" in `TODO.md`), and the wrapper change already protects agents.
- Do not change what `rc.d/010-env_user.sh` exports or unsets, the order in which the private environment file is sourced, or `rc.d/445-tools_opencode.sh` (the function that starts opencode without secret-named variables); a speed change may move or cache work around them but must leave their behaviour as it is, and a check of that behaviour belongs in your tests.
- Aliases, the prompt, plugins beyond load order, brew packages.

What to do about the rest of the change: in plan mode, propose how to split it.
The natural cut is to narrow this change to the in-scope tasks and requirements, and to move the out-of-scope tasks and requirements, with their open questions, into a new change that you only propose (proposal and a note of what moves, no design work).
Do not edit anything until the user chooses and switches you to build mode.

## What changed since the draft

- Paths: everything is under `home/` now; line numbers quoted in the audit (aliases, `110-pkg_brew.sh`, `020-env_defaults.sh`) are older than the tree, so find the code again.
- `rc.d/445-tools_opencode.sh` exists (a function; it must keep working in bash and zsh, and its cost at startup is negligible).
- Measured on 2026-11-16: `zsh -i -c exit` takes about 3.0 s, and prints one banner line on stdout and six lines on stderr (two option errors from an `eval`, an unknown-flag error from the infracost completion, and an update notice from infracost); startup time varies by several hundred milliseconds between runs minutes apart, so compare interleaved runs and medians of at least five, and treat the 1.0 s target of the design as a hypothesis to check, not a promise.
- Facts for the tools: there is no GNU `time` on `PATH` (use `date +%s.%N`), the `shellcheck` shim fails with "No version is set" (run it through `mise exec` or say it cannot run), and an interactive startup banner pollutes the stdout of `zsh -i -c`.
- tmux opens login shells (`default-shell`), so the login path matters as much as the interactive one.

## Read first, in this order

1. `AGENTS.md` (safety rules, writing for a public repository, the conventions, the zsh pitfalls).
2. `openspec/changes/fast-correct-shell-startup/` (proposal, design, `specs/shell-startup/spec.md`, tasks) and `openspec list`.
3. The audit section 2.6 (load order) and findings F06, F19, F20 and F33 in `docs/audits/2026-10-30-environment.md`.
4. `home/dot_config/shell/` (`profile`, `shellrc`, `rc.d/*`, `aliases`), `home/dot_config/zsh/`, `home/dot_config/bash/`.
5. The archived change `openspec/changes/archive/2026-11-16-add-agent-env-wrapper/` for the test method (a driver outside the repository, every shell under `env -i`, synthetic data, counts only).
6. After reading, say in a few lines what in the proposal, design, spec or tasks no longer matches the tree.

## What to do

1. Plan mode: the review above, the baseline measurement (read-only, saved outside the repository), a list of what each source of delay costs now, a proposal for the split, and the decisions that you need from the user.
2. Build mode: `/opsx-apply fast-correct-shell-startup` on the part the user chose, task by task.
3. Tests: a driver kept outside the repository (for example under `/tmp/opencode/shell-startup/`), run against a scratch destination before anything is deployed.
   - Render the target into a scratch directory with `chezmoi -S <worktree> apply --destination <scratch> --exclude=scripts,externals,encrypted` after a `--dry-run --verbose` that shows what it would write; check first that it cannot write elsewhere.
   - Start each shell with `env -i` and the scratch directory as `HOME` and `XDG_CONFIG_HOME`, so that the real configuration and the real secrets never enter a test.
     Measured by the orchestrator on 2026-11-16: the dry run writes nothing, the real apply into the scratch writes about 430 files and leaves the real home alone, and the apply prints one warning about the Neovim external, which is harmless.
     Run the shells from the scratch directory, not from a repository: in a first probe `mise` still read the real home's configuration (it resolves it from the account's home directory, not from `HOME`) and printed warnings that the real startup does not print, so point `MISE_CONFIG_DIR`, `MISE_DATA_DIR` and `MISE_CACHE_DIR` into the scratch too, or filter those lines out and say that you did.
   - The checks are counts and exit statuses: bytes on stdout and stderr (`2>&1 | wc -c` prints 0), the order and number of times `rc.d` runs (`SHELL_RC_DEBUG` or a call log), the shell stays usable (an alias and a function still resolve), completion still works for the tools you cached, and the stripped-variable behaviour of the opencode function is unchanged.
4. Deployment: a broken shell startup breaks every new shell of the user, agents included.
   - The user's go is needed at the time, one target at a time, after the tests pass in the scratch destination, and never a full apply.
   - Before a target, say in your pane which one, show `chezmoi -S <worktree> diff --exclude=externals,scripts <target>`, and give the rollback: `chezmoi apply --exclude=scripts <target>` from the main checkout's default source restores the previous content.
   - After a target, open a new interactive shell in a spare herdr tab you create and close by id, and check it before the next target; already running shells are not affected.
5. Verify (`/opsx-verify`), then archive on the user's go, showing any `AGENTS.md` wording in your pane before you write it.
   After the archive, check that the merged spec kept its Purpose and has no stray modeline inside a requirement (the archive has done both before).
6. Rebase on `main`, run `openspec validate --all --strict`, and report with the last commit hash; the orchestrator fast-forwards `main`.
   You never merge and never push.

## chezmoi in a worktree

- This worktree is not chezmoi's default source: every chezmoi command takes `-S <worktree>`; check first that `chezmoi -S <worktree> source-path` prints `<worktree>/home`.
- chezmoi comes from brew: if a shell lacks it, run `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` first.
- Never run a full `chezmoi apply`, never `chezmoi init`.
- Do not run any command that changes brew packages: the brew hook commits the Brewfile by itself after brew changes, in a checkout that is not yours.

## Rules

- Public repository: no secret values, no private hosts or IP addresses, no employer or client details, no private repository names.
  Names of secret variables: only publicly well-known ones (a provider's documented convention), never a name specific to this workstation; tests use `DEMO_` names only.
  Name only darse, cem, bosco, greffe and the Neovim configuration repository; call any other "a fleet repository".
- Markdown: one sentence per line, no em or en dashes, no emoji, sentence-case headings, the vim modeline as the last line.
- Shell: POSIX-compatible where bash and zsh both source the file, shell-specific code in `case "$CURRENT_SHELL"` blocks; an agent's shell is zsh, see the four habits in `AGENTS.md`.
- Commits: propose the message first (`type(domain:subject): imperative lowercase summary`, English, subject at most 80 characters), commit only after the user validates it, with `/home/linuxbrew/.linuxbrew/bin/git commit` so the hook output is visible.
  Never push.
- Anything that uses sudo, writes outside `$HOME`, installs, uninstalls or deletes needs the user's explicit go.
- Edit the source, never the target, for managed files.
- In every herdr listing, select fields with `jq` (name, status, pane id, tab id); an unfiltered listing puts the names and directories of other projects into your transcript.

## Reporting

- Report with one short line each time, at five points: reading done, review ready (with the baseline numbers), a target deployed, verify result, blocked (say on what).
  Send it with `herdr agent prompt chezmoi-orch "<one line>"` when `herdr agent get chezmoi-orch` succeeds.
  Agent names can be lost when herdr restarts: when that fails, find the pane of the tab labelled `orch` in the workspace of this repository (`herdr tab list --workspace <id>`, then `herdr agent list` with `jq`) and prompt it by pane id, checking the tab label before you rely on it.
  `herdr agent prompt` refuses a blocked agent: when the orchestrator waits for the user, write the line in your own pane as well.
- Keep a list of every friction you meet with the tooling, and send it with the last report.
- When a command or diagnostic of yours makes a private value inferable in your transcript, say so in the report, so that the export of your session is masked before it is committed.
- Your session export is done at the end, when the user asks, following `memory/sessions/README.md`.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
