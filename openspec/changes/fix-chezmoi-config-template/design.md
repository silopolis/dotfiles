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
color = true

[age]
  identity = "~/.config/chezmoi/key.age"
  recipient = "<public recipient, unchanged>"

{{ includeTemplate "cpu.toml.tmpl" . }}
...
[data]
...
```

`[age]` may come after the top-level keys or after the includes, since it is a table; the includes must follow every bare key.

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
The repository default `features.incus: false` (added by `add-incus-setup-hook` in `.chezmoidata/features.yaml`) applies where the config holds no value, and the config value wins when both exist (checked on 2.73.3).
`promptBoolOnce` returns its default when no terminal is attached, and reads an existing value without asking.
The prompt flags (`--promptString`, `--promptBool`) are keyed by the prompt text, not by the data path, so the checks below use `--override-data`, keyed by the data path, which the `Once` functions read as existing data.

### First apply on the existing clone

With no record for `~/.config/nvim` in `gitRepoExternalState`, the first apply runs one `git pull --ff-only` there, and records it; later applies skip it unless `-R` is passed.
The step is applied once, when the user's Neovim work is merged and idle, after a read-only check that the pull would not move `HEAD`.
Alternative considered: seeding the state record by hand so chezmoi never touches the clone; rejected, it relies on chezmoi internals.

## Risks / Trade-offs

- [Risk] `chezmoi init` prompts or fails in a non-interactive session. → Run it in a terminal; check first with `chezmoi --override-data '{"email":"x","gitemail":"x","firstname":"x","name":"x"}' execute-template --init < home/.chezmoi.toml.tmpl`.
- [Risk] Deleting the snapshot source makes chezmoi think it should remove `~/.config/chezmoi/chezmoi.toml`. → It does not: removed sources are only forgotten, never deleted, unless listed in `.chezmoiremove`; verify with `chezmoi apply --dry-run --verbose ~/.config/chezmoi`.
- [Risk] Wrong recipient breaks decryption of every encrypted file. → Copy the recipient from the working config; check with `chezmoi cat` on one encrypted target before and after.
- [Risk] umask 027 makes a file unreadable for a service running as another user. → None found on 2026-10-30 (the display manager reads the avatar from its own copy); `reconcile-drift-and-supervised-apply` reviews the full list of mode changes before applying.
- [Risk] The first pull in `~/.config/nvim` fails or changes `HEAD` while the user is working there. → Applied only when the user says the repository is idle; fast-forward only; `git status -sb` and `rev-parse HEAD` compared before and after.
- [Risk] `chezmoi apply -R` pulls into the Neovim working copy at any later time. → Fast-forward only; documented in `AGENTS.md`.
- [Risk] The login file becomes managed by a later change and the guard is meaningless. → `manage-gh-config` states in its proposal and spec that it stays unmanaged.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
