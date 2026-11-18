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
* Agents running key-reading clients (parked by the user on 2026-11-16, depends on the agent-harness decision).
  Document, model and translation command-line clients read a key from the environment.
  Whether an agent may run them, and how each would get a key file of its own (mode 0600) instead of the environment, is a question for the agent-harness tooling (a planned darse module or a dedicated repository) more than for the dotfiles alone.
  Until it is studied, those clients are not allowed inside agent sessions, and the wrapper change keeps them out of its scope.
* Check after the next reboot (from the credential exposure of 2026-11): a count, never a value, that the terminal, the multiplexer and the systemd user manager hold no GitHub token variable (`systemctl --user show-environment | cut -d= -f1 | grep -c`, and `grep -c` on `/proc/<pid>/environ`).
  The revoked variable stays in the user manager until then; the profile no longer sets it and new shells unset it.
* Commit identity and the history of this repository (from a fleet signal of 2026-11-16, decided by the user the same day).
  The hosting account now keeps the e-mail address private and blocks pushes that expose it; the user lifted the block, and the public history already carries the real address in every commit.
  A review of all refs (credential scanner, then the redaction tool's checks on `git log -p --all`, counts only, run from a scratch copy that was then deleted) found no credential and one private project name in early versions of a committed session export, published since 2026-10-31 and removed from the file by later re-redaction.
  Decision: accept the history as it is, no rewrite (no pull request, no fork, and a rewrite changes every commit hash that the audit, this file and the session records cite).
  The real name and address stay for new commits until the fleet strategy is decided; a study of that strategy was signalled to the coordination repository of the fleet.
  If it settles on another identity, the change is small and lives in `home/dot_config/git/gitconfig`, which is global to the machine.
  Before any other repository of the fleet goes public, the same review applies to its history.

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
4. [x] `fast-correct-shell-startup` (audit 7): silent and fast startup, archived 2026-11-16; its environment half is the proposal `correct-shell-environment` (audit 28), which has no place in this order yet and follows the study of secrets held by the desktop session below.
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
    * [ ] `port-omalap-shell-aliases` (audit 8)
    * [ ] `rationalize-package-ownership` (audit 9): also owns the mise packaging backlog above
    * [ ] `install-terminal-fonts` (audit 10)
    * [ ] `manage-kde-desktop-config` (audit 11)
    * [ ] `manage-ai-tool-configs` (audit 13)
    * [ ] `manage-dev-tui-configs` (audit 14)
    * [ ] `ignore-app-state` (audit 15)
    * [ ] `add-repo-quality-gates` (audit 17)
    * [ ] `refresh-repo-docs` (audit 18)
    * [ ] `add-agent-launch-tasks` (audit 25): after item 10, for the language rule of the global tasks.
    * [ ] `add-secret-tasks` (audit 26): after item 10, for the Python rule of the global tasks; the store external of item 9 is a soft dependency (the probe table lives in the private store).
    * [x] `add-agent-env-wrapper` (audit 27): no dependency; a shell function that starts opencode without secret-named variables, first part of the launcher decided on 2026-11-16 (the study of secrets held by the desktop session is in the follow-ups above).

Later, with no change yet: development containers and DevPod as targets, OCI images as machines, real machines reached over SSH (with cem), more distros (Debian stable, Ubuntu, Arch), RPM-based distros, Zabbly packages for Debian testing (revisit at the forky freeze, early 2027).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
