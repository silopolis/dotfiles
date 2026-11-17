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
| startup-unset-removed | tests/smoke/startup-behaviour.bats | home/dot_config/shell/rc.d/010-env_user.sh | sed startup/unset-removed.sed | at least 4 |

The wrapper mutant replaces the `opencode` function with `opencode() { command env opencode "$@"; }`, which hands the whole environment to the binary.
Three checks fail in each of the three shells: the synthetic set is not removed, a variable added later is not removed, and the secret-named names do not disappear from the list of what the stub sees.

The startup mutants and what they break:
- `startup-cache-name-only` keys the cache on the tool name only, so a tool that moved or was replaced keeps its cache file: the "tool resolves to another file", "header follows the new real path" and "tool newer than the cache" checks fail in zsh and in bash (6).
- `startup-generator-prints` makes the regeneration of a completion script print, so the silent-startup tests that start a home with a cold cache fail: the cold start under a terminal, and the three starts without a terminal (4).
- `startup-rc-twice` makes `profile` source the shared configuration for an interactive login shell on top of the rc file of the shell, so `zsh -l -i` and `bash -l -i` make two passes (2).
- `startup-refresh-ignored` makes `SHELL_COMPLETION_REFRESH=1` regenerate nothing: the refresh check of the unit file and of the smoke file fail in each shell (4).
- `startup-unset-removed` stops `rc.d/010-env_user.sh` from dropping the inherited variable: three private-environment checks and the desktop replay check fail (4).

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
