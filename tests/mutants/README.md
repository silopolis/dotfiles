# Mutants: proof that a suite can fail

A suite that cannot fail is not a proof.
`mise run test:mutants` (`tests/mutants/run.sh`) runs each suite against a deliberately broken copy of the code under test and checks how many tests fail.
`mise run test` does not run them.

For each row of the table, the script copies `.chezmoiroot` and `home/` into a scratch directory, changes one file of the copy, and runs `tests/run.sh` on the named test files with `DOTFILES_TEST_SOURCE` pointing at the copy.
The repository itself is never changed: the script compares `git status --porcelain` before and after.
A mutant that changes nothing is an error, so that a stale mutant cannot pass for a proof.

Changes: `replace <file>` puts a file of this directory over the target, and `sed <file>` applies a sed script of this directory to it.
Expected failures: `exactly N` for a mutant whose failures are counted one by one, `at least N` for the others.

| Mutant | Tests run | File changed | Change | Failures |
| --- | --- | --- | --- | --- |
| wrapper-broken | tests/unit/agent-env.bats | home/dot_config/shell/rc.d/445-tools_opencode.sh | replace wrapper/broken.sh | exactly 9 |
| startup-cache-name-only | tests/unit/completion-cache.bats | home/dot_config/shell/rc.d/335-shell_completion_cache.sh | sed startup/cache-name-only.sed | at least 6 |
| startup-generator-prints | tests/smoke/startup-silent.bats | home/dot_config/shell/rc.d/335-shell_completion_cache.sh | sed startup/generator-prints.sed | at least 4 |
| startup-rc-twice | tests/smoke/startup-single.bats | home/dot_config/shell/profile | sed startup/rc-twice.sed | at least 2 |
| startup-refresh-ignored | tests/unit/completion-cache.bats tests/smoke/startup-cache.bats | home/dot_config/shell/rc.d/335-shell_completion_cache.sh | sed startup/refresh-ignored.sed | at least 4 |
| install-run-ignores-dry-run | tests/unit/install-scripts-isolated.bats | home/.chezmoitemplates/script-lib.sh | sed install/run-ignores-dry-run.sed | at least 10 |
| install-need-always-ok | tests/unit/install-scripts-isolated.bats | home/.chezmoitemplates/script-lib.sh | sed install/need-always-ok.sed | at least 9 |
| install-limits-lower | tests/unit/install-scripts-isolated.bats | home/.chezmoiscripts/run_onchange_before_02-system-limits.sh.tmpl | sed install/limits-lower.sed | at least 3 |
| startup-unset-removed | tests/smoke/startup-behaviour.bats | home/dot_config/shell/rc.d/010-env_user.sh | sed startup/unset-removed.sed | at least 4 |
| env-path-no-clean | tests/unit/path-helper.bats tests/unit/env-path-files.bats tests/smoke/environment-path.bats | home/dot_config/shell/rc.d/035-env_path_helper.sh | sed env/path-no-clean.sed | at least 8 |
| env-lc-all-forced | tests/unit/locale.bats tests/smoke/environment-locale.bats | home/dot_config/shell/rc.d/020-env_defaults.sh | sed env/lc-all-forced.sed | at least 10 |

The wrapper mutant replaces the `opencode` function with `opencode() { command env opencode "$@"; }`, which hands the whole environment to the binary.
Three checks fail in each of the three shells: the synthetic set is not removed, a variable added later is not removed, and the secret-named names do not disappear from the list of what the stub sees.

The startup mutants and what they break:
- `startup-cache-name-only` keys the cache on the tool name only, so a tool that moved or was replaced keeps its cache file: the "tool resolves to another file", "header follows the new real path" and "tool newer than the cache" checks fail in zsh and in bash (6).
- `startup-generator-prints` makes the regeneration of a completion script print, so the silent-startup tests that start a home with a cold cache fail: the cold start under a terminal, and the three starts without a terminal (4).
- `startup-rc-twice` makes `profile` source the shared configuration for an interactive login shell on top of the rc file of the shell, so `zsh -l -i` and `bash -l -i` make two passes (2).
- `startup-refresh-ignored` makes `SHELL_COMPLETION_REFRESH=1` regenerate nothing: the refresh check of the unit file and of the smoke file fail in each shell (4).
- `startup-unset-removed` stops `rc.d/010-env_user.sh` from dropping the inherited variable: three private-environment checks and the desktop replay check fail (4).

The environment mutants and what they break:
- `env-path-no-clean` makes `_path_clean` return at once, so `PATH` keeps its duplicates, its missing directories and its empty entries: the helper's own `_path_clean` checks, the base `PATH` check, the unclean-start checks (no duplicate and no missing directory in any kind, an inherited directory that does not exist is dropped) and the four nested-shell checks fail (ten, plus the two `shellcheck` checks, which see an unreachable line).
- `env-lc-all-forced` puts the old `LC_ALL` default back after `LANGUAGE`, so the locale of the session is overridden again: the unit checks of the filter and of the defaults, the check that the file sets no `LC_ALL`, the two "no forced LC_ALL" smoke checks, the check of a missing inherited locale and the check of the man alias fail (14, 12 when `fr_FR.UTF-8` is not generated).

The install-script mutants and what they break:
- `install-run-ignores-dry-run` makes `run()` of the shared helper execute whatever the dry-run switch says, so every dry-run check that goes through `run` fails: the apt update, the limits install, the brew file install, the mise reshim, the bat cache, the VSCodium install and the brew completions link (10).
- `install-need-always-ok` makes `need()` succeed for a missing tool, so the checks of a script that must skip when a tool is absent fail: mise, pipx, jq, kubectl, kubectl-krew, vim, bat and codium (9).
- `install-limits-lower` makes the limits script declare half of the soft limit, so a file that already matches no longer does, and the content that is written is no longer the declared one (3).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
