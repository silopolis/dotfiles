# Brief: design the change correct-shell-environment

Written by the orchestrator agent of this repository, on 2026-11-20, for the agent that leads this change (suggested name `chezmoi-env-lead`).
The change exists as a proposal and a draft spec (`openspec/changes/correct-shell-environment/proposal.md` and `specs/shell-environment/spec.md`, three requirements moved from the startup draft: clean `PATH`, working locale, opt-in token exposure): no study, no design, no tasks.
Your job is to run the study that the proposal needs, take the open decisions with the user, and produce the design, the specs and the tasks.
This file is the operational complement to the change: once its artifacts exist, they are the contract and this file says how to work.
It sits in your worktree's `.state/briefs/correct-shell-environment/brief.md`, which is git-ignored and is deleted with the worktree: your first commit on the change copies it to `openspec/changes/correct-shell-environment/brief.md`, so it must stay free of anything private (it is).

## Where you work

- Repository: this one, in a worktree under `~/Work/trees/` on branch `feat/correct-shell-environment`, started from `main`.
  The orchestrator creates the worktree and your herdr tab and gives you the exact path in the first message; if you find yourself in the main checkout, stop and say so.
- Your tab sits in the herdr workspace of this repository, next to the tabs of the user and of the orchestrator: do not close, rename or type into a tab you did not open.
- You start in plan mode, then the user switches you to build mode for the artifacts.
  The read-only guard may ask for approval on commands it does not know yet; the user answers in your pane.
- Everything chezmoi reads lives under `home/` (`.chezmoiroot`); `tests/` and `openspec/` sit at the root and are never chezmoi targets.
- You do not apply anything: this brief ends at a reviewed set of artifacts, and a separate build session applies them later.

## What the change is

`fast-correct-shell-startup` (archived 2026-11-16) made shell startup silent and fast and left out the half that decides which environment a shell provides.
This change owns that half: `PATH`, locale, which secrets are exported and to whom, the shell umask, the load order of syntax highlighting, the interactive guard of `shellrc`, and what a non-interactive login shell (the desktop session) loads.
Audit findings F18, F21, F23 and the environment points of F33 (`docs/audits/2026-10-30-environment.md`, change map row 28).
Read the proposal first: its "What moves in", "What the review of 2026-11-16 found" and "Open questions" sections are the starting point and are accurate as of today.

Decisions already taken with the user on 2026-11-20 (do not reopen them without a reason):

1. **The study of secrets held by the desktop session is part of this change**, not a separate one and not a prerequisite: it is section 1 of your work, and its findings feed the design.
2. **The proposal's "better version of `profile` is environment-only"** is designed here, together with the token study (see the proposal: the desktop login must not run the interactive parts, must keep what the session needs, must not export tokens it has no reader for, and needs a guard so that an interactive login shell does not run the environment part twice).
3. **`add-agent-env-wrapper` stays as it is** (`rc.d/445-tools_opencode.sh`): the wrapper protects agents and their children only and does not replace the study.
4. **History and identity of this repository are not in scope** (accepted as they are).

## Facts measured on 2026-11-20 (check them, they may have moved)

- The live `~/.config/shell/rc.d` holds two files that the source does not manage, and neither belongs to this change: tasks 2.3 and 2.4 of `reconcile-drift-and-supervised-apply` already own them (the libvirt snippet is moved into the source under a new name; `190-env_path_user.sh`, which is identical to `050-env_path_user.sh`, is deleted).
  Until task 2.4 runs, `~/.local/bin` is prepended twice; say so in the design as a known live state, and do not add a task for it.
- Generated locales: `C`, `C.utf8` and `fr_FR.utf8`; `en_US.UTF-8`, the `LANG` default of `rc.d/020-env_defaults.sh`, is not generated.
- The umask of an interactive shell is 002.
  `chezmoi status` shows all 32 entries under `~/.config/shell` as modified: 2 directories at 0775 (chezmoi expects 0750) and 30 files at 0664, whose content is identical to what the source renders; so the drift is mode only (`chezmoi diff <directory>` prints just the directory, ask it per file).
  Mode drift is the subject of `reconcile-drift-and-supervised-apply`, not of this change, but it is evidence for the umask decision.
- Specs that this change touches or must not break (read them under `openspec/specs/`): `shell-startup` (7 requirements: silent startup, one `rc.d` pass, cached completions and others), `secret-hygiene` (4), `agent-environment` (6), `shell-test-harness`.
  Say in the design which requirements you modify, which you add and which stay.
- The test suite is the proof: `mise run test:deps` once (the checkout has no `tests/.lib` yet, and it downloads: say what you run and wait for the user's go once), then `mise run test`; `tests/README.md` describes the levels (unit, smoke, live), the helpers and the mutants.
  Every requirement of your specs gets a test at the right level, and a way to show that the test can fail (a mutation of the code under test).

## Section 1: the study (read-only)

The starting evidence is the inventory of 2026-11-15 in `openspec/changes/archive/2026-11-16-add-agent-env-wrapper/design.md` (lines 7 and 50): the private environment file holds 10 assignments, all with secret-looking uppercase names, and most of the variables have no reader on this machine.
The backlog item "Secrets held by the desktop session" in `TODO.md` says what the study must settle before any change:

- what reads each variable inside the desktop session, and which services need which key;
- where each key should live instead: a key file of its own with mode 0600, the keyring, or a credential helper;
- whether the profile stops exporting them and shells source the file only in interactive shells.

Settle in addition: what each kind of shell loads today (interactive login, interactive non-login, non-interactive login as the display manager starts it, non-interactive non-login, over ssh, `env -i`) and what the systemd user manager inherits from the desktop login, by running real shells in a scratch home where you can, and counts only where you cannot.

Rules for the study, which are the point of the work:

- Never print, log, copy or commit a value, and never print the name of a variable that is specific to this workstation or chosen by the user: label the variables V1 to Vn by position and report counts and booleans per label.
  Only publicly well-known names (a provider's documented convention) may be written, as in `AGENTS.md`.
- Never read the private environment file with a tool that prints it (neither the deployed file nor its source, nor `chezmoi cat` of it).
  When you need a fact about it, use a pipeline that prints counts or per-label booleans, and when you are not sure that a command cannot print a value, ask the user to run it in a terminal and give you the count.
- The desktop session's environment (`systemctl --user show-environment`, `/proc/<pid>/environ`): count with `cut -d= -f1`, `grep -c`, never list; this is the same method as the reboot check in `TODO.md`.
- Your process holds none of the secret-named variables (agents started through the `opencode` function are stripped), which is why the readers' side must be found in files and process lists, not by looking at your own environment.
- Put what you learn in the change folder as `findings.md` (counts and labels only, one sentence per line), or fold it into the design's context section, your choice; commit nothing from `.state/tmp/`.

## Section 2: decisions to take with the user, in your pane

Bring each one with the options, what each costs, and your recommendation; one at a time; the user answers in the pane.
Record each answer in the design.

1. Token exposure mechanism (from the proposal): a loader function that sources the encrypted file in the current shell only; per-directory loading through direnv or mise `[env]`; per-command wrappers; key files with mode 0600 and the keyring.
   The study decides which of them the readers need.
2. Shell umask: keep 002, align with chezmoi's 027, or Debian's 022; say what each does to the files that tools write under `$HOME`.
3. Locale: generate `en_US.UTF-8` (needs sudo, which only the user can grant) or default `LANG` to a locale that exists with English messages through `LANGUAGE`.
   Whichever is chosen, the case of a shell started without `LANG` (`env -i`, a bare terminal, ssh) must not print `setlocale` warnings; the tests of `fast-correct-shell-startup` set `LANG` as the desktop session does, so this case is not in their counts yet.
4. What a non-interactive login shell loads, and whether `shellrc` gets its interactive guard back once the desktop session no longer depends on it.
5. Which loose ends of F33 (highlighting last, `HISTFILE` outside XDG, the empty and stub `rc.d` files, `shell/environment` unused), belong in this change and which go to other changes; `manage-xdg-basics` and `port-omalap-shell-aliases` also touch this area.

## What to do

1. Plan mode: read (below), say in a few lines what in this brief or in the proposal does not hold against the tree, run the study of section 1 (read-only; scratch in `.state/tmp/`, mode 0700), and report its results.
2. Section 2: the decisions, with the user.
3. Build mode, after the user's switch: write the artifacts in the change folder with the project's skills (`/opsx-continue` or `/opsx-ff`, your choice): `design.md` (decisions, the load order of each kind of shell as a table or list, risks, migration and rollback, what the desktop session sees after the next login), `specs/shell-environment/spec.md` (new capability `shell-environment`) plus any delta spec for `shell-startup`, `secret-hygiene` or `agent-environment`, and `tasks.md` (small tasks, each with its test and its check, grouped so that a fresh build session can pick it up cold).
   Update the proposal where the study answers its open questions (the order question closes: the study is inside), and `TODO.md`'s "Secrets held by the desktop session" item only if I ask you to.
4. Validate: `openspec validate --all --strict` passes, then propose the commit; the user reads the artifacts before anything is applied.
5. Stop there: you do not apply, merge or push.
   Rebase on `main`, run the validation again, and report with the last commit hash; the orchestrator fast-forwards `main` and starts a build session from your tasks.

Manual checks that cannot be automated go in the tasks as explicit steps for the user: the desktop session reads its environment at login, so a change to `profile` is only proved by a new login, and the live probe (counts of the user manager's and the terminal's variables after that login) is the user's to run.

## chezmoi in a worktree

- This worktree is not chezmoi's default source: every chezmoi command takes `-S <worktree>`; check first that `chezmoi -S <worktree> source-path` prints `<worktree>/home`.
- chezmoi comes from brew: if a shell lacks it, run `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` first.
- Never run a full `chezmoi apply`, never `chezmoi init`; this brief deploys nothing.
  A scratch render or an isolated shell in a scratch home is how you test the proposed load order.

## Read first, in this order

1. `AGENTS.md` (safety rules, writing for a public repository, the conventions, the zsh pitfalls).
2. `openspec/changes/correct-shell-environment/proposal.md`, then audit rows F18, F21, F22, F23, F33 and change map row 28 in `docs/audits/2026-10-30-environment.md`.
3. `openspec/changes/archive/2026-11-16-fast-correct-shell-startup/` (proposal, design, tasks, the spec `shell-startup`, and the part of its design about the draft that was narrowed), and `openspec/changes/archive/2026-11-16-add-agent-env-wrapper/` (design lines 7 and 50 for the inventory; spec `agent-environment`).
4. The main specs `shell-startup`, `secret-hygiene`, `agent-environment`, `shell-test-harness` under `openspec/specs/`, and `tests/README.md`.
5. The source: `home/dot_config/shell/` (`profile`, `shellrc`, every `rc.d` file, `environment`), `home/dot_config/zsh` and `home/dot_config/bash` if present, `symlink_dot_*` for the entry points, and how the encrypted environment file is deployed (its source path and mode, not its content).
6. `TODO.md` (the follow-ups on secrets, the planned order, where this change sits).
7. After reading, say in a few lines what does not hold against the tree.

## Rules

- Public repository: no secret values, no private hosts or IP addresses, no employer or client details, no private repository names.
  Names of secret variables: only publicly well-known ones (a provider's documented convention), never a name specific to this workstation; tests use `DEMO_` names only.
  Name only darse, cem, bosco, greffe, opencode-readonly-guard and the Neovim configuration repository; call any other "a fleet repository".
- Markdown: one sentence per line, no em or en dashes, no emoji, sentence-case headings, the vim modeline as the last line.
- Shell: the code under test keeps its rule (POSIX-compatible where bash and zsh both source it, shell-specific code in `case "$CURRENT_SHELL"` blocks).
  An agent's shell is zsh: see the four habits in `AGENTS.md`, and the zsh habits that bit earlier leads (`2>&1 >/dev/null | next` also pipes standard output, `print '--- x'` reads an option, a variable holding several words does not split).
  `rtk` condenses some outputs: use `/usr/bin/grep -a` or plain `rg` for counts that decide something.
- Commits: propose the message first (`type(domain:subject): imperative lowercase summary`, English, subject at most 80 characters; domain `chezmoi:spec` for the change artifacts, `shell` for code), commit only after the user validates it, with `env -u GITHUB_TOKEN HK_STASH=none /home/linuxbrew/.linuxbrew/bin/git commit`, and never `git commit | head`.
  Never push.
- Anything that uses sudo, writes outside `$HOME`, installs, uninstalls or deletes needs the user's explicit go.
- Your scratch and logs go in `.state/tmp/` of your worktree, not in `/tmp/opencode`; `.state/journal.md` is the orchestrator's, do not write to it.
- In every herdr listing, select fields with `jq` (name, status, pane id, tab id); herdr JSON nests agent fields under `.result.agent`, tab fields under `.result.tab`, and `herdr pane read` output is not JSON.
- Cut your session at a section boundary when your context nears 70%: write a hand-off note into `.state/briefs/correct-shell-environment/` and tell the orchestrator; a fresh session continues from it.

## Reporting

- Report with one short line each time, at five points: reading done, study done (with counts, no names), decisions taken, artifacts ready for review (with the validation result), blocked (say on what).
  Send it with `herdr agent prompt chezmoi-orch "<one line>"` when `herdr agent get chezmoi-orch` succeeds.
  Agent names can be lost when herdr restarts: when that fails, find the pane of the tab labelled `orch` in the workspace of this repository (`herdr tab list --workspace <id>`, then `herdr agent list` with `jq`) and prompt it by pane id, checking the tab label before you rely on it.
  `herdr agent prompt` refuses a blocked agent: when the orchestrator waits for the user, write the line in your own pane as well.
- Keep a list of every friction you meet with the tooling, and send it with the last report.
- When a command or diagnostic of yours makes a private value inferable in your transcript, say so in the report, so that the export of your session is masked before it is committed.
- Your session export is done at the end, when the user asks, following `memory/sessions/README.md`.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
