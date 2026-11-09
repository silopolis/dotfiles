# Environment audit, 2026-10-30

Baseline audit of this chezmoi repository and of the home environment it deploys, taken on the main laptop after a year on another machine.
Every OpenSpec change under `openspec/changes/` refers to the findings below by their identifier (`F01`, `F02`, ...).

This repository is public.
This document holds no secret values, no names of secret variables, no private hosts and no employer or client details.
Where a finding concerns secrets, it gives a command that reveals the details locally.

## How to read this

- Paths are relative to the repository root as it was on 2026-10-30, before the change `adopt-chezmoiroot`.
  After that change, prefix every source path with `home/`.
- Line numbers were checked on commit `191ee9e`; later changes may shift them, so search for the quoted text if a line moved.
- Everything was collected read-only: `chezmoi status`, `chezmoi diff`, `chezmoi doctor`, `chezmoi managed`, `chezmoi unmanaged`, `chezmoi execute-template`, package manager listings, and timings.
- Severity: **high** (data loss, unsafe operation or broken setup), **medium** (wrong behaviour or real friction), **low** (cleanup).

## 1. Context

- Machine: laptop running Kali Rolling 2026.3, KDE Plasma 6.7 on X11, login shell zsh, Homebrew (linuxbrew), mise, pipx, apt.
- The user came back to it after a year on an Omarchy (Arch, Hyprland) laptop called `omalap`, which was wiped on 2026-10-30.
- The move is tracked in the private repository cles-en-main (`cem`), file `migrations/2026-10-omalap-to-ulap01/checklist.md`; this audit cites its item numbers (for example "checklist 4.1").
- cem is meant to become a workstation lifecycle tool built on chezmoi and mise; this repository is its base layer and will be partly superseded by it.
- Repository state: branch `main` in sync with `origin/main`, clean tree, 297 commits, 883 managed targets.
- chezmoi: v2.62.2 in `~/.local/bin` (first on `PATH`), v2.72.1 from brew, latest upstream v2.73.3.

## 2. Architecture refresher

### 2.1 Config template and data

| File | Role |
| --- | --- |
| `.chezmoi.toml.tmpl` | Prompts once for email, git email, first name and name; includes `cpu`, `machine-type` and `gh-codespaces` from `.chezmoitemplates/`; sets pager, `[git]`, `[env]` (brew-file variables), `[diff]`, `[merge]`, empty `[hooks.apply.*]` |
| `.chezmoitemplates/cpu.toml.tmpl` | `data.cpu.cores` and `threads` from `lscpu` |
| `.chezmoitemplates/machine-type.toml.tmpl` | `data.machine.type` from `hostnamectl` chassis (default `desktop`) |
| `.chezmoitemplates/gh-codespaces.toml.tmpl` | `data.github.is_codespaces` |
| `.chezmoitemplates/os.toml.tmpl`, `profile.toml.tmpl` | Distro, WSL, Steam Deck, headless and ephemeral detection; **never included** |
| `dot_config/chezmoi/chezmoi.toml.tmpl` | A rendered snapshot of the config (July 2025, another machine) plus the age block, deployed over `~/.config/chezmoi/chezmoi.toml` |
| `.chezmoidata/packages.yaml` | krew plugins (7) and darwin brews and casks; the `dpkgs`, `brews`, `pipxs`, `bins` keys are empty |
| `.chezmoidata/vscodium.yaml` | About 30 VSCodium settings and 70 extension IDs |

No template reads `.email`, `.gitemail`, `.name`, `.firstname`, `.cpu`, `.machine` or `.github`.

### 2.2 Encryption

- age, identity `~/.config/chezmoi/key.age`.
- The identity is stored passphrase-encrypted in `key.txt.age` (ignored as a target) and decrypted by `.chezmoiscripts/run_onchange_before_decrypt-private-key.sh.tmpl` when missing.
- Four encrypted targets are deployed: list them with `chezmoi managed --include=encrypted`.

### 2.3 Scripts

| Script | Trigger | Does |
| --- | --- | --- |
| `run_onchange_before_00-pre-requesites.sh.tmpl` | its own content (effectively once) | `sudo apt-get` install of build tools, btrfs and snapper tools, `git-credential-oauth`; no distro guard |
| `run_onchange_before_05-install.sh.tmpl` | Brewfile and pipx `packages.json` hashes | open-files limit with sudo, Homebrew install, `brew file install`, `brew file clean`, `rustup default stable`, `pipx install-all`, Vundle `PluginInstall`, YouCompleteMe build, `gh auth login`, `gh extension install github/gh-copilot` |
| `run_onchange_before_10-install-packages.sh.tmpl` | `packages.yaml` hash | `kubectl krew install` (darwin: `brew bundle`) |
| `run_onchange_before_decrypt-private-key.sh.tmpl` | its own content | age identity, see 2.2 |
| `run_onchange_after_20-vscodium-extensions.sh.tmpl` | extension list hash | installs missing extensions, then every `.vsix` in `~/.local/share/vsix/` |
| `run_onchange_after_bat-cache-build.sh.tmpl` | its own content (hash line broken) | `bat cache --build` |

`scripts/install.sh` is a stock chezmoi bootstrap (ignored as a target); `dot_local/sbin/executable_syssetup.sh` is a second, buggy one.

### 2.4 Packages

| Manager | Declared in | Declared vs installed |
| --- | --- | --- |
| brew | `dot_config/brewfile/Brewfile` (160 formulae, about 30 taps) | 160 = 160; cask `whosthere` installed but not declared |
| mise | `dot_config/mise/config.toml` (45 tools: aqua, github, cargo, npm, pipx backends) | 45 = 45; 48 unreferenced old versions (`mise prune --dry-run`) |
| pipx | `dot_config/pipx/packages.json` (23) | 28 installed: calcure, euporie, hike, ipython, pynvim undeclared |
| krew | `.chezmoidata/packages.yaml` (7) | 7 = 7 |
| VSCodium | `.chezmoidata/vscodium.yaml` (70) | 71 installed: `sitoi.ai-commit` comes from a local `.vsix` |
| bin | external `.chezmoiexternals/bin.toml.tmpl` (v0.21.2) | latest 0.29.4 |
| flatpak | none | no apps |

The Brewfile is written by brew-file; `_post_brewfile_update` in `dot_config/shell/rc.d/110-pkg_brew.sh:63-91` re-adds it to the source and commits it after each brew change.

### 2.5 Externals

Twelve files in `.chezmoiexternals/`, all reachable on 2026-10-30, weekly refresh unless noted: Catppuccin themes for bat, btop, broot, delta, kubecolor, LXQt and qterminal, vifm colors; GitAlias; kubectl-aliases; community cheatsheets; Vundle; `bin` (pinned, no refresh); `cnf` (entirely commented out).

### 2.6 Shell startup

```text
zsh, interactive non-login:
  ~/.zshrc -> .config/shell/shellrc -> rc.d/*.sh
zsh, login (also every new tmux pane):
  ~/.zprofile -> .config/shell/profile -> .config/zsh/zshrc -> shellrc -> rc.d/*.sh
  ~/.zshrc -> shellrc -> rc.d/*.sh            (second full pass)
bash, interactive non-login:
  ~/.bashrc -> shellrc -> rc.d/*.sh
bash, login:
  ~/.profile -> .config/bash/bashrc -> $XDG_CONFIG_HOME/shell/shellrc
```

`rc.d` order: 000-050 environment, XDG and `PATH`; 110-150 package managers (brew, aqua, flatpak, snap, krew); 200-220 languages; 310-350 shell options, history, completion, suggestions, keys; 400-440 tools (command-not-found, direnv, mise, broot, fzf, zoxide, hstr, languagetool); 800 aliases; 910-930 prompt pieces and syntax highlighting; 990 starship.
No plugin framework: zsh-autosuggestions and zsh-syntax-highlighting come from apt.
Shell differences go through `CURRENT_SHELL` (from `ps`) and `case` blocks.
`dot_config/envrc` holds plain variables; the encrypted `~/.config/env` holds tokens and is sourced by `rc.d/010-env_user.sh`.

### 2.7 Managed application configs

alacritty, aspell, bat, bottom, broot, btop, cheat, fabric (234 vendored patterns), fonts.conf, gh, gh-copilot, git (delta, difftastic, GitAlias), hunspell, kitty, kube (via externals), lazygit, lsd, mise, pipx, qterminal, starship, tlrc, tmux (TPM from brew, Catppuccin, resurrect), vifm, vim (Vundle), VSCodium (settings merged by `modify_settings.json`), Joplin (two symlinks into a cloud-synced folder), Dolphin service menus, `~/.face`.

### 2.8 Not managed

- Neovim: `~/.config/nvim` is its own repository (LazyVim, OpenSpec).
- KDE Plasma: kdeglobals, kwinrc, kglobalshortcutsrc, konsolerc, dolphinrc, katerc, krunnerrc, power and lock settings, panel layout.
- XDG basics: `user-dirs.dirs`, `user-dirs.locale`, `mimeapps.list`, `autostart/`, `gtk-3.0/bookmarks`, `fontconfig/fonts.conf`.
- AI tools: opencode, claude, goose, agents, mods, shell_gpt.
- Terminal tools: k9s, lazydocker, nnn, ranger, superfile, htop, glow, fastfetch, gh-dash, helm, gitui.

### 2.9 Conventions

- Commits: `type(domain:subject): imperative lowercase summary`; types feat (196), fix (51), chore (45), docs, ai, tmp; domains `dev`, `shell`, `pkg`, `chezmoi`, `term`, `sys`, `mon`, `git`, `editor`, `kde`.
- Only one agent guide existed (`dot_config/tmux/AGENTS.md`), and it is deployed to `~/.config/tmux`.

## 3. Status on 2026-10-30

```text
 R .chezmoiscripts/05-install.sh            Brewfile and packages.json changed since its last run (2025-12-01)
 R .chezmoiscripts/20-vscodium-extensions.sh new, never run
MM .config/lazygit/config.yml
 M .config/VSCodium                          mode 0700 -> 0775
 M .config/brewfile/Brewfile                 mode 0644 -> 0664
MM .config, .local/share/fonts, .local/share/icons, three LXQt theme dirs (modes)
```

- A full `chezmoi apply` has been avoided on purpose since 2026-10-26 because of `F01`.
- Shell startup measured with `zsh -i -c exit`: 2.5 s (2.5 to 3.6 s over runs); `zsh -l -i -c exit`: 7.0 s.
- `chezmoi doctor`: newer version available, suspicious entry `dot_config/chezmoi/chezmoi.toml.tmpl`.

## 4. Findings

### High

- **F01**: re-running `05-install` is unsafe.
  - Lines 15-16 overwrite `/etc/security/limits.d/ulimit.conf` with 20480/40960, lower than the live 32768/65536.
  - Line 41 runs `brew file clean`, which is not a dry run: it uninstalls undeclared packages (today the `whosthere` cask), untaps, and empties the brew cache.
  - Lines 75-79 run `vim +PluginInstall` before Vundle and the vimrc are deployed (before script), then a full YouCompleteMe build.
  - Line 81 may start an interactive `gh auth login`; line 82 reinstalls the deprecated gh-copilot extension under `set -e`.
  - Lines 18 and 73 hard-code the source directory path.
- **F02**: trigger lines that never trigger.
  `05-install.sh.tmpl:5` (mise config) and `bat-cache-build.sh.tmpl:5` (bat config) escape the braces (`\{\{ ... \}\}`), so they are comments and edits never re-run the scripts.
  The mise block of `05-install` (lines 52-68) is commented out, so nothing runs `mise install`.
- **F03**: `dot_config/chezmoi/chezmoi.toml.tmpl` is a frozen rendered config applied over the generated one.
  It carries stale data (4 cores, 8 threads, `desktop`, where a fresh render gives 6, 12 and `laptop`) and is the only place encryption is configured.
- **F04**: a fresh `chezmoi init --apply` cannot decrypt.
  `.chezmoi.toml.tmpl` has no `encryption` or `[age]` section, so encrypted targets fail until the snapshot of `F03` is deployed.
- **F05**: `~/.config/nvim` had a single copy (no remote, uncommitted work).
  A private remote is being created on 2026-10-30; the repository should then come in as a chezmoi external.
- **F06**: zsh login shells run `rc.d` twice (2.6 diagram), 7.0 s instead of 2.5 s, with duplicate side effects (banners, completions, `PATH` work).
  tmux starts login shells, so every new pane pays it.

### Medium

- **F07**: `.chezmoi.toml.tmpl:51` writes `diff.exclude` inside `[diff]`, giving the key `diff.diff.exclude`; `chezmoi dump-config` shows `diff.exclude: []`.
- **F08**: `.chezmoi.toml.tmpl:16-18` (`pager`, `color`) come after the tables emitted by the included templates, so they land in `[data.github]`; the effective pager is `less`.
- **F09**: `.chezmoi.toml.tmpl:30` uses `promptString` (asks on every init) without `quote` for a commit message template that is unused (`autoCommit = false`).
- **F10**: at least one encrypted target is deployed group-readable because its source name lacks `private_`.
  Lookup: `chezmoi managed --include=encrypted --path-style=absolute | xargs stat -c '%a %n'`.
- **F11**: two chezmoi binaries; the older one (`~/.local/bin`, 2.62.2) wins on `PATH`.
- **F12**: this public repository has no secret scanning, neither in history nor at commit time.
- **F13**: with umask 002, chezmoi would make managed directories and files group-writable (`~/.config`, `~/.local/share/fonts`, `icons`, LXQt theme dirs) and open `~/.config/VSCodium` from 0700 to 0775; the Brewfile shows a mode-only diff after each brew change (brew-file writes 0644).
- **F14**: lazygit 0.65 migrated the live `~/.config/lazygit/config.yml` to its new schema (`git.diffRenderers`, `command`, `type: extDiff`); the source still has the old `git.pagers` and `externalDiffCommand`, so every apply reverts it and lazygit rewrites it again.
- **F15**: deployed-only files inside managed folders: `~/.config/shell/rc.d/060-libvirt.sh` (sets the default libvirt URI, never committed), `rc.d/190-env_path_user.sh` (stale copy of `050` from before a rename; it puts `~/.local/{bin,sbin}` on `PATH` twice), `~/.config/bash/bashrc.original`, `~/.config/zsh/zshrc.bak`.
- **F16**: package drift and overlap: 48 stale mise versions with shims; 5 undeclared pipx apps; undeclared `whosthere` cask; tools present in both brew and mise (age, node, kubectl, k9s, stern, lazydocker, shellcheck, pre-commit, bat, direnv); mise `npm:` tools rely on brew's node; `pipx` itself from brew while mise also has a `pipx:` backend.
- **F17**: kitty, alacritty and qterminal use `VictorMono NF`, and lazygit expects Nerd Font v3 icons, but no Nerd Font is installed (`fc-list | grep -ci nerd` gives 0).
- **F18**: `PATH` quality.
  `rc.d/040-env_path_base.sh:9` replaces `PATH` wholesale; `~/.local/bin` ends up behind rustup, krew and brew; about 70 entries (mise adds one per tool); `rc.d/120-pkg-aqua.sh:5` appends `/bin` to `AQUA_BIN_DIR` on every nested shell.
- **F19**: slow startup work, measured one by one: `localstack completion` (`aliases:444`) about 1 s, `brew completions link` (`110-pkg_brew.sh:32`) 0.44 s, four `chezmoi source-path` calls (`aliases:173-181`) about 0.37 s, `minikube` (`aliases:376`) 0.2 s, `kubectl` (`aliases:327`) 0.13 s, `gh` (`aliases:250`) 0.09 s, `direnv hook` 0.08 s, `kind` (`aliases:407`) 0.07 s, `glab` (`aliases:254`) 0.05 s.
- **F20**: `aliases:304` calls `infracost completion --shell`, a flag that no longer exists: an error on every shell start.
- **F21**: `rc.d/020-env_defaults.sh:4-6` defaults `LANG` to `en_US.UTF-8`, which is not generated on this machine, and `LC_ALL` to `fr_FR.UTF-8`, which overrides everything (bash `setlocale` warnings; the `LANG=C man` alias has no effect).
- **F22**: bash login shells on a bare TTY or over SSH load nothing: `dot_config/bash/bashrc:12` tests `$XDG_CONFIG_HOME` before it is set; bash also errors on the empty `completions.d/*.sh` glob (`rc.d/330-shell_completion.sh`).
- **F23**: the encrypted environment file exports all API tokens into every shell and therefore into every child process, AI agents included.
- **F24**: machine-specific assumptions: `00-pre-requesites` uses apt with no distro guard; the decrypt script hard-codes `/home/tarax`; `/home/linuxbrew` is hard-coded in `05-install`, `rc.d/110`, `aliases:293-294`, the gitconfig credential helper and the tmux TPM path.
- **F25**: bootstrap scripts: `scripts/install.sh:9,11` download from the `git.io` shortener; `dot_local/sbin/executable_syssetup.sh:8,14` test `$(type ...)`, which is always empty, so both branches are inverted, and line 6 fails under `set -u` without an argument.
- **F26**: dead or unused template material: `os.toml.tmpl` (declares `$osid` twice) and `profile.toml.tmpl` are never included; the prompted identity and computed data are never read; `gitconfig` hard-codes the identity instead of using the data; `packages.yaml` has four empty keys.
- **F27**: `20-vscodium-extensions.sh.tmpl:23-26` reinstalls every `.vsix` on each run; the `.vsix` files live outside the repository; the comment at `.chezmoidata/vscodium.yaml:1` names a `.tmpl` file that does not exist.
- **F28**: the `bin` external is pinned to v0.21.2 with no refresh while bin itself can self-update.

### Low

- **F29**: `.chezmoiignore` entries that do nothing: `.chezmoiscripts`, `.chezmoidata`, `.chezmoitemplates` (special files are never targets), `dot_config/tmux/plugins` (a source path, while patterns match targets), `.config/alacritty/alacritty.yml`, `.config/alacritty/themes`, `.config/brew`; `.chezmoiremove` lists `.bashrc.original`, already removed.
- **F30**: leftovers: `dot_config/vim/vimrc.bak` and `dot_config/pipx/packages.json.bak` (both deployed), untracked `dot_config/brewfile/.Brewfile.swp`, dead `dot_config/tmux/tmuxline.conf`, unused `dot_config/alacritty/colors.toml` and copied `README.md`, commented-out `cnf` external.
- **F31**: configs for tools that are absent or deprecated: qterminal (not installed; `HistoryLimitedTo` is set from `.chezmoi.gid`), hunspell (dictionary only), gh-copilot (extension retired upstream, config and extension still present).
- **F32**: broken or risky aliases and functions in `dot_config/shell/aliases`: `aptu` (line 110, not an apt command), `genpw` (line 123, needs the missing `pwgen`, uses `tee -p`), `lt` and `check_language` (missing `pylanguagetool`), `icat` (line 266, shadows The Sleuth Kit's `icat` on Kali), `k` defined twice (348, 350), `AWS_PAGER` not exported (425), `vbx_create` bad substitution (487), `convert_to_png` `$&` (539), `egrep` and `fgrep` aliases, `br` defined twice.
- **F33**: minor shell points: syntax highlighting (930) is not loaded last; compinit runs twice (`/etc/zsh/zshrc` and `rc.d/330`) because `skip_global_compinit` is not set; `HISTFILE` outside XDG; `echo` banners on every start (`shellrc:11` prints an empty shell name in non-login shells); `shell/environment` is unused; `130` and `200-lang_python` are empty; `005` and `995` are profiling stubs; `shellrc` has its interactive guard commented out.
- **F34**: docs: `README.md` is a stub, `TODO.md` is outdated, `dot_config/tmux/AGENTS.md` no longer matches `tmux.conf`.
- **F35**: externals: `delta` fetches `catppucin.gitconfig` (typo) that nothing includes; LXQt targets use `catpuccin`; several upstreams have not moved since 2024 (catppuccin lxqt and qterminal, vifm-colors, cheatsheets, kubecolor-catppuccin).
- **F36**: valuable configs not managed (2.8).
- **F37**: bulk copies: 234 fabric patterns (1.9 MB) vendored from upstream; the 2000-line stock `kitty.conf` with about 25 active lines.
- **F38**: the Joplin symlinks use absolute paths into a cloud-synced folder, which also syncs the whole Joplin profile, caches and database included.
- **F39**: terminal remote control is open to any process running inside kitty (`allow_remote_control yes`).
- **F40**: git: credential helper with an absolute brew path, `remote-open` and `branches` aliases use macOS `open`, `lg` defined twice in `mygitalias`, unused `git-coauthors` and empty `gitmessage`, mixed indentation; checklist 4.2 (omalap git defaults) looks covered by commit `d624901` and needs a check.
- **F41**: the brew hook commits the Brewfile but leaves its mode as brew-file wrote it, so `chezmoi status` keeps a mode-only entry.

## 5. Decisions taken on 2026-10-30

- Work is planned and tracked with OpenSpec only (same workflow and `/opsx-*` commands as the Neovim repository).
- The source state moves into `home/` (`.chezmoiroot`) early, so repository files (`openspec/`, `docs/`, `AGENTS.md`, tooling) sit outside chezmoi's scope.
- chezmoi deploys with `umask = 0o027`: directories 0750, files 0640, nothing readable by other local users.
  The shell's own umask is decided separately in `fast-correct-shell-startup`.
- Neovim stays its own repository and is cloned by a chezmoi `git-repo` external with `refreshPeriod = 0` (clone once, never pull over local work), skipped when GitHub authentication is missing.
- Both this repository and cem are written as if public.
- One chezmoi binary, from brew for now; moving it to mise is part of `rationalize-package-ownership`.
- No full `chezmoi apply` until `make-install-scripts-idempotent` is done; the first one is supervised (`reconcile-drift-and-supervised-apply`).

## 6. Change map

| Order | Change | Findings | cem checklist | Detail on 2026-10-30 |
| --- | --- | --- | --- | --- |
| 0 | `bootstrap-spec-workflow` | process | | done, archived |
| 1 | `harden-sensitive-targets` | F10, F11, F12, F05 (check) | | done, archived 2026-10-31 |
| 2 | `adopt-chezmoiroot` | layout | | full |
| 3 | `fix-chezmoi-config-template` | F03, F04, F07, F08, F09, F13, F41 | | done, archived 2026-11-08 |
| 4 | `make-install-scripts-idempotent` | F01, F02, F24 (scripts), F27 | | full |
| 5 | `reconcile-drift-and-supervised-apply` | F13, F14, F15 | Later steps: supervised full apply | full |
| 6 | `fresh-machine-bootstrap` | F04, F05, F24, F25, F26, F38 | cem task T-012 | proposal, specs, draft tasks |
| 7 | `fast-correct-shell-startup` | F06, F18 to F23, F33 | | proposal, specs, draft tasks |
| 8 | `port-omalap-shell-aliases` | F32 | 4.1 | proposal, specs, draft tasks |
| 9 | `rationalize-package-ownership` | F16, F28 | 4.5, 6.1, 6.6, Later steps: brew to mise | proposal, specs, draft tasks |
| 10 | `install-terminal-fonts` | F17 | 6.3 | proposal, specs, draft tasks |
| 11 | `manage-kde-desktop-config` | F36 | Later steps: KDE preferences | proposal, specs |
| 12 | `manage-xdg-basics` | F36 | | proposal, specs |
| 13 | `manage-ai-tool-configs` | F36 | 5.5 (configs only) | proposal, specs; rtk hides passing-commit hook output, added 2026-10-31 |
| 14 | `manage-dev-tui-configs` | F36 | | proposal, specs |
| 15 | `ignore-app-state` | F36 | | proposal, specs |
| 16 | `cleanup-dead-config` | F29, F30, F31, F35, F37, F39, F40 | 4.2 (check) | proposal, specs |
| 17 | `add-repo-quality-gates` | process | | proposal, specs |
| 18 | `refresh-repo-docs` | F34 | | proposal, specs |
| 19 | `manage-gh-config` | F01, F31 (gh part) | | proposal, specs; added 2026-10-31 on request |
| 20 | `enforce-hook-with-system-git` | F12 (regression after archive) | | done, archived 2026-11-06; added 2026-10-31, suggested early (before order 2); applied 2026-11-06 (shim through `hk install --legacy`); darse `T-065` (open, on its own branch) reads the outcome from this change's `design.md`, nothing written to darse |
| 21 | `adopt-global-mise-tasks` | 2.7 (mise) | | done, archived 2026-11-02; added the same day on request of the Neovim repository |
| 22 | `fix-prompt-delivery` | 2.7 (mise) | | superseded 2026-11-04 by `add-agent-launch-tasks` (row 25); it was added 2026-11-03 on request of the Neovim repository and never applied; its follow-up (default setting and override flag for the timeouts and limits) moved with it |
| 23 | `add-private-store-external` | F05, 2.8 | | full; added 2026-11-03 on request of the Neovim repository; after orders 2 and 3; the Neovim session S16 merged without it |
| 24 | `add-repo-roadmap` | F34, process | | proposal, specs, brief; added 2026-11-03 on request, reworked 2026-11-04 (generated `ROADMAP.md`, global task `openspec:roadmap`); once applied, `ROADMAP.md` replaces this table and `TODO.md`, and this section is frozen |
| 25 | `add-agent-launch-tasks` | 2.7 (mise), process | | proposal, specs; added 2026-11-04 on request; replaces `fix-prompt-delivery`; after 24 (the language rule for the global tasks) |
| 26 | `add-secret-tasks` | 2.1, F10, F11, F12 | | proposal, design, specs, tasks; added 2026-11-09 on request of the Neovim repository's orchestrator; global tasks `secret:check` and `secret:rotate` for the encrypted environment file, probe table in the private store; after 24 (the Python rule), soft dependency on 23 |

Changes 6 to 20 refine their artifacts at the start of their own session (`/opsx-continue`).

## 7. Working a change in a fresh session

1. `cd ~/.local/share/chezmoi`, read `AGENTS.md`, run `openspec list`.
2. Read this document's findings cited by the change, then `/opsx-apply <change>` (or `/opsx-continue <change>` when tasks are still drafts).
3. Re-check facts before acting: line numbers and versions drift.
4. Propose commits to the user; commit only after validation.
5. `/opsx-archive <change>`, then tick the cem checklist line named in section 6.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
