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

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
