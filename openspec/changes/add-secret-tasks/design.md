## Context

- The environment file `~/.config/env` is managed as one age-encrypted source file, `home/dot_config/encrypted_private_env.age` (attributes `encrypted_` and `private_`, target mode 0600, spec `secret-hygiene`).
  It holds shell `export NAME=value` lines for provider keys and tokens, and comments.
  chezmoi decrypts with the age identity `~/.config/chezmoi/key.age` that a before script produces from the passphrase-protected `key.txt.age`.
- chezmoi has `chezmoi cat <target>` (the target content, decrypted, on standard output), `chezmoi encrypt` (standard input to standard output with the configured encryption) and `chezmoi source-path <target>`; none of them needs a plaintext file on disk (checked on 2.73.3 with a synthetic string: `chezmoi encrypt` on standard input, then `chezmoi decrypt`, returns the input; the ciphertext is ASCII-armored age).
- The global mise tasks live in `home/dot_config/mise/tasks/` with a helper in `home/dot_config/mise/lib/`; today they are shell only, and `add-repo-roadmap` amends the rule to allow Python (standard library, `py_compile` and `unittest` in `tests/global-mise-tasks/`).
- The redaction tool of the Neovim repository finds the private store through an environment override and a default clone location, and reads its lists from subdirectories; this change adds one more file there and writes nothing to it.
- herdr exposes no process identifier per pane (`herdr pane get` has the working directories, the agent and the terminal id), so a process can be tied to a pane only by hint.
- Python on this machine is 3.14, with `tomllib`; the tasks need 3.11 or later and say so.

## Goals / Non-Goals

**Goals:**

- Know, in one command and without exposing anything, which keys of the encrypted file are dead.
- Replace one key without it ever reaching a command line, a child environment, a file, a log or a transcript.
- Keep every variable name out of this public repository.

**Non-Goals:**

- Creating keys at a provider.
- Rotating keys that have no probe, except with an explicit flag.
- Committing, pushing, restarting processes, or purging git history.
- A generic secrets manager: one file, one format, one operation each.

## Decisions

### Python, standard library only

Why: a key must not appear in an argument list (curl would show it in `/proc/<pid>/cmdline`; `curl -K -` avoids that, but the rest of the flow, hidden input, in-memory edit, comparisons by hash, is clumsy and error-prone in bash).
`urllib.request` sets headers in memory, `getpass` reads from the terminal, `hashlib` compares without printing, `subprocess` pipes plaintext through standard input and output only.
Alternative considered: bash with `read -rs` and `curl -K -`; rejected for the reasons above, and because the tests need a fake provider and a pseudo-terminal, which Python does natively.
This is why the change follows `add-repo-roadmap`: until its rule is applied, a Python task breaks the spec.

### The probe table lives in the private store

File: `<store>/secrets/probes.toml`, where `<store>` is `$SECRET_TASKS_STORE`, else `$XDG_DATA_HOME/chezmoi-private`, else `~/.local/share/chezmoi-private` (the same default as the redaction tool; no repository name is written here).
Format, with synthetic names (the real file is never copied into this repository):

```toml
[[probe]]
variable = "DEMO_API_KEY"
url = "https://api.example.test/v1/models"
method = "GET"                  # GET (default) or HEAD
auth = "bearer"                 # bearer | header:<Name> | query:<param>
valid = [200]                   # statuses that mean valid (default [200])
expired_codes = ["key_expired"] # error codes that mean expired
timeout = 10                    # seconds, at most 30
```

A variable of the environment file with no entry is reported `no probe`.
An entry whose variable is not in the file is ignored with one warning line.
`secret:check` exits 2, checking nothing, when the store, the file or the table is missing or invalid: a vacuous "all valid" would hide that nothing was checked.
Alternatives considered: the local chezmoi data (not shared with other tools, lost on a new machine), and patterns on variable names in this repository (a public table of provider-specific names, which the writing rule forbids).

### Status of a request

| Answer | Status |
| --- | --- |
| Status in `valid` | `valid` |
| 401 or 403, and the JSON error code (`error.code`, else `code`) is in `expired_codes` | `expired` |
| Any other 4xx, a redirect, a body that cannot be read | `rejected` |
| Timeout, connection error, 429, 5xx, a refused certificate | `unreachable` |

Exit status of `secret:check`: 0 when every probed key is `valid`; 1 when at least one probed key is not; 2 when nothing could be checked.
`unreachable` is a status, not a crash: the other keys are still checked.

### Hardened requests

- HTTPS only; `http://` is accepted only for `127.0.0.1` and `::1`, which is what the test provider uses.
- No redirect is followed: `urllib` forwards request headers to the redirect target, including across hosts, so a redirect is turned into an error with a handler that refuses it, and the status is `rejected`.
- One request per key, sequential, with the table's timeout; no retry.
- The key is placed in the header (or the query parameter the table names) in memory; exceptions are reported by class and status only, never with the request, the URL query or the headers.

### Reading and editing the file

- Read with `chezmoi cat <target>` captured through a pipe; the target defaults to `~/.config/env`, with `--target` to change it, and `--source` is passed through as `chezmoi -S` (a worktree is not chezmoi's default source).
- The parser is literal and does not evaluate shell: it reads `export NAME=value` and `NAME=value`, with single or double quotes around the value, and ignores comments and blank lines.
  A value that uses shell expansion outside single quotes (`$(`, backquote, `${`) is reported `no probe`.
- The variables reported are the ones with a table entry plus every exported name that ends in `_KEY`, `_TOKEN`, `_SECRET` or `_PASSWORD`; the rest of the file is never listed.

### Rotation flow

1. Refuse unless standard input and output are a terminal (an agent's shell tool has none, which is intended: a key typed in a chat would be in the transcript).
2. Decrypt in memory, find the one `export` line of the variable (refuse when it is missing or appears twice), and note the hash of the old value.
3. Ask for the new value with `getpass` (no echo, no argument, no environment variable), refuse an empty value, a value with control characters, and surrounding whitespace.
4. Probe the new value with the variable's entry; refuse unless `valid`, writing nothing; `--no-validate` allows a variable with no entry and says so.
5. Show what will happen (variable name, probe result, source file) and ask for confirmation, unless `--yes`.
6. Build the new plaintext in memory, pipe it to `chezmoi encrypt`, write the ciphertext to a temporary file in the source directory with mode 0600 and rename it over the source file; the temporary file is removed on every exit path.
7. Verify: decrypt the new source with `chezmoi cat`, check that exactly one line differs and that its value hashes to the new value; on any failure write the old ciphertext back (its bytes were read into memory before step 6), apply nothing, stage nothing and stop with exit 1.
8. Apply that one target (`chezmoi apply --exclude=scripts <target>`), stage the source file with `git add`, and print the proposed message `chore(chezmoi:secrets): rotate an encrypted secret`.
9. List the holders (below).

Plaintext only ever exists in the memory of the task and in pipes to `chezmoi`: there is no plaintext temporary file to protect or remove.
The new value is replaced in the line as `export NAME='value'`, with `'` written as `'\''`; the original prefix (`export ` or none) is kept.

### Holders of the old value

The task reads `/proc/<pid>/environ` of the processes of the current user and compares each entry for the variable with the hash of the old value, in memory; it prints, for a match, the process id, the command name, the working directory and, when exactly one herdr pane has that foreground working directory, its pane id (a hint: herdr gives no process id).
Limit, stated in the output: `/proc/<pid>/environ` is the environment at start, so a shell that exported the variable later is not seen; its children are.
Nothing is restarted or signalled.
The scan is skipped with a message when `/proc` is not readable (macOS).

### Commit behaviour

The task stages the source file and prints a neutral message; the user or the orchestrator reviews and commits.
Why not commit: `AGENTS.md` says commits are proposed and validated first, and a message that names the variable would write a secret-variable name into public history.
The old ciphertext stays in history; for a key that is live at rotation time that is a residual risk, read in Risks.

### Tests

- `tests/global-mise-tasks/fake_provider.py`: an `http.server` on 127.0.0.1 with scripted answers (valid, expired by code, other 4xx, 5xx, slow, a redirect to a second loopback server that counts the requests it receives) that logs, per request, the path and whether the credential was present, never the credential.
- `tests/global-mise-tasks/fake_chezmoi.py`: a test double first on `PATH` implementing `cat`, `encrypt`, `source-path`, `apply` over a scratch directory (a reversible transform stands in for age) and logging every argument list.
- Canary values: every test key is a long synthetic string, and every test asserts that no canary appears in standard output, standard error, the fake `chezmoi` argument log, or any file under the scratch directory except the fake ciphertext.
- Rotation is driven through a pseudo-terminal (`pty` module); a second path runs it with a pipe as standard input and expects the refusal.
- One round trip with a throwaway age identity (`age-keygen` from brew, a scratch chezmoi source and destination), skipped with a message when `age-keygen` is missing, checks that the real `chezmoi encrypt` output decrypts to the expected content by hash.

## Risks / Trade-offs

- [Risk] A task that decrypts every key is a high-value target. → It runs as the user, decrypts in memory only, and never prints or writes a value; tests assert it with canaries.
- [Risk] A redirect or a log line sends a key to a third party. → Redirects are refused, only HTTPS (and loopback) is spoken, errors carry class and status only.
- [Risk] `getpass` falls back to standard input with a warning when there is no terminal. → The task checks for a terminal itself first and refuses.
- [Risk] The old ciphertext of a rotated key stays in public git history, decryptable by anyone who holds the identity. → The identity is protected by a passphrase, and rotation matters most for keys that are already dead; for a live key, rotate at the provider as well. History rewriting is out of scope.
- [Risk] The holders list misses a shell that exported the variable after start, and the pane is only a hint. → Both limits are printed with the list.
- [Risk] The task relies on `chezmoi encrypt` reading standard input. → Checked in task 1; the fallback is `chezmoi encrypt <file>` with a plaintext file in a 0700 directory removed on every exit path, which the spec already allows.
- [Trade-off] Writing the source file directly instead of `chezmoi edit` skips chezmoi's own edit hooks; the verify step and the single-target apply cover the result.
- [Trade-off] The tasks do nothing without a table in the private store: a fresh machine reports `no probe` for everything until the store is there.

## Open Questions

- Should `secret:check` also print the age of a key (from a response header, for providers that give one)? Default: no.
- A pane id from a process id would need herdr to expose it; worth a request upstream? Default: no, the hint stays.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
