# Observations: launching an agent by hand into its own worktree and workspace


Input for the design of `add-agent-launch-tasks`, and for a signal to the fleet's study of multi-agent orchestration.
The first launch is done by hand, on 2026-11-04, for the agent that builds `add-repo-roadmap`: one worktree, one herdr workspace built out of it, one agent in plan mode, one first prompt.
Each step below is logged with its command, its result and any friction, so that the tasks automate what really happened and not what was expected.


## Known before the launch

- herdr 0.9.5 has `herdr worktree list|create|open|remove`.
  `list` gives, for each worktree of a repository, its branch, its path and the workspace open on it.
- No global task creates a workspace; `agent:dispatch` and `scm:worktree:new --tab` need one that exists.
- The Neovim configuration repository runs its sessions as tabs of one workspace and does not use `herdr worktree create`, because it opens a whole workspace.
- The first prompt is lost when sent while the opencode TUI is still blank (about 10 s after `agent start` returns), and a prompt ending in `@file` opens the autocomplete, which takes the Enter.
- The read-only guard asks for approval on every `mise run` in plan mode.


## Questions this launch answers

- Does `herdr worktree open --path <worktree>` create a usable workspace for a worktree that `scm:worktree:new` made, and what label and focus does it give?
- Does the new session start with the project's tracked `.opencode/` commands and skills, and does its dependency directory (not tracked) get installed by itself?
- Is the worktree trusted by mise from its first command, and does the commit hook run there?
- How long does the TUI take to draw in a fresh worktree, and does the first prompt arrive once?
- What does the agent need from the orchestrator that a brief cannot carry?


## Log

<!-- Entries: time, step, command, result, friction. -->

- 2026-11-08, before the launch: agent names are not durable.
  The orchestrator pane was renamed on 2026-11-03 so that briefs could name it as the reporting target.
  By 2026-11-06 herdr listed no agent name at all, and on 2026-11-08 most panes of other workspaces had a name again while the orchestrator pane and the pane of the agent that did the work in between had none.
  The cause is unknown (a restart of the pane, of herdr, or of the agent session are all candidates).
  Consequence: a brief that names a reporting target must say what to do when `herdr agent get <name>` fails; the roadmap brief now does.
  For the design: `agent:launch` should check the name at the end of the launch and report the pane id next to it, so that a caller can message by pane when the name is gone.
- 2026-11-08: `herdr agent prompt <pane-id>` works on an unnamed pane (used to send a request to another agent); a name is not required.
- 2026-11-08, first launch actually done: the lead of `fix-chezmoi-config-template`, not the roadmap agent (still to launch).
  It exercises the same steps, with `herdr worktree create` in place of `scm:worktree:new` plus `herdr worktree open`.

  - Rename: `herdr agent rename wN:p1 chezmoi-orch` took effect at once and `herdr agent get chezmoi-orch` found the pane, so the name lost in the first entry above can be set again by hand.
  - Worktree, first try: `herdr worktree create --workspace wN --branch fix/chezmoi-config-template --base main --path ~/Work/trees/chezmoi-config-template --label chezmoi-config-template --no-focus` failed with `not_git_worktree`.
    The root pane of that workspace reports a working directory outside any repository (a herdr configuration directory), and `--workspace` resolves the repository from it.
    For the design: `agent:launch` passes `--cwd <repository>` and never relies on the workspace's pane.
  - Worktree, second try: the same command with `--cwd <repository>` instead of `--workspace` returned at once with a new workspace labelled as asked (one tab, one root pane in the worktree, not focused) and the branch created from `main`.
    Because the branch is made by herdr, `herdr worktree open` is not needed in this path.
  - mise: the new worktree was already trusted (`mise trust --show`), so no `mise trust` was needed; the reason (a trusted parent path or herdr) was not checked.
    The commit hook is the shared shim in the common git directory (`core.hooksPath` is unset), so it runs in every worktree.
    `.opencode/` holds the tracked `command/` and `skills/`; its `node_modules` is absent, and the session did not need it.
  - Agent: `herdr agent start chezmoi-config-lead --kind opencode --pane <root pane> -- --agent plan --model anthropic/claude-opus-5-5` returned in 3.9 s with the agent idle; the TUI was drawn 9 s later (polled every 3 s).
    The footer showed the plan agent, the requested model and `xhigh` without any variant flag: opencode has no variant option, so the variant comes from state saved by the last use of that model (not checked), and a launch cannot choose it.
  - First prompt: a single paragraph held in a shell variable (here-document), delivered with `--wait --until working` in 0.7 s; no retry, nothing left in the input box.
    Sending it after the TUI was drawn avoided the blank-TUI loss.
  - Blocked after 8 s: the read-only guard asked for approval of the agent's first shell command (`chezmoi -S <worktree> source-path`).
    The cause is the guard's learning phase, not plan mode: its allowlist is still short (1 learned rule on 2026-11-08, hundreds of "always" answers not yet turned into rules), so commands that are read-only but unknown to it, such as `chezmoi` queries, ask each time.
    Until the allowlist grows, a plan-mode launch cannot run unattended; the launch result should report `blocked` as a normal outcome and say that the user has to answer in the new pane.
    Later the same launch should be rechecked, since the prompt count falls as rules are learned.
  - Outcome, about 75 minutes after the first prompt (08:23 to 09:38, with the user answering guard prompts and switching the agent to build): the lead verified the change (19 scenario checks), archived it, rebased its branch on `main` and reported by `herdr agent prompt chezmoi-orch`, so the reporting target set by hand worked.
    Five commits on the branch, none pushed at that point (the lead pushed afterwards, on the user's go, with its own session export); the orchestrator checked the branch (clean tree, fast-forward possible, no added line with the Neovim owner or repository values, gitleaks and `openspec validate --all --strict` clean) and fast-forwarded `main` with `git merge --ff-only`.
  - A side effect no brief can prevent: a worktree-based change that runs `chezmoi init` regenerates the live `~/.config/chezmoi/chezmoi.toml` from the branch template, so until the merge the main checkout sees a config built from a template it does not have.
    The lead said so in its report and named the window; `agent:launch` cannot remove it, but a brief for a change that edits the config template should state it and ask for a quick merge.
  - What the brief could not carry: nothing needed to be added after the first prompt except the answers to guard prompts and the switch to build mode.
    The model switch is not scriptable (no variant option), so the user did it in the pane.
  - A lead's own diagnostics can leak a private name into its transcript even when it prints no value (a generic repository token became inferable).
    A launch brief for a change that handles private values should tell the lead to say so when it happens, as this one did, so the export of that session is masked before it is committed.
- 2026-11-09, cleanup of that launch, and what it shows for `agent:launch`:
  - `herdr worktree create --cwd <repository>` made two workspaces in one call, 7 ms apart (herdr's server log): one labelled like the repository with a bare shell in the main checkout, and the one of the worktree.
    herdr knows a repository only through a workspace whose pane sits inside it, and the orchestrator's workspace did not qualify (its root pane ran from a herdr configuration directory), so herdr made a source workspace of its own.
    `herdr worktree list` now reports that workspace as the source of the repository (`source_workspace_id`), so later calls with `--workspace <it>` work and `--workspace <orchestrator workspace>` still fails with `not_git_worktree`.
    For the design: `workspace:open` resolves the source workspace from `herdr worktree list --cwd <repository>` and reuses it, so a second launch does not create another one; whether a launch may create the source workspace at all is a question for the user.
  - `scm:worktree:done <branch>` removed the worktree directory and the local branch after checking the merge into `origin/main`, and left the herdr workspace open.
    The workspace had three tabs (the agent, a shell and a git client): the user's own tabs live next to the agent's, so closing the workspace closes them too, and the launch tasks must not close a workspace without saying what is in it.
  - After `herdr workspace close`, `herdr agent get <name>` answered `agent_not_found`: the name goes away with the pane, as expected.
- 2026-11-09, second launch, with the existing global task instead of herdr's worktree commands: the lead of `make-install-scripts-idempotent`.
  - Command: `mise run scm:worktree:new fix/install-scripts-idempotent --base main --tab --workspace wN --label scripts-lead --agent-kind opencode --agent-name chezmoi-scripts-lead --json -- --agent plan --model anthropic/claude-opus-5-5`, with no `--prompt`.
    It returned exit 0 after 21 s and printed one JSON object (`path`, `branch`, `name`, `tab`, `pane`, `agent`); stderr logged the worktree, `mise trusted`, the tab and the agent.
  - The orchestrator's workspace worked as `--workspace` here: `scm:worktree:new --tab` only calls `herdr tab create --workspace <id> --cwd <worktree>`, which does not resolve a repository, so the `not_git_worktree` failure of the first launch does not occur, and no second workspace was created.
    The agent sits in a tab next to the user's tabs, which is the arrangement the user asked for ("in the chezmoi workspace").
  - The 21 s include the wait for the agent: the TUI was already drawn when the task returned, with the plan agent, the requested model and `xhigh` in the footer (the variant came from the saved state again).
    So the 10 s blank window of the first launch is absorbed by the task, and a prompt sent right after the task returns is safe.
  - Friction: the directory name is `<prefix>-<name>` with the prefix taken from the repository name (`dotfiles`, from the remote), not from the checkout's directory, so it differed from what the brief announced (`chezmoi-...`).
    The first prompt gave the real path and the brief was corrected afterwards; a launch brief should not hard-code a worktree directory name, or the launch should print the path before the agent starts.
  - First prompt, by hand: one paragraph in a shell variable, `herdr agent prompt ... --wait --until working --timeout 20000` returned in 1.6 s with the agent working and the input box empty; no retry.
  - No permission prompt came in the first 6 s (the brief's first command had not run yet); the guard's behaviour is recorded in the first launch's entry.
  - After the launch, the workspace that herdr had created as a side effect of the first launch (a bare shell in the main checkout) was checked as idle and closed, on the user's earlier choice of one workspace for everything chezmoi.
- 2026-11-12, first report of the second lead, and the cause of the lost agent names:
  - The lead reported at the end of its reading, by `herdr agent prompt` to the pane id, because `herdr agent get chezmoi-orch` failed for it: the orchestrator's name was gone again.
    The brief's fallback (name, else pane id, else the lead's own pane) worked as written, and the lead said which route it used.
  - Cause, from herdr's server log and the socket files: the herdr server restarted on 2026-11-06 at 18:13 and on 2026-11-11 at 16:54 (local time; the second one logs a session restore of 19 workspaces), and the names disappeared after each restart.
    The first entry above (names lost between 11-04 and 11-08) is the first of these restarts.
    The lead's own name survived the second restart (it was started on 11-09 through `--agent-name` of `scm:worktree:new`); why is not known, so a restart does not always drop names.
    After a restart the orchestrator renames its pane (`herdr agent rename <pane> <name>`), and a brief should keep the pane-id fallback.
    For the design: `agent:launch` reports the pane id next to the name, and a check of "is the reporting target still named" belongs before a long wait.
  - The review took the lead most of a weekend of wall clock: opencode's footer showed 2 h 23 min for the plan turn, with the user answering guard prompts in between (the share spent waiting was not measured).
    One of its commands, `mise install --dry-run-code` (a read-only form), was refused by the read-only guard: a false positive to report to the guard's repository.


<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
