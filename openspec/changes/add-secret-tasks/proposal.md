## Why

The age-encrypted environment file holds provider API keys, and nothing says which of them is still valid: an expired key fails later and far away, inside a tool that reads it.
Replacing one is a manual sequence (decrypt, edit, encrypt, apply) in which the value passes through an editor buffer, a terminal and possibly a transcript, and it does not say which running processes still hold the old value.
Both steps are needed again each time a key is exposed or expires, so they are worth two small tested tasks.
Source: request of the Neovim repository's orchestrator, 2026-11-09, raised when it found an expired key; secret hygiene is audit section 2.1 and F10, F11, F12 (`harden-sensitive-targets`, archived).

## What Changes

- **Two global mise tasks**, in Python with the standard library only (the rule that allows Python for global tasks comes from `add-repo-roadmap`, which this change follows):
  - `secret:check` decrypts the environment file in memory and, for each variable that has a probe, makes one read-only request to the provider and prints one line: the variable name and a status (`valid`, `expired`, `rejected`, `unreachable`, `no probe`).
    It never prints a value, a prefix or a length, and exits 0 only when every probed key is valid.
  - `secret:rotate <variable>` asks for the new value with hidden input, on a terminal only, checks it with the same probe, replaces that one line, re-encrypts with the repository's age setup, applies that one target, stages the encrypted source file and prints a proposed commit message that names no variable.
    It then lists the running processes that still hold the old value in their initial environment, and restarts nothing.
- **The probe table is data in the private store, not in this repository.**
  It maps a variable name to a provider endpoint and to how an expired key answers; variable names are secret-variable names, which a public repository must not hold.
  The tasks carry only the generic probe machinery and a documented format with synthetic names.
  The store is found like the redaction tool finds it (an environment override, else the default clone location), so no repository name is written here.
- **Requests are hardened**: HTTPS only (plain HTTP only to a loopback address, for tests), no redirect is followed, one bounded request per key, the key lives in memory and in the request header only, never in an argument list, a child environment, a file, a log or an error message.
- **Tests** with a fake provider and a fake `chezmoi` (`tests/global-mise-tasks/`, outside the source state), canary values that must never appear in any output, and one round trip with a throwaway age identity.
- **`AGENTS.md`** gets the two commands and the rule that `secret:rotate` is run by the user in a terminal.
- **Non-goals.**
  - Creating a key at a provider (a web console step) and rotating keys that have no probe.
  - Committing: the task stages and proposes; the user validates the commit, as for every commit here.
  - Purging old ciphertext from git history: a rotated key's earlier encrypted versions stay in history, readable by the age identity only.
  - Adding the store's deployment on a fresh machine (`add-private-store-external`).

## Capabilities

### New Capabilities

- `secret-tasks`: checking the validity of the keys in the encrypted environment file, rotating one of them without exposing it, the private probe table, and the guarantees on what the tasks may output or leave behind.

### Modified Capabilities

None.
The scenario of `global-mise-tasks` that lists the deployed tasks stays true with two more tasks present, and the language rule for Python tasks is the one `add-repo-roadmap` adds.

## Impact

- New files in the source state: `home/dot_config/mise/tasks/secret/check`, `home/dot_config/mise/tasks/secret/rotate`, and a small library under `home/dot_config/mise/lib/secret/`; new tests under `tests/global-mise-tasks/`.
- `AGENTS.md`: Commands section.
- No change to the encrypted file as part of this change; `secret:rotate` changes it when the user runs it.
- The probe table is created by the user in the private store; this change does not write to the store.
- Order: after `add-repo-roadmap` (the Python rule); the store external is a soft dependency (a fresh machine needs it to have a table).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
