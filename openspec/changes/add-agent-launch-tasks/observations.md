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
- 2026-11-12, outcome of the second launch, from the launch (2026-11-09 18:05) to the merge:
  - The lead built and archived `make-install-scripts-idempotent` in 17 commits above `main`, with a test harness at 155 of 155; the build phase ran from 13:19 to 18:26 on 2026-11-12, with the user answering guard prompts and five design questions in its pane.
    The branch needed no rebase (`main` had not moved), so the orchestrator fast-forwarded it after a read-only check (clean worktree, `gitleaks`, strict validation, no private value in the added lines).
  - Reports reached the orchestrator through `herdr agent prompt` by name once the name had been restored, and through the lead's own pane when the target was blocked: `herdr agent prompt` refuses a blocked agent (`agent_blocked`), so a report sent while the orchestrator waits for a question is lost unless the lead also writes it in its own pane.
    For the design: the launch brief keeps the three-step fallback (name, pane of the tab labelled for the orchestrator, own pane), and the orchestrator reads the lead's pane after every question it has to answer.
  - Windows that no brief can close: the lead deployed four files as single targets with the user's go before the merge, so for about an hour and a half the live files were ahead of `main`, and a brew change in that window would have made the brew hook commit the live Brewfile on `main` and break the fast-forward.
    The brief said to touch no brew package, and none was touched.
    A launch brief for a change that deploys before it merges should name this window and ask for a quick merge, as for the config template in the first launch.
  - One real `sudo true` ran by mistake: a throwaway helper test used a bare `PATH` outside the harness, so the real `sudo` ran and failed at once because standard input was `/dev/null`.
    The lead reported it by itself, as the brief asks (any real `sudo` is stop-and-ask); a harness that puts a logging `sudo` first on `PATH` for every test, not only for the scripts under test, would have made the mistake impossible.
  - The lead printed unfiltered `herdr agent list` and `herdr workspace list` once each, which put the names, working directories and session titles of other projects into its transcript.
    The export needed four throwaway patterns for them (the name of another project, the pane titles, two personal workspace labels, one workspace name).
    For the design: `agent:launch` and its brief template should say to select fields with `jq` (name, status, pane id) in every herdr listing, as the briefs already say for `chezmoi data`.
  - Cleanup in a shared workspace: `scm:worktree:done <branch> --keep-tab`, then `herdr tab close <tab id>`, removed the worktree, the local branch and the lead's tab and left the four other tabs of the workspace untouched; the remote branch never existed.
    Closing the tab by id, after the merge check, is the safe way when the user's own tabs sit next to the agent's.


- 2026-11-16, third launch, with the global task and `--tab` in the source workspace: the lead of `add-agent-env-wrapper`.
  - The launch was one command (`scm:worktree:new <branch> --base main --tab --workspace <id> --label <label> --agent-kind opencode --agent-name <name> --json -- --agent plan --model <model>`).
    It took about 20 s, created the worktree and the tab, and returned the pane id and the name in its JSON; the agent name resolved and the orchestrator's own name still resolved for the lead's reports, so the fallbacks of the brief were not needed.
    The first read of the new pane showed only the path line, so the footer with the mode and model could not be confirmed at launch; it showed in the lead's report a little later (plan, the planned model, high effort).
  - One prompt, pointing at the brief, was accepted with `--wait --until working`.
    The lead's review came back within about half an hour, and the user switched it to build mode in its pane.
  - A claim of the brief was wrong: it said the lead inherits the revoked token variable, but the lead's shell had already dropped it, since new shells unset it at startup.
    The lead found it during its review and said so.
    For the design: a brief states facts about the environment only after a count taken from a process started the same way as the lead's.
  - The change was built in one session with the user's go for the single-target deployment; the live check created a probe tab in the user's workspace, counted matching names by process id, and closed the tab by id, with the tab list identical afterwards.
    For about an hour the deployed file was ahead of `main`; the review and fast-forward were quick, but the brief did not name this window.
  - The lead rebased on a `main` that had moved by two commits, committed its own session export, and the orchestrator re-ran the lead's tests, the export checks and the spec checks before the fast-forward.
    No conflict and nothing to fix; the review took a few minutes.
  - Reporting: the lead's notice to another orchestrator named a path that the archive then moved, so it had to send a correction.
    The change did not say which orchestrator had asked for it, so the lead relayed the final notice through the orchestrator of this repository.
    For the design: a launch brief for a change that came from a request names the requester and says whether the notice goes before or after the archive.
  - `openspec archive` frictions seen on this repository's side too: it dropped the preamble of a new spec (Purpose came out as TBD) and merged the delta file's trailing modeline into the middle of a main spec; both were fixed by hand.
  - Other frictions the lead listed: the `shellcheck` shim failed with "No version is set"; there is no GNU `time` on `PATH`; in zsh `print '--- x'` reads an option and dropped three results; the startup banner of an interactive shell pollutes the output of `zsh -i -c`; startup time varies by hundreds of milliseconds between runs minutes apart, so a fixed millisecond criterion cannot be measured (interleaved runs and medians work); the commit hook flagged a synthetic test canary in the export, which a throwaway terms file masked without touching the scanner's allow list.
  - The lead printed herdr listings once more, despite the brief: the names of agents of other projects, a task id and a workspace id came into its transcript and needed throwaway terms in the export.
    For the design: the first message of the lead should repeat the rule to select fields with `jq` for every herdr listing, because the brief is read once at the start.
  - Cleanup as in the second launch: `scm:worktree:done <branch> --keep-tab`, then `herdr tab close <id>`; the lead had pushed nothing, so no remote branch was left.

- 2026-11-17, fourth launch, same command as the third: the lead of `fast-correct-shell-startup`, a change that deploys files read by every new shell.
  - The lead measured, reviewed and asked the user seven questions in one form, then built in six deployments, one file at a time with a diff and a rollback each, a new shell checked in a spare tab it closed by id, and the whole change took about three and a half hours of wall clock with the user answering.
    The orchestrator re-measured after each deployment from its own pane (deployed against source, bytes at startup, interleaved timing), and the one discrepancy it found was its own glob matching three files.
  - The stricter deployment rules of the brief held: no login or session break, the exported variable names of four shell kinds were compared between `main` and the worktree in memory (counts and sorted name sets, never values), and the brew install script change waits for the supervised apply.
    For the design: a brief for a change that edits files every shell reads asks for that name-set proof before the file that sets the environment, and keeps the order from the least to the most risky.
  - The first read of the lead's pane showed the footer with the mode and the model this time; the launch took one command again.
  - Frictions the lead listed:
    - herdr JSON nests agent fields under `.result.agent` and tab fields under `.result.tab`, so a top-level `jq` path gives null, and `herdr pane read` output is not JSON.
    - zsh MULTIOS sent standard output into a pipe after `2>&1 >/dev/null` (a habit already in `AGENTS.md`), and a shell was needed to get it right.
    - Plan mode blocked a write of the baseline in `/tmp` that the brief asked for, and the read-only guard blocked a `PATH=` assignment inside a child `zsh -c` string: a false positive for the guard's repository.
    - The `shellcheck` shim fails with "No version is set", and `mise exec` did too; the lead called the binary under the mise installs.
    - The `fr_FR` locale gives decimal commas in `printf` and `awk`, which broke arithmetic in the first version of a timing helper.
    - `chezmoi apply` into a scratch destination fails with "could not open a new TTY" when a pre-created directory has a mode other than 0750: let chezmoi create the directories.
    - `bash -i -c exit` prints `exit` itself, so a spec check had to use `true`; bash without `LANG` warns about `setlocale`, a finding for `correct-shell-environment`.
    - `openspec archive` of a new capability left "Purpose TBD" and a trailing blank line after the modeline: the second time on this repository, fixed by hand again.
    - `rtk` filtered some listings, and starship warns about a scan timeout in a scratch directory.
  - Orchestration state: the orchestrator's briefs and scratch had lived in `/tmp/opencode`, which a reboot empties and which a lead in a worktree cannot read without a permission prompt; the user asked on 2026-11-17 to follow the other fleet repositories and keep them in a git-ignored `.state/` (rule in `AGENTS.md`, Workflow).
    The first brief written there also needed the old harness scripts copied into the lead's worktree, for the same permission reason.
  - Private values in the lead's transcript, masked in its export with a throwaway terms file: a cloud account address and a region prefix from a probe pane's prompt, the names of other projects' worktrees and a log file from one `find` listing, and a short hash of the desktop environment.
    For the design: the brief repeats the rule on listings, and the `find` and prompt cases show it must also cover `find` over the user's directories and the prompt of a probe pane.
  - Cleanup: `scm:worktree:done <branch> --keep-tab` removed the worktree and the branch, then `herdr tab close <id>` closed the lead's tab.

- 2026-11-18, fifth launch, the first change run by three agents in a row: `add-shell-test-harness`, a plan lead, a builder and a closer, in three tabs of the source workspace, one worktree.
  - The plan lead (same launch command as before) reviewed the brief against the tree, inventoried the checks of the three old harnesses with a level for each, asked the user seven questions in one form, and committed the proposal with its own session export.
    The user asked that the apply start in a new session: the orchestrator started a builder in a second tab of the same worktree with `herdr tab create --cwd <worktree>`, then `herdr agent start <name> --kind opencode --pane <pane> -- --agent build --model <model>`, in build mode directly, with a prompt that points at the brief and the change.
  - The builder ran for about four hours of wall clock and used 70 percent of its context by the end of section 7; the user cut it there.
    A hand-off note written by the builder into its own `.state/` (commits, exact commands, counts, the user's decisions, deviations still to record, fragile points, frictions, private-content kinds, advice for the rest) let a fresh closer take sections 8 to 10 with no loss.
    For the design: the cut point is a section boundary, the note is a task of the cut, and a closer is started with the orchestrator's own pending files named as not to be staged.
  - The orchestrator re-measured at every report from its own pane and found: an error in the design (the install backend of the test runner does not verify the release asset, found by the builder at the first install gate), a gap in the live allow-list of the harness (found by the first live run), and, at verify, four scenarios of the specs that had no test (found by the closer).
    A second path of the loop caught a claim of the closer that was wrong ("already in main"), and a report whose statements the closer corrected after a self-check.
  - Parallelism: the user suggested running the long test runs through sub-agents; the suggestion arrived after the builder had run them from one background script, which was equivalent because every run takes its own report and temporary directory.
    For the design: a brief for a test-heavy change says so before the section starts.
  - Orchestrator errors worth keeping: a `set -- $r` in a scan helper did not word-split in zsh (a habit already in `AGENTS.md`) and printed zero added lines; a scan through `rtk rg` truncated an output once; both were caught by comparing counts with plain `rg`, and the full scans were re-run.
  - Frictions of the three sessions:
    - `mise install` with the short name of a tool creates a second install next to the one the pin names, and `mise uninstall` leaves symlinks behind.
    - A shim of a tool that is not active in a worktree fails, so tests resolve tools once before the scratch home is set.
    - The test runner's parallel helper prints a citation notice and writes a state directory unless told otherwise (set per run, never exported from a startup file).
    - `git commit | head` kills git on a broken pipe in the middle of the hook, and the commit is not made.
    - `openspec archive` of a change with a new capability again left a placeholder Purpose and dropped the preamble, moved a modeline into the middle of a requirement, and left stray blank lines: the third time, fixed by hand each time.
    - The commit subject limit is checked by no hook: one subject of 85 characters passed and was reworded at the final rebase.
    - The Grep tool given one file path returned matches from the whole tree including the session exports.
    - `herdr agent prompt` answers with no `ok` key, and `herdr tab create` fields sit under `.result.tab` and `.result.root_pane`.
  - Private content in the three transcripts, masked in their exports: the login name through paths and listings, the full name and handle of the commit author from one command, the Homebrew prefix, the names of tools installed through mise, a few third-party formula names, and the key-shaped synthetic canary values of the old wrapper harness (masked by a throwaway terms file, because the commit hook takes them for keys).
  - Cleanup: the closer's tab was closed by id after its export was committed; the worktree removal refused while the branch was not yet in `origin/main`, which is the intended check, and ran after the push.
    The rule "a finished agent is closed once its session is exported" was written into `AGENTS.md` during this launch at the user's request.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
