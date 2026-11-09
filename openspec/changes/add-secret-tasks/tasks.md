## 1. Preparation

- [ ] 1.1 Check that `add-repo-roadmap` is applied and that the spec now allows Python global tasks; stop and tell the orchestrator when it does not (`rg -n -i 'python' openspec/specs/global-mise-tasks/spec.md` prints the rule)
- [ ] 1.2 Re-check the chezmoi round trip on standard input with a synthetic string (`c=canary-$$; [ "$(printf '%s\n' "$c" | chezmoi encrypt | chezmoi decrypt)" = "$c" ] && echo yes` prints `yes`)
- [ ] 1.3 Check that a process can read the start environment of its own children (`FOO_X=1 python3 -c 'import os; print(b"FOO_X=1" in open(f"/proc/{os.getpid()}/environ","rb").read().split(b"\0"))'` prints `True`)
- [ ] 1.4 Make the scratch directory with mode 0700 outside the repository (`install -d -m 0700 /tmp/opencode/secret-tasks && stat -c '%a' /tmp/opencode/secret-tasks` prints `700`)

## 2. Library

- [ ] 2.1 `home/dot_config/mise/lib/secret/store.py`: store resolution (override, `XDG_DATA_HOME`, default), table loading with `tomllib`, validation of every field of an entry, errors that name the entry and the field and never a value (`python3 -m py_compile home/dot_config/mise/lib/secret/store.py`)
- [ ] 2.2 `home/dot_config/mise/lib/secret/envfile.py`: the literal parser (`export NAME=value`, quotes, comments, expansion detection), the reported-variable rule, the single-line replacement with quoting (`python3 -m py_compile home/dot_config/mise/lib/secret/envfile.py`)
- [ ] 2.3 `home/dot_config/mise/lib/secret/probe.py`: one request with `urllib`, HTTPS or loopback only, no redirect handler, timeout, header or query credential, status mapping, errors by class and status only (`python3 -m py_compile home/dot_config/mise/lib/secret/probe.py`)
- [ ] 2.4 `home/dot_config/mise/lib/secret/chezmoi.py`: `cat`, `encrypt`, `source-path` and `apply` through pipes, `--source` as `-S`, argument lists that never hold a value (`python3 -m py_compile home/dot_config/mise/lib/secret/chezmoi.py`)
- [ ] 2.5 `home/dot_config/mise/lib/secret/holders.py`: the `/proc` scan comparing hashes in memory, the herdr pane hint by foreground working directory, the skip message (`python3 -m py_compile home/dot_config/mise/lib/secret/holders.py`)

## 3. secret:check

- [ ] 3.1 `home/dot_config/mise/tasks/secret/check` with a `#MISE description`, executable, argparse (`--target`, `--source`), the status lines and the exit codes of the spec (`python3 -m py_compile home/dot_config/mise/tasks/secret/check && test -x home/dot_config/mise/tasks/secret/check`)
- [ ] 3.2 Run it against the scratch fixtures of task 5.1 and compare with the five-line scenario (`SECRET_TASKS_STORE=/tmp/opencode/secret-tasks/store home/dot_config/mise/tasks/secret/check --target /tmp/opencode/secret-tasks/env; echo $?` prints five status lines and `1`)

## 4. secret:rotate

- [ ] 4.1 `home/dot_config/mise/tasks/secret/rotate` with a `#MISE description`, executable, the refusals, the hidden prompt, the confirmation, the flow of the design (steps 1 to 9) (`python3 -m py_compile home/dot_config/mise/tasks/secret/rotate && test -x home/dot_config/mise/tasks/secret/rotate`)
- [ ] 4.2 Temporary file and restore on every exit path, with `try/finally` and a handler for SIGINT and SIGTERM (`rg -n 'finally|SIGINT|SIGTERM' home/dot_config/mise/tasks/secret/rotate`)
- [ ] 4.3 The holders list and its limit line after the stage step (`rg -n 'start' home/dot_config/mise/tasks/secret/rotate` shows the printed limit)

## 5. Tests

- [ ] 5.1 `tests/global-mise-tasks/fake_provider.py` and `tests/global-mise-tasks/fake_chezmoi.py` as the spec describes them, and a shared helper that builds the scratch store, environment file and source repository with synthetic variables and canaries (`python3 -m py_compile tests/global-mise-tasks/fake_provider.py tests/global-mise-tasks/fake_chezmoi.py`)
- [ ] 5.2 `tests/global-mise-tasks/test_secret_check.py`: the scenarios of the requirements on the table, the statuses, the hardened requests and the canary scans (`python3 -m unittest discover -s tests/global-mise-tasks -p 'test_secret_check.py'`)
- [ ] 5.3 `tests/global-mise-tasks/test_secret_rotate.py`: the refusals, the happy path through a pseudo-terminal, quoting, failure at the verify step, interrupt, no plaintext on disk (`python3 -m unittest discover -s tests/global-mise-tasks -p 'test_secret_rotate.py'`)
- [ ] 5.4 `tests/global-mise-tasks/test_secret_holders.py`: a holder, an innocent process, the pane hint, the skipped scan (`python3 -m unittest discover -s tests/global-mise-tasks -p 'test_secret_holders.py'`)
- [ ] 5.5 `tests/global-mise-tasks/test_secret_age_roundtrip.py`: the real `chezmoi` with a throwaway identity, skipped with a reason when `age-keygen` is missing (`python3 -m unittest discover -s tests/global-mise-tasks -p 'test_secret_age_roundtrip.py'`)
- [ ] 5.6 Every secret test passes together, and no canary is left in the scratch directory (`python3 -m unittest discover -s tests/global-mise-tasks -p 'test_secret*.py'`; `rg -c -F -f /tmp/opencode/secret-tasks/canaries /tmp/opencode/secret-tasks` prints nothing outside the fake ciphertext)

## 6. Deploy and document

- [ ] 6.1 `AGENTS.md`, Commands: add `mise run secret:check` and `mise run secret:rotate <variable>` with the rule that rotation is run by the user in a terminal, and that the probe table lives in the private store (`rg -n 'secret:' AGENTS.md`)
- [ ] 6.2 With the user's go, apply the two directories as single targets (`chezmoi apply --exclude=scripts ~/.config/mise/tasks/secret ~/.config/mise/lib/secret`; `mise tasks ls --global | rg 'secret:'` prints both tasks)
- [ ] 6.3 Propose commits, one per group: `feat(sys:secrets): add the secret probe library`, `feat(sys:secrets): add secret:check`, `feat(sys:secrets): add secret:rotate`, `docs(chezmoi:docs): document the secret tasks` (each subject at most 80 characters; the hook output is visible)

## 7. Live check, by the user

- [ ] 7.1 The user writes the probe table in the private store from the format of the design (the agent never writes or reads that file) (`test -f "${SECRET_TASKS_STORE:-$HOME/.local/share/chezmoi-private}/secrets/probes.toml" && echo present`)
- [ ] 7.2 `mise run secret:check` in a terminal: one status line per variable, no value anywhere, exit status as expected (`mise run secret:check; echo $?`)
- [ ] 7.3 The user rotates the key that is expired, in a terminal (`mise run secret:rotate <variable>`); then the source file is staged and nothing else is (`git diff --cached --name-only` prints `home/dot_config/encrypted_private_env.age`) and the user commits with the proposed message
- [ ] 7.4 After the rotation, `mise run secret:check` exits 0 for that variable, and the processes listed as holders are restarted by the user (`mise run secret:check`)

## 8. Close

- [ ] 8.1 `openspec validate add-secret-tasks --strict`; `/opsx-verify add-secret-tasks`
- [ ] 8.2 Archive (`openspec archive add-secret-tasks --yes`)
- [ ] 8.3 With the user's go, tell the Neovim repository's orchestrator that the tasks exist, with the commit hash and the format of the probe table (`herdr agent get nvim-orch`)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
