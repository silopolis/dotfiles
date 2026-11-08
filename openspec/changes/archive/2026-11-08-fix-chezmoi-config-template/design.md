## Context

- `.chezmoi.toml.tmpl` (80 lines on commit `191ee9e`): prompts (lines 1-4), unused `$username` (5-10), includes `cpu`, `machine-type`, `gh-codespaces` (12-14), then `pager` and `color` (16-18), `[data]`, `[git]` with `commitMessageTemplate = "{{ promptString ... }}"` (30), `[env]`, `[update]`, `[diff]` with `diff.exclude` (51), `[edit]`, `[merge]`, empty hooks.
- The included templates end with `[data.cpu]`, `[data.machine]`, `[data.github]` tables, so anything placed after them without a new table header belongs to `[data.github]`.
- `dot_config/chezmoi/chezmoi.toml.tmpl` (56 lines) is a rendered copy plus `encryption` and `[age]`; it has no template actions; `chezmoi doctor` reports it as a suspicious entry.
- `chezmoi dump-config` on 2026-10-30: `diff.exclude: []`, pager `less`, umask 002 (from the process).
- The brew hook (`dot_config/shell/rc.d/110-pkg_brew.sh:63-91`) runs `chezmoi re-add` then commits; brew-file writes the Brewfile with its own mode, so `chezmoi status` keeps a mode-only entry.
- Neovim lives in its own private repository, cloned at `~/.config/nvim`; its remote exists since 2026-10-30.
  chezmoi runs `git pull` with the entry's `pull.args` on an existing `git-repo` external target the first time (no record in `gitRepoExternalState`), then only with `-R` when `refreshPeriod` is 0.
- `~/.config/gh/hosts.yml` is not managed (only `config.yml` is) and must stay that way.
- After `adopt-chezmoiroot`, all these paths are under `home/`.
- Facts checked on 2026-11-08 (chezmoi 2.73.3, `-S` on the worktree):
  - `chezmoi re-add` records the actual mode of the target in the entry state, so a later single-target `apply` only fixes the mode and does not prompt.
  - A single-target `apply` leaves the parent directories alone.
  - Under umask 027 a full `chezmoi status` lists 841 targets as modified (mostly modes), and the `git-repo` external folders (`vifm/colors`, `Vundle.vim`, `cheatsheets/community`) as modified too: apply only runs git there and never changes their mode, so they stay listed.
  - The global `pager` is only the fallback of the diff pager (`[diff] pager` wins), so `pager = "bat"` changes almost nothing while `[diff] pager` is `delta`.
  - `chezmoi doctor` briefly creates a test file in the source root and removes it.
  - Every chezmoi command reads the persistent state next to the config file; once `chezmoi init` runs from this worktree, the stored template hash no longer matches the main checkout's template, which then warns on every command.

## Goals / Non-Goals

**Goals:**

- `chezmoi init` alone produces a complete, correct config on any machine.
- Every key in the template has the effect it claims.
- The Neovim repository location is configuration, not source.

**Non-Goals:**

- Using the computed data in templates, profiles, distro data (change `fresh-machine-bootstrap`, cem `T-012`).
- Removing the unused prompts or `$username` lines (cleanup in `fresh-machine-bootstrap`, which decides which data stays).
- Mass-applying the new modes (change `reconcile-drift-and-supervised-apply`).
- Skipping the Neovim external by profile and proving a bootstrap without GitHub access (change `fresh-machine-bootstrap`).

## Decisions

### Order inside the template

```toml
{{- /* prompts and variables */ -}}
encryption = "age"
umask = 0o027
pager = "bat"
color = "auto"

[age]
  identity = "~/.config/chezmoi/key.age"
  recipient = "<public recipient, unchanged>"

{{ includeTemplate "cpu.toml.tmpl" . }}
...
[data]
...
```

`[age]` may come after the top-level keys or after the includes, since it is a table; the includes must follow every bare key.

`color = "auto"` and not `true`: `true` forces colour codes into piped output, which agents and scripts read; `"auto"` colours a terminal only (it is also chezmoi's default, written out so that the key is visible).
`pager` stays `bat` as the fallback of the diff pager; `[diff] pager = "delta"` keeps selecting the pager of `chezmoi diff`.

### umask 027 in chezmoi only

It applies to what chezmoi writes and to how it computes expected modes; the shell's umask (002 today) is decided in `fast-correct-shell-startup`.
Alternatives considered: 022 (world-readable files, Debian default), 002 with `private_` everywhere it matters; 027 chosen by the user: the user's group holds only the user, so 027 mostly removes access for other system accounts.

### Regenerate, do not hand-edit, the config

After the template is fixed and the snapshot source file is deleted, `chezmoi init` (no `--apply`) rewrites `~/.config/chezmoi/chezmoi.toml`.
`promptStringOnce` reuses the existing `data` values, so no prompt appears when they are set.
A copy of the old config goes to `/tmp/opencode/chezmoi.toml.before` for the diff.

### Brew hook re-applies the Brewfile

After `chezmoi re-add "$target"`, the hook runs `chezmoi apply --exclude=scripts "$target"`, which only fixes the mode since contents are equal.
Alternative considered: `chmod` with a computed mode; rejected because it duplicates chezmoi's mode logic.
The new line goes before the `BREWFILE_NO_COMMIT` early return, so that the mode is fixed whether or not the commit is skipped, and it ends with `|| return 1` like the `re-add` above it.
The hook calls `chezmoi` without `-S`, so it acts on the default source (the main checkout); the checks of task 5 use the same source.

### Neovim external, location from data

Three questions asked once with `promptStringOnce` and emitted as a `[data.nvim]` table after `[data]`: `host` (default `github.com`), `owner`, `repo`.
They live only in the local config, never in this repository.
The external template builds the URL from them:

```toml
{{- $nvim := or (get . "nvim") dict -}}
{{- $owner := get $nvim "owner" -}}
{{- $repo := get $nvim "repo" -}}
{{- $host := or (get $nvim "host") "github.com" -}}
{{- $hasClone := stat (joinPath .chezmoi.destDir ".config" "nvim" ".git") -}}
{{- $hasLogin := stat (joinPath .chezmoi.destDir ".config" "gh" "hosts.yml") -}}
{{- if and $owner $repo (or $hasClone $hasLogin) }}
[".config/nvim"]
  type = "git-repo"
  url = {{ printf "https://%s/%s/%s.git" $host $owner $repo | quote }}
  refreshPeriod = "0"
  pull.args = ["--ff-only"]
{{- else if and $owner $repo }}
{{ warnf "nvim: no clone and no GitHub CLI login, skipping the Neovim external" }}
{{- end }}
```

- `get` with a fallback instead of `.nvim.owner`, because chezmoi templates fail on missing keys.
- In a render check (`execute-template --init`, no terminal), a prompt with no default returns its own prompt text, not an empty string; the checks therefore set `nvim.owner` and `nvim.repo` through `--override-data`.
  A real `chezmoi init` in a terminal stores what the user types, and an empty answer means no external.
- The rendered URL contains the owner and repository: no check or message prints it; checks compare it with the data and print a verdict (`match`) only.
  git may echo the URL in an error message, so commands that talk to the remote have their error output filtered.
- The guard is offline and cheap: `gh auth status` would make a network call on every chezmoi command, and `output` aborts the whole template on a non-zero exit.
  The presence of `~/.config/gh/hosts.yml` only says that a login was done once; a stale login makes the clone fail at apply time, which is acceptable and visible.
- `.chezmoi.destDir` instead of the home directory, so the skip and clone tests can run against a scratch destination.
- No `clone.args`: the repository's default branch is used.
- `pull.args = ["--ff-only"]`: a diverged or dirty clone makes the pull fail or do nothing; it never merges, rebases or discards.
- HTTPS rather than SSH: the git credential helper of the GitHub CLI already serves it.
  Alternative considered: SSH, as chezmoi's documentation suggests for private repositories; needs a key set up before the first apply.
- Alternative considered: a `run_once` script that clones; rejected, the external is declarative and visible in `chezmoi managed`.

### Incus feature flag

One boolean question, asked once: `promptBoolOnce . "features.incus" "Install and enable Incus on this machine" false`, emitted as a `[data.features]` table after `[data]`, like `[data.nvim]`.
The repository default `features.incus: false` (`.chezmoidata/features.yaml`, which `add-incus-setup-hook` will add; it does not exist yet) applies where the config holds no value, and the config value wins when both exist (checked on 2.73.3).
`promptBoolOnce` returns its default when no terminal is attached (checked with `execute-template --init`), and reads an existing value without asking.
`.chezmoidata` is not visible to the config template, so the question is asked on every machine whose config lacks the flag, whatever the repository default.
The prompt flags (`--promptString`, `--promptBool`) are keyed by the prompt text, not by the data path, so the checks below use `--override-data`, keyed by the data path, which the `Once` functions read as existing data.

### First apply on the existing clone

With no record for `~/.config/nvim` in `gitRepoExternalState`, the first apply runs one `git pull --ff-only` there, and records it; later applies skip it unless `-R` is passed.
The step is applied once, when the user's Neovim work is merged and idle, after a read-only check that the pull would not move `HEAD`: the clone is clean and on a branch with an upstream, and the upstream's commit on the remote is `HEAD` or an ancestor of it.
If the remote commit is not present locally, the pull would move `HEAD`: the step stops and the user decides.
The state record is checked by its exact key (the clone's path in `gitRepoExternalState`), since other externals already have records.
Checked offline on 2026-11-08 (a clone of a local bare repository, no state record, no terminal): the first plain apply pulls and records without asking; a second plain apply is skipped.
chezmoi records the folder's expected mode (0750 under umask 027) but git creates it as 0775, so `apply -R` afterwards asks "has changed since chezmoi last wrote it?" and fails without a terminal; `-R --force` runs the pull, and a local commit and an untracked file survive it.
Alternative considered: seeding the state record by hand so chezmoi never touches the clone; rejected, it relies on chezmoi internals.

## Risks / Trade-offs

- [Risk] `chezmoi init` prompts or fails in a non-interactive session. → Run it in a terminal; check first with `chezmoi --override-data '{"email":"x","gitemail":"x","firstname":"x","name":"x"}' execute-template --init < home/.chezmoi.toml.tmpl`.
- [Risk] Deleting the snapshot source makes chezmoi think it should remove `~/.config/chezmoi/chezmoi.toml`. → It does not: removed sources are only forgotten, never deleted, unless listed in `.chezmoiremove`; verify that the target is no longer managed (`chezmoi managed` does not list it, `chezmoi --no-pager status` shows nothing for it) and that the file is still there.
- [Risk] Wrong recipient breaks decryption of every encrypted file. → Copy the recipient from the working config; check with `chezmoi cat` on one encrypted target before and after.
- [Risk] umask 027 makes a file unreadable for a service running as another user. → None found on 2026-10-30 (the display manager reads the avatar from its own copy); `reconcile-drift-and-supervised-apply` reviews the full list of mode changes before applying.
- [Risk] The first pull in `~/.config/nvim` fails or changes `HEAD` while the user is working there. → Applied only when the user says the repository is idle; fast-forward only; `git status -sb` and `rev-parse HEAD` compared before and after.
- [Risk] `chezmoi apply -R` pulls into the Neovim working copy at any later time. → Fast-forward only; it asks for confirmation first because of the mode mismatch (it fails without a terminal, `--force` skips the question); documented in `AGENTS.md`.
- [Risk] The login file becomes managed by a later change and the guard is meaningless. → `manage-gh-config` states in its proposal and spec that it stays unmanaged.
- [Risk] Between the first `chezmoi init` from this branch and its merge, the main checkout still carries the old template and the frozen config source. → Its commands warn that the config template has changed (expected); nobody runs `chezmoi init` or applies `~/.config/chezmoi` from there (either would bring back the config without encryption and umask); the branch is merged soon after the archive.
- [Risk] The `git-repo` external folders with a refresh period stay listed as modified after any apply, because umask 027 expects 0750 and apply only runs git there. `~/.config/nvim` is not listed: with `refreshPeriod = "0"` and a state record, chezmoi skips the entry, and its mode mismatch only surfaces with `apply -R` (the confirmation). → Not fixed here; the list is recorded in "Measured at close" for `reconcile-drift-and-supervised-apply`.
- [Risk] A check prints the Neovim location by accident (rendered URL, `remote -v`, an error message). → The checks print verdicts, key names or lengths only, and filter the error output of git commands that reach the remote.

## Measured at close

Taken on 2026-11-08 with the regenerated config (umask 027), `-S` on the worktree, scripts excluded:

- `chezmoi status` lists 838 entries: 833 with a modified second column only (313 directories, 520 files), 4 modified since the last write as well (`.config`, `.config/lazygit/config.yml`, `.local/share/fonts`, `.local/share/icons`), and 1 `AD` (`.bashrc.original`, already there before this change).
- `chezmoi diff --exclude=scripts,externals` shows 713 blocks: 711 mode only, 1 content only, 1 mode and content.
- The `git-repo` external folders listed as modified: `.config/vifm/colors`, `.config/vim/bundle/Vundle.vim`, `.local/share/cheat/cheatsheets/community` (mode 0775 against 0750; apply never changes it).
  `~/.config/nvim` is not listed (see the risk above).
- `reconcile-drift-and-supervised-apply` reviews these before the first full apply; the difference between the status count and the diff block count is part of that review.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
