## ADDED Requirements

### Requirement: The Kali VM image boots with Secure Boot enabled

The Kali virtual machine image SHALL boot as an Incus VM with `security.secureboot` at its default, and the guest SHALL report Secure Boot as enabled.

#### Scenario: Default firmware settings boot

- **WHEN** the image is launched with `--vm` and no `security.secureboot` option, and `incus exec <name> -- true` runs after `incus exec <name> -- cloud-init status --wait`
- **THEN** both exit 0

#### Scenario: Guest reports Secure Boot

- **WHEN** `incus exec <name> -- od -An -t u1 -j4 -N1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c` runs against that guest
- **THEN** it prints `1`

#### Scenario: Harness target has no override

- **WHEN** `mise run machine:list --json | jq -r '.[] | select(.name == "kali-vm") | .config | has("security.secureboot")'` runs
- **THEN** it prints `false`

### Requirement: Signing keys stay out of the repository

A signing key used for the bootloader chain SHALL NOT be committed and SHALL NOT be reachable from a CI job.

#### Scenario: No private key material in the tree

- **WHEN** `rg -l -e 'BEGIN (RSA |EC |ENCRYPTED )?PRIVATE KEY' .` runs at the repository root
- **THEN** it prints nothing

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
