# Brief: build the change add-agent-env-wrapper

Written by the orchestrator agent of this repository, for the agent that leads this change (suggested name `chezmoi-env-lead`).
This file is an operational complement to the change, not a replacement: the proposal, design, spec and tasks are the contract, this file says how to work.

## Where you work

- Repository: this one, in a worktree under `~/Work/trees/` (the directory is `dotfiles-agent-env-wrapper`: the prefix comes from the repository name, not from the checkout), on branch `fix/agent-env-wrapper`, started from `main`.
  The orchestrator creates the worktree and your herdr tab; if you find yourself in the main checkout, stop and say so.
- Your tab sits in the herdr workspace of this repository, next to the tabs of the user and of the orchestrator: do not close, rename or type into a tab you did not open.
- You start in plan mode on a short review, then the user switches you to build mode.
  The read-only guard may ask for approval on commands it does not know yet; the user answers in your pane.
- Everything chezmoi reads lives under `home/` (`.chezmoiroot`).
- Your own process was started before the change exists, so it holds the secret-named variables of the user's shell, like every agent before this change: never print the environment, `chezmoi data`, `chezmoi dump-config` or any listing that could carry a value, and when you need a fact about a variable, count (`grep -c`) or compare by hash in memory.
  The revoked GitHub variable is inherited too: if `gh` or `git` fails with a 401, run it with `env -u GITHUB_TOKEN` in front (its name is the public convention of GitHub); you never push.

## Read first, in this order

1. `AGENTS.md` (safety rules, writing for a public repository, the secret and zsh rules added on 2026-11-16, conventions).
2. `openspec/changes/add-agent-env-wrapper/` (proposal, design, `specs/agent-environment/spec.md`, tasks) and `openspec list`.
3. The three backlog entries on secrets in `TODO.md` ("Follow-ups from changes"): they say what this change is not.
4. `home/dot_config/shell/shellrc` and `home/dot_config/shell/rc.d/010-env_user.sh` (where the variables enter the shell and where an inherited copy is dropped).
5. After reading, say in a few lines what in the proposal, design, spec or tasks no longer matches the tree, if anything.

## What to do

1. Plan mode: review the change against the current tree.
   - The design records measurements of 2026-11-15 and 2026-11-16 (zsh and bash leave 0 matching names in the child; the real opencode starts with them stripped; herdr types the bare command into the pane shell; the name computation costs about 6 ms): re-run the two cheapest ones (the 0 count in both shells, and `env -u` on the real binary with `--version`) before you rely on them, with counts only.
   - Report what is stale, and one line on whether the spec scenarios are all checkable by a command.
   - Do not edit anything until the user switches you to build mode.
2. Build mode: `/opsx-apply add-agent-env-wrapper`, task by task.
   Tasks 1 to 4 write one source file, the test driver in `/tmp/opencode/agent-env/` (outside the repository) and one `AGENTS.md` line.
3. Task 5.1, the single-target deployment: the user approved it on 2026-11-16 once the tests of task 3 pass (`chezmoi -S <worktree> apply --exclude=scripts ~/.config/shell/rc.d/445-tools_opencode.sh`, nothing else).
   Say in your pane that you are about to run it, and run only that command.
4. Task 5.3, the live check: it creates a tab in the user's workspace and starts a probe agent in it.
   - Start nothing that sends a prompt, count only (`grep -Ec` on `/proc/<pid>/environ`, the pid from `herdr pane process-info`), and close the probe tab by its id when done, not the workspace.
   - It runs after 5.1: a new shell started by herdr sources the deployed function.
5. Verify (`/opsx-verify`), then archive (`openspec archive add-agent-env-wrapper --yes`) on the user's go; show the `AGENTS.md` wording in your pane before you write it.
6. Rebase on `main`, run `openspec validate --all --strict`, and report with the last commit hash; the orchestrator fast-forwards `main`.
   You never merge and never push.

## chezmoi in a worktree

- This worktree is not chezmoi's default source: every chezmoi command takes `-S <worktree>`; check first that `chezmoi -S <worktree> source-path` prints `<worktree>/home`.
- chezmoi comes from brew: if a shell lacks it, run `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` first.
- Never run a full `chezmoi apply`, never `chezmoi init`; the only target you deploy is the one of step 3.

## Non-goals

- Stopping the export of the secrets in login shells, cleaning the systemd user manager, restarting herdr, kitty or any other agent: the backlog study owns them, and they are the user's to restart.
- Whether agents may run key-reading command-line clients: parked, depends on the agent-harness decision, out of this change; those clients are not allowed in agent sessions meanwhile.
- Other agents (`codex`, `pi`, `goose`), a plugin or guard that redacts output, a name list: the function computes names at each call and carries no list.
- Any edit to another repository or to the private store.

## Rules

- Public repository: no secret values, no private hosts or IP addresses, no employer or client details, no private repository names.
  Names of secret variables: only publicly well-known ones (a provider's documented convention), never a name specific to this workstation; the tests use `DEMO_` names only, so they depend on no real name.
  Name only darse, cem, bosco, greffe and the Neovim configuration repository; call any other "a fleet repository".
- Markdown: one sentence per line, no em or en dashes, no emoji, sentence-case headings, the vim modeline as the last line.
- Shell: POSIX-compatible where bash and zsh both source the file; the function must work in both, and the tests run both.
  An agent's shell is zsh: see the four habits in `AGENTS.md` before you write a command.
- Commits: propose the message first (`type(domain:subject): imperative lowercase summary`, English, subject at most 80 characters), commit only after the user validates it, with `/home/linuxbrew/.linuxbrew/bin/git commit` so the hook output is visible.
  Never push.
- Anything that uses sudo, writes outside `$HOME`, installs, uninstalls or deletes needs the user's explicit go.
- Edit the source, never the target, for managed files.

## Reporting

- Report with one short line each time, at five points: reading done, review ready, apply done, verify result, blocked (say on what).
  Send it with `herdr agent prompt chezmoi-orch "<one line>"` when `herdr agent get chezmoi-orch` succeeds.
  Agent names can be lost when herdr restarts (see `openspec/changes/add-agent-launch-tasks/observations.md`): when that fails, find the pane of the tab labelled `orch` in the workspace of this repository (`herdr tab list --workspace <id>`, then `herdr agent list`, field selection with `jq`, never an unfiltered listing) and prompt it by pane id, checking the tab label before you rely on it.
  `herdr agent prompt` refuses a blocked agent: when the orchestrator waits for the user, write the line in your own pane as well.
- Keep a list of every friction you meet with the tooling (a lost or duplicated prompt, a slow start, a guard prompt that blocked work, a path or trust problem in the worktree, a command that behaved differently from its help); send it with the last report.
- When a command or diagnostic of yours makes a private value inferable in your transcript, say so in the report, so that the export of your session is masked before it is committed.
- Your session export is done at the end, when the user asks, following `memory/sessions/README.md`.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
