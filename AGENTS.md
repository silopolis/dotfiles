# AGENTS.md: dotfiles

Operational digest for coding agents working in this repository.

This is the chezmoi source state of the user's Linux workstations (main machine: Kali Rolling, KDE Plasma 6 on X11, zsh, laptop).
It is the base layer of cles-en-main (`cem`, `~/Work/cles-en-main`), a workstation lifecycle tool built on chezmoi and mise.
The GitHub repository is **public**.

## Read first, in a fresh session

1. This file.
2. `openspec list`, then the change you are asked to work on under `openspec/changes/<change>/` (proposal, design, specs, tasks).
3. The findings that change cites in `docs/audits/2026-10-30-environment.md` (identifiers `F01`, `F02`, ...).
4. When the change names a cem checklist item: `~/Work/cles-en-main/migrations/2026-10-omalap-to-ulap01/checklist.md`.

## Where things live

Paths below are the flat layout; after the change `adopt-chezmoiroot`, everything chezmoi reads moves under `home/`.

| Path | Content |
| --- | --- |
| `.chezmoi.toml.tmpl` | Config template: prompts, data, encryption |
| `.chezmoidata/` | Template data: `packages.yaml`, `vscodium.yaml` |
| `.chezmoiexternals/` | Downloaded files and repositories (themes, GitAlias, Vundle, bin) |
| `.chezmoiscripts/` | `run_onchange_` install scripts |
| `.chezmoitemplates/` | Shared template snippets |
| `.chezmoiignore`, `.chezmoiremove` | Target ignore and removal lists (patterns match targets, not source paths) |
| `dot_config/`, `dot_local/`, root `symlink_dot_*` | Managed files; `~/.zshrc`, `~/.bashrc`, `~/.profile`, `~/.gitconfig` are symlinks into `~/.config` |
| `dot_config/shell/` | Shared bash and zsh startup: `profile`, `shellrc`, `rc.d/NNN-*.sh`, `aliases` |
| `docs/audits/` | Dated audits; the 2026-10-30 one is the consolidation baseline |
| `openspec/` | Specs (`specs/`), active and archived changes (`changes/`), `config.yaml` |
| `memory/sessions/` | Redacted transcripts of agent sessions, public profile; see its `README.md` |
| `.opencode/` | OpenSpec commands and skills for opencode |

Not here: Neovim (`~/.config/nvim`, its own repository).

## Commands

- `chezmoi status` and `chezmoi diff --exclude=externals`: what an apply would change.
- `chezmoi apply --dry-run --verbose`: full preview, scripts included.
- `chezmoi apply --exclude=scripts <target>`: apply one target without running scripts.
- `chezmoi execute-template < file.tmpl` and `chezmoi cat <target>`: render a template or a target.
- `chezmoi managed`, `chezmoi unmanaged <dir>`, `chezmoi doctor`.
- `zsh -n <file>`, `bash -n <file>`, `shellcheck <file>`: shell checks.
- `openspec validate --all --strict`: check specs and changes.
- `mise run hooks:install`: after a fresh clone, install the pre-commit secret scan as a `.git/hooks` shim, which every git version runs.
- Startup time: `for i in 1 2 3; do /usr/bin/env time -f %e zsh -i -c exit; done` (or `date +%s.%N` around the call when GNU time is missing).
- chezmoi comes from brew, and minimal non-interactive shells (ssh command, cron, `env -i`) do not load brew, so they do not find it.
  Run `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` first, or call `/home/linuxbrew/.linuxbrew/bin/chezmoi`.
  This holds until `fast-correct-shell-startup` fixes bash login startup (F22).

## Safety rules

- Never run a full `chezmoi apply` without reviewing `chezmoi apply --dry-run --verbose` with the user first; until `make-install-scripts-idempotent` is archived, do not run one at all.
- Apply single targets with `--exclude=scripts`.
- Edit the source, never the target, for managed files; bring live edits back with `chezmoi re-add` after a diff review.
- Never print, log or commit secret values; encrypted files are added with `chezmoi add --encrypt` and keep the `private_` attribute.
- Raw session exports contain private data: keep them in a scratch directory with mode 0700, commit only the redacted copies in `memory/sessions/`, and delete the raw files.
- Anything that uses sudo, writes outside `$HOME`, uninstalls or deletes needs the user's explicit go.
- Commits: propose the messages, commit only after the user validates them, never push without being asked.
- The brew hook (`dot_config/shell/rc.d/110-pkg_brew.sh`) commits the Brewfile by itself after brew changes: expect those commits.

## Writing for a public repository

- No secret values, no names of secret variables, no token scopes, no private hosts or IP addresses, no employer or client details.
- Open security issues are described in general terms, with a command that shows the details locally.
- The same rule applies to cem, which will become public too.
- Sibling repositories: name only those that are public or meant to be (darse, cem, bosco, greffe, the Neovim configuration repository); call any other "a fleet repository".
  A file that is committed here is public, so a private repository is not named even to say that it is private.

## Conventions

- Commits: `type(domain:subject): imperative lowercase summary`, English, subject at most 80 characters; domains in use include `shell`, `pkg`, `dev`, `term`, `git`, `chezmoi`, `sys`, `editor`, `kde`; for this repository's own process use `chezmoi:spec`, `chezmoi:audit`, `chezmoi:docs`.
- Markdown: one sentence per line, no em or en dashes, no emoji, sentence-case headings, vim modeline as the last line.
- Shell: POSIX-compatible where both bash and zsh source the file; shell-specific code goes in `case "$CURRENT_SHELL"` blocks.
- Install priority for tools: mise, brew, apt, vendor APT repository, Flatpak; GitHub `.deb` releases through bin.

## Workflow

One OpenSpec change per working session.
`/opsx-apply <change>` to implement, `/opsx-verify <change>` to check, `/opsx-archive <change>` when done; then tick the cem checklist line named in the audit's change map.
New work starts with `/opsx-propose` or `/opsx-explore`.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
