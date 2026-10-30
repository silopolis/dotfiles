## Context

- `scripts/install.sh:9,11` downloads from `git.io`; line 23 passes `--source=<directory of the script>`, which is `scripts/`, not the repository.
- `dot_local/sbin/executable_syssetup.sh`: `[ $(type curl &>/dev/null) ]` is always false (lines 8, 14), so curl is never installed and chezmoi's branches are swapped; line 6 fails under `set -u` without an argument.
- `.chezmoitemplates/os.toml.tmpl` computes `$osid`, WSL and Steam Deck flags but emits nothing; `profile.toml.tmpl` declares unused booleans.
- Literal paths: `dot_config/git/gitconfig:45,48` (`gh` credential helper), `dot_config/tmux/tmux.conf:199` (TPM), `dot_config/symlink_Joplin` and `symlink_joplin-desktop` (absolute targets under a cloud-synced folder), `dot_config/shell/aliases:293-294` (terraform completion), `dot_config/shell/rc.d/110-pkg_brew.sh:2,17`.
- Neovim lives in `~/.config/nvim` (LazyVim, OpenSpec), private remote created on 2026-10-30.
- cem `T-012` plans profiles (desktop, mobile) next to machine and distro, read by `cem settings` (`DR-005`).
- The age identity needs a passphrase at first apply; a container test cannot have it.

## Goals / Non-Goals

**Goals:**

- `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply silopolis` (or `scripts/install.sh` from a clone) works on a clean Debian-family system.
- Templates read machine facts from data, not from literals.

**Non-Goals:**

- Non-Debian distros beyond guards (Arch or Omarchy restore is cem `T-011`).
- Choosing the package manager per tool (change `rationalize-package-ownership`).

## Decisions

### Data schema (first cut, refined with cem `T-012`)

```toml
[data.os]       # id = "kali", like = ["debian"], wsl = false
[data.machine]  # type = "laptop", cpu = { cores = 6, threads = 12 }
[data]          # profile = "mobile"  (promptChoiceOnce: desktop, mobile, server, ephemeral)
[data.brew]     # prefix = "/home/linuxbrew/.linuxbrew"
```

### Neovim external

```toml
[".config/nvim"]
  type = "git-repo"
  url = "https://github.com/<owner>/<repo>.git"
  refreshPeriod = "0"
  clone.args = ["--branch", "dev"]
  pull.args = ["--ff-only"]
```

`refreshPeriod = 0` means chezmoi clones when the directory is missing and never pulls; updates stay a git operation in the repository.
Guard: wrap the entry in a template condition on a data flag (`nvim.external`, default true) and on `gh auth status` succeeding (`output` in the external template), so a machine without GitHub access still applies.
Alternative considered: a `run_once` script cloning the repository; rejected, the external is declarative and visible in `chezmoi managed`.

### Container test

A `podman` (or `docker`) Debian or Kali image, running the bootstrap with `--exclude=encrypted` and a non-interactive profile; success is a zero exit and an empty `chezmoi status --exclude=encrypted`.
Brew in a container is slow; the test may set `CHEZMOI_SCRIPTS_DRY_RUN=1` for package scripts in a first stage.

## Risks / Trade-offs

- [Risk] Templating plain files changes their output subtly. → `chezmoi diff` must be empty on this laptop after each conversion.
- [Risk] `chezmoi apply --refresh-externals` (or `-R`) pulls into the Neovim working copy. → `pull.args = ["--ff-only"]` refuses anything but a fast-forward; documented in `AGENTS.md`.
- [Risk] A private-repository external fails during `apply` and aborts it. → Guard as above; test in an environment without GitHub authentication.
- [Risk] Profile values chosen here conflict with cem `T-012`. → Keep the schema minimal and record it in cem before implementing.

## Open Questions

- Profile names and how many (cem `T-012`).
- Keep `syssetup.sh` (system bootstrap with apt) or fold it into `scripts/install.sh`?
- Does the btrfs and snapper part of the apt prerequisites belong to a `btrfs` machine flag?

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
