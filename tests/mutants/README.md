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

The wrapper mutant replaces the `opencode` function with `opencode() { command env opencode "$@"; }`, which hands the whole environment to the binary.
Three checks fail in each of the three shells: the synthetic set is not removed, a variable added later is not removed, and the secret-named names do not disappear from the list of what the stub sees.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
