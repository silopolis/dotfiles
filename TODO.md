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

## Planned order of changes

The order in which the open OpenSpec changes are applied and archived, written on 2026-11-07; tick a line when its change is archived.
It starts from the audit's change map (`docs/audits/2026-10-30-environment.md`, section 6) and differs from it on purpose in three places:

* the changes the user wants applied soon (lines 4 to 10) come right after the first three;
* the Incus changes (lines 11 to 13) and the guest-based stages come before the supervised apply, so that the first full apply is proven in a disposable guest before it runs on the laptop;
* `reconcile-drift-and-supervised-apply` moves behind `test-second-apply-noop` for that reason.

Lines marked *planned* have no change yet; create each with `/opsx-propose` when it is next.
Once `add-repo-roadmap` is applied, its generated `ROADMAP.md` replaces this list.

1. [ ] `fix-chezmoi-config-template` (audit 3): the config template, encryption, umask, Neovim external, the `features.incus` question.
2. [ ] `make-install-scripts-idempotent` (audit 4): after it, a full apply is allowed after a reviewed dry run.
3. [ ] `remove-brew-libvirt`: brew's libvirt, and a ban on it, on `qemu` and on brew's `incus`; first of the Incus group so that `virsh` and `incus` on `PATH` are the system ones.
4. [ ] `fast-correct-shell-startup` (audit 7).
5. [ ] `manage-xdg-basics` (audit 12): its install script runs only after line 2.
6. [ ] `add-mise-app-desktop-entries`: after line 5 is archived, so that `mimeapps.list` has one owner.
7. [ ] `cleanup-dead-config` (audit 16): proposal and specs only, needs design and tasks.
8. [ ] `manage-gh-config` (audit 19): proposal and specs only; its install script step comes after line 2.
9. [ ] `add-private-store-external` (audit 23): after line 1.
10. [ ] `add-repo-roadmap` (audit 24): proposal and specs; replaces this list once applied.
11. [ ] `add-incus-host-setup`: the deployed task `sys:virt:incus:setup`, installed on the laptop with its acceptance checks.
12. [ ] `add-machine-lifecycle-test-infra`: the harness core for system containers; starts with a throwaway run on a hosted runner.
13. [ ] `add-incus-setup-hook`: the opt-in flag and the chezmoi hook; needs lines 1, 2 and 11.
14. [ ] `fresh-machine-bootstrap` (audit 6): the first stage that applies, run in the harness of line 12.
15. [ ] `test-second-apply-noop` *planned*: a second apply in a guest changes nothing.
16. [ ] `reconcile-drift-and-supervised-apply` (audit 5): the first full apply on the laptop, after line 15.
17. [ ] `add-kali-vm-target`: the `vm` kind and the Kali VM; needs lines 11 and 12.
18. [ ] `add-machine-smoke-ci`: the committed workflow and its Zabbly channel matrix; the VM job needs line 17.
19. [ ] `support-kali-vm-uefi`: a Kali VM image of our own, and the pipeline decision (distrobuilder with a fork of `lxc/lxc-ci`, or Packer); an upstream request.
20. [ ] `support-kali-vm-secure-boot`: after line 19.
21. [ ] `test-update-to-head` *planned*.
22. [ ] `test-rollback-to-previous` *planned*.
23. [ ] `test-purge` *planned*.
24. [ ] `support-omarchy` *planned*: an Arch VM with the Omarchy installer; needs line 17.
25. [ ] The rest, in the audit's order:
    * [ ] `port-omalap-shell-aliases` (audit 8)
    * [ ] `rationalize-package-ownership` (audit 9): also owns the mise packaging backlog above
    * [ ] `install-terminal-fonts` (audit 10)
    * [ ] `manage-kde-desktop-config` (audit 11)
    * [ ] `manage-ai-tool-configs` (audit 13)
    * [ ] `manage-dev-tui-configs` (audit 14)
    * [ ] `ignore-app-state` (audit 15)
    * [ ] `add-repo-quality-gates` (audit 17)
    * [ ] `refresh-repo-docs` (audit 18)
    * [ ] `add-agent-launch-tasks` (audit 25): after line 10, for the language rule of the global tasks.

Later, with no change yet: development containers and DevPod as targets, OCI images as machines, real machines reached over SSH (with cem), more distros (Debian stable, Ubuntu, Arch), RPM-based distros, Zabbly packages for Debian testing (revisit at the forky freeze, early 2027).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
