# Brief: build the change make-install-scripts-idempotent

Written by the orchestrator agent of this repository, for the agent that leads this change (suggested name `chezmoi-scripts-lead`).
This file is an operational complement to the change, not a replacement: the proposal, design and specs are the contract, this file says how to work.

## Where you work

- Repository: this one, in a worktree `~/Work/trees/dotfiles-install-scripts-idempotent`, on branch `fix/install-scripts-idempotent`, started from `main`.
  The orchestrator creates the worktree and your herdr tab; if you find yourself in the main checkout, stop and say so.
- Your tab is in the herdr workspace of this repository, next to the tabs of the user and of the orchestrator: do not close, rename or type into a tab you did not open.
- You start in plan mode.
  Your first output is a review of the change against the current tree, shown in chat; the user reads it and switches you to build mode once approved.
  The read-only guard asks for approval on commands it does not know yet; that is expected, the user answers in your pane.
- Everything chezmoi reads lives under `home/` (`.chezmoiroot`, spec `source-layout`); the change was written before that move, so its paths and line numbers were stale when this brief was written.
  The first commit of your branch refreshes the change documents against the tree (2026-11-12 review): once it is made, they are current and this note no longer applies to them.
- The change `fix-chezmoi-config-template` is archived since 2026-11-08: the config now holds `umask = 0o027`, `encryption = "age"`, a `features` table and a `nvim` table, and `chezmoi diff` excludes externals.
  Read `openspec/specs/chezmoi-config/spec.md` and `openspec/specs/neovim-config/spec.md` before you touch data or scripts.

## Read first, in this order

1. `AGENTS.md` (safety rules, writing for a public repository, conventions).
2. `openspec/changes/make-install-scripts-idempotent/` (proposal, design, `specs/install-scripts/spec.md`, tasks) and `openspec list`.
3. Audit findings F01, F02, F24 (scripts part) and F27 in `docs/audits/2026-10-30-environment.md`, and the scripts section of that audit.
4. The current scripts in `home/.chezmoiscripts/`, the data in `home/.chezmoidata/packages.yaml`, the templates in `home/.chezmoitemplates/`, and `home/dot_config/shell/rc.d/110-pkg_brew.sh` (the brew hook).
5. After reading, summarise in a few lines what each script does today and which statements of the design no longer match the tree.

## What to do

1. Plan mode: review the change against the current tree and report, in chat, a plan.
   - List what is stale or wrong in the proposal, design, specs or tasks (paths, line numbers, script names, data keys), and the edits you propose to the change documents.
   - Answer the two open questions of the design with a recommendation each (Vundle and vim plugins, and the scope of the undeclared-package report); the user decides.
   - Say how each task will be proved without touching the machine (see "Testing the scripts").
   - Do not edit anything until the user switches you to build mode.
2. Build mode: `/opsx-apply make-install-scripts-idempotent`, task by task, proposing one commit per group of tasks as task 5.6 lists.
3. Verify (`/opsx-verify`), then archive (`openspec archive make-install-scripts-idempotent --yes`) on the user's go.
   Archiving also updates the safety rule of `AGENTS.md` (a full apply is allowed after a reviewed dry run): show the new wording in chat and get the user's go before you write it.
4. Rebase on `main` (it moves: the brew hook commits there), run `openspec validate --all --strict`, and report.
   The orchestrator fast-forwards `main`; you never merge.

## Testing the scripts

- The scripts are never run for real in this change: no `chezmoi apply` of any kind without `--exclude=scripts`, and the pending-scripts preview of task 5.4 is a dry run only (`chezmoi -S <worktree> apply --dry-run --verbose`).
- Render a script with `chezmoi -S <worktree> execute-template < <file>`, then run the rendered text under a harness in `/tmp/opencode/scripts-test/` (outside the repository): a `PATH` whose first entry holds stubs for `sudo`, `apt-get`, `brew`, `pipx`, `mise`, `kubectl`, `codium`, `vim`, `gh` and `rustup` that log their arguments and change nothing, `HOME` pointed at a scratch directory, stdin from `/dev/null`, `CHEZMOI_SCRIPTS_DRY_RUN=1` where the design says so.
  A real `sudo`, `apt-get`, `brew install` or `pipx install` on this machine is a stop-and-ask, even for a check.
- `shellcheck -s bash` on every rendered script, `bash -n` on the helper.
- Read-only queries of the real system are fine to decide what a guard should test (`dpkg-query`, `command -v`, `cat /etc/security/limits.d/ulimit.conf`).

## chezmoi in a worktree

- This worktree is not chezmoi's default source: EVERY chezmoi command takes `-S <worktree>` (execute-template, managed, apply, diff, cat, data, dump-config, doctor, state).
  Check first that `chezmoi -S <worktree> source-path` prints `<worktree>/home`.
- chezmoi comes from brew: if a shell lacks it, run `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` first.
- The live config at `~/.config/chezmoi/chezmoi.toml` stays as it is: do not run `chezmoi init` in this change, and never run a full `chezmoi apply`.
- A single-target apply of a non-script target needs `--exclude=scripts` and the user's go.
- Do not print `chezmoi data`, `chezmoi dump-config` or the live config unfiltered: they hold values that must not reach a transcript.
  Select keys with `jq` (`.system`, `.packages`, `.vim`, `.brew`), and say at once if a command printed more than you meant.

## Non-goals

- Changing which packages are declared or which manager owns a tool (`rationalize-package-ownership`), distro and profile data beyond the Debian-family guard (`fresh-machine-bootstrap`), the macOS branches beyond keeping them.
- The supervised full apply: `reconcile-drift-and-supervised-apply` runs it, after this change and after item 15 of the planned order, `test-second-apply-noop`, which is only a planned entry so far and has no change yet.
- Any edit to another repository, and any edit to `TODO.md` beyond what the exceptions below allow: at archive time, tick item 2 of the "Planned order of changes" list (the `make-install-scripts-idempotent` entry).

Exceptions decided by the user on 2026-11-12, after the plan-mode review (the design records them):

- The krew script has one branch per operating system, with a shared list `packages.common.krews` and per-system lists; the darwin `brew bundle` call moves to the darwin branch of the brew script.
- `packages.json` is synchronized with the venvs installed on this machine, in its own commit, so that the undeclared-package report starts empty.
- `TODO.md` entries are called items and not lines (wording only, no reordering, in its own commit), and two backlog entries are added in another commit: the soft open-files limit of the desktop session, and the per-system review of the krew plugins.

## Rules

- Public repository: no secret values, no names of secret variables, no private hosts or IP addresses, no employer or client details, no private repository names.
  Name only darse, cem, bosco, greffe and the Neovim configuration repository; call any other "a fleet repository".
- Markdown: one sentence per line, no em or en dashes, no emoji, sentence-case headings, the vim modeline as the last line.
- Shell: bash with `shellcheck -s bash` clean; no user-specific path in any script (`$HOME`, data keys).
- Commits: propose the message first (`type(domain:subject): imperative lowercase summary`, English, subject at most 80 characters), commit only after the user validates it, with `/home/linuxbrew/.linuxbrew/bin/git commit` so the hook output is visible.
  Never push.
- Anything that uses sudo, writes outside `$HOME`, installs, uninstalls or deletes needs the user's explicit go.
- Edit the source, never the target, for managed files.

## Reporting

- Report with one short line each time, at five points: reading done, plan ready, apply done, verify result, blocked (say on what).
  Send it with `herdr agent prompt chezmoi-orch "<one line>"` when `herdr agent get chezmoi-orch` succeeds.
  Agent names can be lost when herdr restarts (see `openspec/changes/add-agent-launch-tasks/observations.md`), so when that fails, find the pane of the tab labelled `orch` in the workspace of this repository (`herdr tab list --workspace <id>`, then `herdr agent list`; on 2026-11-12 it is pane `wN:p1`) and prompt it by pane id; a pane id written in a brief can go stale, so check the tab label before you rely on it.
  Only when both fail, write the line in your own pane for the user.
- Keep a list of every friction you meet with the tooling (a lost or duplicated prompt, a slow start, a permission prompt that blocked work, a path or trust problem in the worktree, a command that behaved differently from its help); send it with the last report.
- When a command or diagnostic of yours makes a private value inferable in your transcript, say so in the report, so that the export of your session is masked before it is committed.
- Your session export is done at the end, when the user asks, following `memory/sessions/README.md`.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
