# TODO

* Add chezmoi.toml
* Use $EDITOR for commit message writing
* Add .gitconfig
* Add .config/user-dirs.{dirs,locale}
* Add .config/.nvim/
* Add .config/gtk-3.0
* Add .config/qt{5,6}ct
* Use pre-commit

## Mise packaging backlog

Tools that the install priority puts in mise and that are installed another way today.
Candidates for `rationalize-package-ownership`, which owns package ownership.

* Incus command-line tools.
  The mise registry has no `incus` entry (checked on 2026-11-07), and brew's `incus` is the client only.
  Upstream releases of `lxc/incus` ship Linux binaries named `bin.linux.incus.x86_64`, `bin.linux.incus-migrate.x86_64` and `bin.linux.incus-simplestreams.x86_64`, so mise's GitHub backend (`github:lxc/incus`) is the candidate; try it with an asset pattern.
  A client from mise would come first on `PATH` and shadow `/usr/bin/incus`, which `sys:virt:incus:setup` reports on purpose: keep it on the daemon's release line (7.0 while Kali packages 7.0.1), or leave the client to apt.
  Check whether apt's `incus-extra` already holds `incus-migrate` and `incus-simplestreams` before adding them.
  The daemon stays with apt: it is a system service that needs root.
* mise itself (backlogged by the user on 2026-11-24, after a request from cem for a newer mise).
  `~/.local/bin/mise` is installed outside any package manager and updated by hand with `mise self-update`: it went from 2026.10.23 to 2026.11.12 that day, because a pin in cem that uses the `http:` backend with `filter_bins` needs 2026.11.10.
  Nothing in this repository installs it, pins its version or declares a minimum, and a second copy from brew (`brew mise` in the Brewfile, 2026.9.5 on that date) sits later on `PATH`: it is the overlap of audit F16 in its plainest form, and `brew uses` lists nothing that depends on it.
  To decide in `rationalize-package-ownership`: how this repository owns mise (an install script of the `run_onchange_` kind on the pattern of the others, or a documented `mise self-update` step; a `min_version` in the repository `mise.toml` and in the global config), then the removal of the brew copy (the Brewfile line, then `brew uninstall mise`, which needs the user's go and is committed by the brew hook).

## Follow-ups from changes

* Desktop session open-files limit (from `make-install-scripts-idempotent`).
  `/etc/security/limits.d/ulimit.conf` reaches only PAM login sessions (TTY, ssh): the systemd user manager starts the desktop session with a soft limit of 1024 (checked on 2026-11-12 on the KDE session).
  systemd reads `~/.config/systemd/user.conf`, so a managed `[Manager]` section with `DefaultLimitNOFILE=` built from `system.limits.nofile` would raise it without sudo, from the next login.
* Krew plugins per system (from `make-install-scripts-idempotent`).
  Review `packages.darwin.krews` on the first macOS machine: colorize-managed-fields, neat and node-shell are available there, and the shared list `packages.common.krews` holds only the plugins that krew offers on all three systems.
  A Windows machine would need a PowerShell krew script.
* Secrets held by the desktop session (from the credential exposure of 2026-11, decided on 2026-11-16 not to be decided yet).
  The login profile sources the private environment file and exports its variables, and the display manager's startup imports that environment into the systemd user manager, so every process of the graphical session holds every secret-named variable: terminal, multiplexer, browser, editors, agents.
  A study should settle, before any change:
  - what reads each variable inside the desktop session, and which services need which key (the inventory of 2026-11-15 is the starting evidence: most variables have no reader at all on this machine);
  - where each key should live instead: a key file of its own with mode 0600, the keyring, or a credential helper;
  - whether the profile stops exporting them and shells source the file only in interactive shells.
  The wrapper that starts agents without them, `add-agent-env-wrapper`, protects agents and their children only: it does not replace this study.
  The proposal `correct-shell-environment` carries the profile questions of this study together with `PATH`, locale and umask; its design starts from the findings in its proposal.
  Decided on 2026-11-20: the study runs inside that change, as the first section of its work, and not as a change of its own.
  Done on 2026-11-21: the findings are in `openspec/changes/correct-shell-environment/findings.md` (counts and labels only) and the decisions in its design: the profile stops exporting the private file, a loader function exports it into the current shell on demand, and new shells unset inherited copies.
  What is left is the build of that change (its tasks), the reboot check below, and the follow-ups below.
* Per-tool keys instead of the environment (from decision 1 of `correct-shell-environment`, the target once the loader is in place).
  The Neovim AI plugin accepts a key command in its key names and none is configured, so a note goes to the orchestrator of the Neovim repository; the command-line client that has a key-command setting belongs to `manage-ai-tool-configs`; the one editor extension that reads a key from the environment has its own key setting, empty today.
  A key file of mode 0600 or the wallet (`secret-tool`, with `pam_kwallet` opening it at login) are the sources.
  The Neovim repository's orchestrator recorded the item on 2026-11-21 in its roadmap, unscheduled, the route being a decision of the user in a change of its own; it will say which route is chosen.
  Two facts from its reading of the plugin matter for that choice: a key command runs synchronously with no timeout, so a locked wallet would block the editor until the dialog is answered; and a provider switched to a key command stops reading the environment unless the plugin's shell-environment field is also set, so the loader of `correct-shell-environment` no longer helps that provider.
  Agents running key-reading clients, below, is the same question seen from the agent side.
* A managed `~/.zshenv` for non-interactive non-login zsh (from decision 4 of `correct-shell-environment`, kept out of that change on purpose).
  Ssh commands, cron and scripts would load the environment part through it.
  The review has to weigh its cost on every `zsh -c`, since the desktop login pass measures 0.23 s today.
* Agents running key-reading clients (parked by the user on 2026-11-16, depends on the agent-harness decision).
  Document, model and translation command-line clients read a key from the environment.
  Whether an agent may run them, and how each would get a key file of its own (mode 0600) instead of the environment, is a question for the agent-harness tooling (a planned darse module or a dedicated repository) more than for the dotfiles alone.
  Until it is studied, those clients are not allowed inside agent sessions, and the wrapper change keeps them out of its scope.
* Check after the next reboot (from the credential exposure of 2026-11): a count, never a value, that the terminal, the multiplexer and the systemd user manager hold no GitHub token variable (`systemctl --user show-environment | cut -d= -f1 | grep -c`, and `grep -c` on `/proc/<pid>/environ`).
  The revoked variable stays in the user manager until then; the profile no longer sets it and new shells unset it.
  The exact probe, with its expected counts before and after the deployment of `correct-shell-environment`, is `openspec/changes/correct-shell-environment/manual-steps.md` (section "Reboot check before the change is deployed"); it also counts every process, so the terminal and the multiplexer are covered.
  Done on 2026-11-23, after the reboot of 2026-11-22: the user manager holds 0 GitHub token variables and 0 of 113 readable processes hold one (the terminal and the multiplexer included); it still holds the 10 names of the private file, as expected until `correct-shell-environment` is deployed, and the opencode process of the orchestrator, started through the wrapper, holds none.
  The after-deployment values of the same probe stay to be checked, with the other live steps of that change.
* Commit identity and the history of this repository (from a fleet signal of 2026-11-16, decided by the user the same day).
  The hosting account now keeps the e-mail address private and blocks pushes that expose it; the user lifted the block, and the public history already carries the real address in every commit.
  A review of all refs (credential scanner, then the redaction tool's checks on `git log -p --all`, counts only, run from a scratch copy that was then deleted) found no credential and one private project name in early versions of a committed session export, published since 2026-10-31 and removed from the file by later re-redaction.
  Decision: accept the history as it is, no rewrite (no pull request, no fork, and a rewrite changes every commit hash that the audit, this file and the session records cite).
  The real name and address stay for new commits until the fleet strategy is decided; a study of that strategy was signalled to the coordination repository of the fleet.
  If it settles on another identity, the change is small and lives in `home/dot_config/git/gitconfig`, which is global to the machine.
  Before any other repository of the fleet goes public, the same review applies to its history.
* Bump the pre-commit hook runner (from the darse signal T-070, backlogged by the user on 2026-11-20).
  The pin is `2.10.0` in `mise.toml` (line 5) and in the two `package://` addresses of `hk.pkl` (lines 8 and 9); darse measured `2.11.1` working end to end.
  Read the release notes, change the three places together, run `mise run hooks:install` and the test suite, and check that the secret scan still runs on a commit.

## Planned order of changes

The order in which the open OpenSpec changes are applied and archived, written on 2026-11-07; tick an item when its change is archived.
It starts from the audit's change map (`docs/audits/2026-10-30-environment.md`, section 6) and differs from it on purpose in three places:

* the changes the user wants applied soon (items 4 to 10) come right after the first three;
* the Incus changes (items 11 to 13) and the guest-based stages come before the supervised apply, so that the first full apply is proven in a disposable guest before it runs on the laptop;
* `reconcile-drift-and-supervised-apply` moves behind `test-second-apply-noop` for that reason.

Items marked *planned* have no change yet; create each with `/opsx-propose` when it is next.
Once `add-repo-roadmap` is applied, its generated `ROADMAP.md` replaces this list, the packaging backlog and the older bullets move into its backlog, and this file is removed.

1. [x] `fix-chezmoi-config-template` (audit 3): the config template, encryption, umask, Neovim external, the `features.incus` question.
2. [x] `make-install-scripts-idempotent` (audit 4): after it, a full apply is allowed after a reviewed dry run.
3. [ ] `remove-brew-libvirt`: brew's libvirt, and a ban on it, on `qemu` and on brew's `incus`; first of the Incus group so that `virsh` and `incus` on `PATH` are the system ones.
4. [x] `fast-correct-shell-startup` (audit 7): silent and fast startup, archived 2026-11-16; its environment half is the change `correct-shell-environment` (audit 28), second in the rest list of item 25, which includes the study of secrets held by the desktop session below.
5. [ ] `manage-xdg-basics` (audit 12): its install script runs only after item 2.
6. [ ] `add-mise-app-desktop-entries`: after item 5 is archived, so that `mimeapps.list` has one owner.
7. [ ] `cleanup-dead-config` (audit 16): proposal and specs only, needs design and tasks.
8. [ ] `manage-gh-config` (audit 19): proposal and specs only; its install script step comes after item 2.
9. [ ] `add-private-store-external` (audit 23): after item 1.
10. [ ] `add-repo-roadmap` (audit 24): proposal and specs; replaces this file once applied.
11. [ ] `add-incus-host-setup`: the deployed task `sys:virt:incus:setup`, installed on the laptop with its acceptance checks.
12. [ ] `add-machine-lifecycle-test-infra`: the harness core for system containers; starts with a throwaway run on a hosted runner.
13. [ ] `add-incus-setup-hook`: the opt-in flag and the chezmoi hook; needs items 1, 2 and 11.
14. [ ] `fresh-machine-bootstrap` (audit 6): the first stage that applies, run in the harness of item 12.
15. [ ] `test-second-apply-noop` *planned*: a second apply in a guest changes nothing.
16. [ ] `reconcile-drift-and-supervised-apply` (audit 5): the first full apply on the laptop, after item 15.
17. [ ] `add-kali-vm-target`: the `vm` kind and the Kali VM; needs items 11 and 12.
18. [ ] `add-machine-smoke-ci`: the committed workflow and its Zabbly channel matrix; the VM job needs item 17.
19. [ ] `support-kali-vm-uefi`: a Kali VM image of our own, and the pipeline decision (distrobuilder with a fork of `lxc/lxc-ci`, or Packer); an upstream request.
20. [ ] `support-kali-vm-secure-boot`: after item 19.
21. [ ] `test-update-to-head` *planned*.
22. [ ] `test-rollback-to-previous` *planned*.
23. [ ] `test-purge` *planned*.
24. [ ] `support-omarchy` *planned*: an Arch VM with the Omarchy installer; needs item 17.
25. [ ] The rest, in the audit's order:
    * [x] `add-shell-test-harness` (audit 29): the bats suite that replaces the three scratch harnesses of the install scripts, the wrapper and the shell startup, archived 2026-11-18; first of this list on purpose (out of the audit's order), because `port-omalap-shell-aliases` and `correct-shell-environment` change the startup again and are proved by it; no dependency.
    * [ ] `correct-shell-environment` (audit 28): `PATH`, locale, umask, the load order of highlighting, the guard of `shellrc` and what the desktop login shell loads, with the study of secrets held by the desktop session as its first section (decided on 2026-11-20); second of this list on purpose (out of the audit's order), because it follows the test suite that proves it and `port-omalap-shell-aliases` changes the same startup files.
    * [ ] `add-agent-launch-tasks` (audit 25): moved on 2026-11-23 to follow `correct-shell-environment` part 1 (it was after item 10), so that workers are grouped as linked workspaces and cleaned after their export; its dependency on `add-repo-roadmap` for the language rule of the global tasks stays and must be settled in its plan lead's review: either that rule lands first, or this change carries it.
    * [ ] `port-omalap-shell-aliases` (audit 8)
    * [ ] `rationalize-package-ownership` (audit 9): also owns the mise packaging backlog above
    * [ ] `install-terminal-fonts` (audit 10)
    * [ ] `manage-kde-desktop-config` (audit 11)
    * [ ] `manage-ai-tool-configs` (audit 13)
    * [ ] `manage-dev-tui-configs` (audit 14)
    * [ ] `ignore-app-state` (audit 15)
    * [ ] `add-repo-quality-gates` (audit 17)
    * [ ] `refresh-repo-docs` (audit 18)
    * [ ] `add-secret-tasks` (audit 26): after item 10, for the Python rule of the global tasks; the store external of item 9 is a soft dependency (the probe table lives in the private store).
    * [x] `add-agent-env-wrapper` (audit 27): no dependency; a shell function that starts opencode without secret-named variables, first part of the launcher decided on 2026-11-16 (the study of secrets held by the desktop session is in the follow-ups above).

Later, with no change yet: development containers and DevPod as targets, OCI images as machines, real machines reached over SSH (with cem), more distros (Debian stable, Ubuntu, Arch), RPM-based distros, Zabbly packages for Debian testing (revisit at the forky freeze, early 2027).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
