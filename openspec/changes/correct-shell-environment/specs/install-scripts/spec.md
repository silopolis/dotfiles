## ADDED Requirements

### Requirement: Session defaults are set for the login

`run_onchange_before_03-session-defaults.sh.tmpl` SHALL make the login give the user the umask of `system.session.umask` (the `umask=` entry of the `other` sub-field of the user's GECOS field, which `pam_umask` reads), make sudo run commands with the umask of `system.session.sudo_umask` (a file in `/etc/sudoers.d/` with `Defaults umask=` and `Defaults umask_override`, validated with `visudo -cf` before it is installed with mode 0440), set the mode of `$HOME` to `system.session.home_mode`, and make sure the locales of `system.session.locales` are generated.
It SHALL change only what differs, call sudo only to write, keep the other entries of the GECOS `other` sub-field, never make a umask or the home mode more permissive than the live value, and never remove a generated locale.
The template SHALL fail at render time when a umask is not three octal digits or the home mode is not four.

In the scenarios below, the script runs rendered, in the isolated mode of the suite: stubs for `sudo`, `chfn`, `getent`, `visudo`, `install`, `locale-gen` and `locale`, a scratch home, and fixture answers for the GECOS field, the sudoers file, the home mode and `locale -a`.

#### Scenario: Everything already set

- **WHEN** the GECOS field holds `umask=027`, the sudoers file holds the declared content, the home has mode 0700 and `locale -a` lists every declared locale
- **THEN** the script exits 0, logs that each part is set, and records no sudo call and no `chmod`

#### Scenario: Nothing set yet

- **WHEN** the GECOS field has no `other` sub-field, the sudoers file does not exist, the home has mode 0755 and `en_US.UTF-8` is not generated
- **THEN** the recorded sudo calls are, in order, one `chfn -o umask=027 <user>`, one `install -m 0440` of a file that `visudo -cf` accepted, and the commands that enable `en_US.UTF-8` in `/etc/locale.gen` and run `locale-gen`, and the home is changed to 0700 without sudo

#### Scenario: Other GECOS entries are kept

- **WHEN** the `other` sub-field holds `pri=5`
- **THEN** the `chfn` call sets it to `pri=5,umask=027`

#### Scenario: A stricter live value is left

- **WHEN** the GECOS field holds `umask=077` and the home has mode 0700 while the data asks for 0750
- **THEN** the script logs a warning for each, and records no `chfn` call and no `chmod`

#### Scenario: An invalid sudoers file is never installed

- **WHEN** the `visudo -cf` stub rejects the file
- **THEN** no `install` call into `/etc/sudoers.d/` is recorded, the script prints the reason and exits non-zero

#### Scenario: A system without the tools

- **WHEN** `chfn`, `/etc/sudoers.d` or `locale-gen` is missing
- **THEN** the script logs that it skips that part, does the other parts and exits 0

#### Scenario: Dry run

- **WHEN** the rendered script runs with `CHEZMOI_SCRIPTS_DRY_RUN=1` on the "Nothing set yet" fixtures
- **THEN** it prints one line per change it would make, and records no sudo call and no `chmod`

#### Scenario: Data checked at render time

- **WHEN** the template is rendered with `system.session.umask` set to `27` or `0o27`
- **THEN** the render fails with a message that names the key

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
