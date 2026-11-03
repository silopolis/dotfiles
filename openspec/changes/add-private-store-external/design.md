## Context

- The Neovim repository (session S16, change `layer-spell-dictionaries`) reads private spell words from `~/.local/share/chezmoi-private`, for its third spell tier and for LTeX.
  Its session export script reads the redaction terms from there too.
  Nothing in that directory is ever published.
- On 2026-11-03 the store on this machine is a git clone of a private repository with an `origin`, one commit, a clean tree, and a 0700 root.
  It holds files of mode 0600 and 0664 and two symlinks.
  Its `.gitattributes` sets `*.add merge=union`, and it ignores `*.add.spl` itself.
- `fix-chezmoi-config-template` (not applied yet) defines the pattern this change reuses:
  - questions asked once with `promptStringOnce`, emitted as a `[data.nvim]` table in the local config;
  - a `git-repo` external built from `get` with fallbacks;
  - a guard: owner and repository set, and either an existing clone or the GitHub CLI login file `~/.config/gh/hosts.yml`, tested with `stat` on `.chezmoi.destDir`;
  - `refreshPeriod = "0"` and `pull.args = ["--ff-only"]`, HTTPS through the GitHub CLI credential helper, and a warning when skipped;
  - `umask = 0o027` for what chezmoi writes.
- chezmoi runs `git clone <url> <target>` when the target is missing, and `git pull` with `pull.args` the first time it sees an existing target (no record in `gitRepoExternalState`), then only with `-R` when `refreshPeriod` is 0.
- chezmoi's external format documents `private` as "add the `private_` attribute to file or directory", without saying whether it applies to `git-repo` targets.
- Git keeps symlinks and the executable bit, but no other mode bits: a clone's files and directories get the umask of the process that clones.
- `~/.config/git/ignore` is the managed `dot_config/git/ignore` (one line today).
  `core.excludesFile` is unset, so git reads that file as the global ignore file.
- `/tmp/opencode` is mode 0775.
- After `adopt-chezmoiroot`, the source paths are under `home/`.

## Goals / Non-Goals

**Goals:**

- On a machine with GitHub access, an apply clones the store, with no location written in this repository.
- On a machine without GitHub access, or with no data, the apply goes on without the store.
- An existing store never loses local work to an apply.
- No other account on the machine can read a clone.
- Compiled spell lists never show as untracked in any repository.

**Non-Goals:**

- The content of the store, its `.gitattributes`, and how the Neovim configuration reads it (the sender's).
- Skipping the store by profile, the branch or an SSH transport: `fresh-machine-bootstrap` decides them for the Neovim external, and the same decisions then apply here.
- Pushing the store: an apply only clones or pulls.
- Restoring the 0600 modes of individual files inside the store.

## Decisions

### Data keys

The questions are `private.host` (default `github.com`), `private.owner` and `private.repo`, emitted as `[data.private]` after `[data.nvim]`, the names the sender suggested.
They sit next to the three `nvim` questions in `.chezmoi.toml.tmpl` and use `promptStringOnce`, so `chezmoi init` asks them once per machine and keeps the answers in the local config.
An empty owner or repository means no external.
Alternative considered: `store.*`. Rejected: it says less about what it is, and the sender's documentation already uses `private.*`.

### External, own file

`home/.chezmoiexternals/private-store.toml.tmpl`, separate from `nvim.toml.tmpl` so either can be read alone:

```toml
{{- $p := or (get . "private") dict -}}
{{- $owner := get $p "owner" -}}
{{- $repo := get $p "repo" -}}
{{- $host := or (get $p "host") "github.com" -}}
{{- $hasClone := stat (joinPath .chezmoi.destDir ".local" "share" "chezmoi-private" ".git") -}}
{{- $hasLogin := stat (joinPath .chezmoi.destDir ".config" "gh" "hosts.yml") -}}
{{- if and $owner $repo (or $hasClone $hasLogin) }}
[".local/share/chezmoi-private"]
  type = "git-repo"
  url = {{ printf "https://%s/%s/%s.git" $host $owner $repo | quote }}
  refreshPeriod = "0"
  pull.args = ["--ff-only"]
  private = true
{{- else if and $owner $repo }}
{{ warnf "private store: no clone and no GitHub CLI login, skipping the external" }}
{{- end }}
```

The reasons are those of the Neovim external: an offline, cheap guard, HTTPS, no `clone.args`, a pull that is fast-forward only.
Alternative considered: one shared template for both externals. Rejected: two small files are easier to read, and their profile conditions may differ later.

### Keeping a clone private

Goal: the clone root is 0700, which hides every file inside it from other accounts, whatever their modes.

1. `private = true` on the external.
   The apply session checks, in a scratch destination, that a fresh clone's root is 0700.
   It also checks that an apply on an existing clone leaves its modes as they were.
2. When chezmoi does not apply `private` to a `git-repo` target, the field is removed, and the rule is the umask 027 of `fix-chezmoi-config-template`.
   That gives a 0750 root and 0640 files, readable only by the user's private group.
   The design records the result either way.

Alternative considered: a script that runs `chmod -R go-rwx` after each apply. Rejected: scripts fall under `make-install-scripts-idempotent`, and the directory mode is enough.
Alternative considered: a git hook in the store. Rejected: hooks are not cloned.

### Global ignore for compiled spell lists

`*.add.spl` goes into `home/dot_config/git/ignore`, with a comment naming Neovim.
`zg` writes `<lang>.utf-8.add`, which projects track, and Neovim compiles it next to it as `<lang>.utf-8.add.spl`, which they must not track.
The pattern does not match `.add` files.

### First apply on this machine's store

As for `~/.config/nvim`: a read-only check first, then, with the user's go and a clean store in sync with its remote, apply the external alone once.
The check runs `git -C ~/.local/share/chezmoi-private status -sb`, then `fetch --dry-run`, then compares `HEAD` with `origin`.
The apply records the external in `gitRepoExternalState`, and later applies skip it unless `-R` is given.

### Where the requirements go

- New capability `private-store`: the store also serves the session redaction script, so it is not a Neovim setting.
- `neovim-config`, created by `fix-chezmoi-config-template`, gains the global ignore requirement.
  That change is archived first, so this delta adds to an existing spec.

## Risks / Trade-offs

- [Risk] The location reaches this public repository through a commit. → Only templates and data names are committed. A check looks for the configured owner and repository in the tracked tree and in the change's commits, printing counts only, never the values.
- [Risk] The clone test writes private data outside `$HOME`. → The test clones into a fresh `mktemp -d` directory, mode 0700, under `/tmp/opencode` (which is 0775), and deletes it right after (`test ! -e`).
- [Risk] The first pull, or a later `apply -R`, fails because the store diverged from its remote. → `--ff-only` never merges or discards; chezmoi reports the error; the user reconciles the store by hand, and the union merge of `*.add` keeps word lists easy to merge.
- [Risk] A stale GitHub CLI login lets the guard pass while the clone fails. → Same as the Neovim external: the failure is visible at apply time.
- [Risk] `private = true` is silently ignored for `git-repo`. → The scratch-destination test measures the mode; the umask fallback is recorded.
- [Risk] Two new questions in `chezmoi init` break a non-interactive init. → Same mitigation as the Neovim questions: `chezmoi execute-template --init --promptString ...` first, then `chezmoi init` in a terminal.
- [Trade-off] The sender's merge of its session S16 waits for two other changes and this one; the user accepted that on 2026-11-03.

## Migration Plan

1. After `fix-chezmoi-config-template` is archived: add the questions, run `chezmoi init` in a terminal, add the external and the ignore line.
2. Prove the skip paths and the clone path in scratch destinations, apply the ignore file alone, then apply the external alone with the user's go.
3. Rollback: remove the external template and the questions; the store stays where it is, and removing a source never deletes its target.

## Open Questions

None.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
