# Tests

The proof of this repository's shell code: the wrapper that keeps secrets out of an agent's environment, the shell startup, and the chezmoi install scripts.
It is a bats suite, run with one command, in a scratch home, with a JUnit report.
Nothing here is deployed: `tests/` sits outside `home/`, so chezmoi never sees it.

## Run it

- `mise install` once, and `mise run test:deps` once (it fetches the pinned helper libraries into `tests/.lib`, anonymously, and does nothing when they are already there).
  The runner is pinned under its long name, `aqua:bats-core/bats-core`: `mise install bats` with the short name would install a second copy, so use `mise install` as it is.
- `mise run test` runs the unit and smoke levels and writes `tests/.reports/report.xml`.
- `mise run test:live` runs everything, including the tests that read this machine (serial).
- `mise run test:mutants` proves that each suite can fail (see `mutants/README.md`).
- `tests/run.sh [bats options] [paths]` is what the tasks call; it works from any directory and takes test files or directories to run only those.

The run prints `jobs: <n>` first, then the TAP lines, then the numbers of tests, failures and skips and the result of the canary scan.
It exits 0 when every test passes or is skipped.

## Levels

### Unit

One file or one rendered script runs under `env -i` with a scratch home.
Every tool it calls is a stub, and nothing reaches the network.
The shell is real (zsh, bash), the tools are not.
A file takes seconds.
Where a unit test needs a real utility (`git`, `jq`, `unzip`, `python3`, `shellcheck`, a second bash, `hostnamectl`, `lscpu`) it finds it at run time and skips, naming it, when it is absent.

### Smoke

Real interactive shells start on a scratch render of the shell targets, under a pseudo-terminal when the check is about a terminal, or a real tool runs in a sandbox of scratch directories (the real `mise reshim`).
It runs by default and may take a few seconds per file.
The render is one apply of the shell targets into an empty scratch destination, with a generated configuration and the scripts, externals and encrypted files left out; `helpers/render.sh` is the only place of the suite that applies anything.
`smoke/render.bats` tests the render itself: synthetic identity values and no encryption key, no external and no encrypted file, no need of `hostnamectl` or `lscpu`, and a new destination of mode 0750 that the real home never sees.
The tests that read this machine are the smoke files named `*-live.bats`, tagged `live`, and skipped unless `DOTFILES_TEST_LIVE=1`.

### E2E

An apply into a scratch destination or a disposable machine, opt-in.
It is defined here and has no directory and no test yet: bats 1.14 errors on an empty suite, and none of the three ported suites belongs at this level.

## The install-script harness

Both modes put a logging stub first on `PATH` for each tool the install scripts call (`sudo`, `apt-get`, `dpkg-query`, `brew`, `pipx`, `mise`, `kubectl`, `kubectl-krew`, `codium`, `vim`, `gh`, `rustup`, `bat`, `unzip`, `chezmoi`, `curl`, `python3`).
A script passes when it exits 0 and both the sudo log and the refused-command log are empty.

### Isolated mode

A scratch `HOME` (a copy of the fixture's home directory), a `PATH` of the stubs and of a curated directory of base utilities only, and standard input from `/dev/null`: the script can call nothing but stubs.
A stub logs its arguments and answers from the fixture directory.
It refuses a script whose `use_tool_dirs` lists a real directory, because a real `/usr/bin` in front of the stubs would let real tools run.

### Live read-only mode

The real `HOME` and `PATH`.
The stub forwards an allow-list of read-only calls to the real tool (`brew list`, `brew completions state`, `mise ls`, `pipx list`, `codium --list-extensions` and the like, and a few calls it rewrites into a harmless form) and refuses and logs everything else.
`sudo` is a logging stub in both modes: it never elevates.
Live mode is used only by the live tests.

## Isolation rules

- Every test runs the code under test under `env -i`, with a scratch home below `BATS_TEST_TMPDIR`; the real home is read only by the live tests.
- `run.sh` runs bats with a scratch `HOME` and `TMPDIR`, with the exported variables whose names match the secret pattern removed (the names are computed at the call and never printed), and with `PARALLEL=--will-cite` for that process only.
- A test never applies (except the render of the smoke level), installs, uninstalls or calls `sudo`.
  The dry-run variable of the install scripts is set on a rendered script run by the harness, and nowhere else.
- A shell started on the render has mise confined to its scratch home (`MISE_CEILING_PATHS` and friends), so a scratch home that sits inside a repository, because `TMPDIR` points there, reads no configuration above it.
- Names and canaries are built at run time from parts: no committed file holds a secret-looking name or a canary value.
  After each run `run.sh` scans the report and the output for the canaries of the run and fails when it finds one; the lines of the output that hold one are dropped from what is shown.

## Variables

| Variable | Meaning |
| --- | --- |
| `DOTFILES_TEST_LIVE` | `1` runs the tests that read this machine, serially; they skip without it |
| `DOTFILES_TEST_BASE_REF` | a git ref to render and compare with (`startup-compare.bats`); the tests skip without it |
| `DOTFILES_TEST_BASE_ALLOW` | a file, one name per line (an alias, a function or a variable name, or a whole listing line): the differences with the base ref that the change claims |
| `DOTFILES_TEST_SOURCE` | the tree under test, a directory that holds `.chezmoiroot` and `home/`; the repository by default, a scratch copy for a mutant |
| `DOTFILES_TEST_TMPDIR` | where `run.sh` makes its scratch directory (default `TMPDIR`, then `/tmp`) |
| `DOTFILES_TEST_REPORTS` | where the report and the output are written (default `tests/.reports`) |
| `DOTFILES_TEST_JOBS` | the number of parallel jobs (default: the cores, at most 8; always 1 for a live run) |

`run.sh` also sets `DOTFILES_TEST_REAL_HOME` and `DOTFILES_TEST_REAL_CONFIG` for the live tests, and two counts of the secret-like names of the real environment (taken before anything is hidden, never the names).

Tools are looked up once, by `run.sh` (or by the suite setup when a file is run with `bats` alone), before the home is replaced by a scratch home, and handed to the tests as `DT_TOOL_<NAME>`.
The lookup reads `PATH` only, and asks `mise` for a shim, passing over one that is dead (a shim of a tool that is not active in the directory): a `PATH` without the tool makes it missing, and the tests that need it skip and name it.
The helpers also read three variables that a test may set for one call: `DT_TIMEOUT` (seconds, default 60, after which a started command is killed and the test fails instead of hanging the run), `DT_START_PATH` (the `PATH` of a shell started on the render) and `DT_RENDER_PATH` (the `PATH` of a render of an install script).

## Layout

- `run.sh`, `deps.sh`, `deps.txt`: the entry point, and the pinned helper libraries (name, URL, tag, commit; a moved tag fails the fetch).
- `unit/`, `smoke/`: the `.bats` files, one per area.
- `helpers/*.sh`: plain bash that calls no bats function and reads no bats variable, so that another runner can reuse it: `common.sh` (tool lookup, shells, GNU time), `scratch.sh` (scratch homes, the `env -i` and pseudo-terminal runners), `synth.sh` (synthetic names and canaries), `fixtures.sh` and `script-fixtures.sh` (stubs and fixtures made at run time), `render.sh` (the scratch render and the shells started on it), `compare.sh`, `timing.sh`, `scripts.sh` (render the install scripts, read the data), `harness.sh` and `stub` (the two modes).
- `helpers/bats/`: the bats glue only: `load.bash` (libraries and the `require_*` skips), `scripts.bash`, `setup_suite.bash`.
- `fixtures/`: small synthetic files (each under 4 KiB).
- `mutants/`: the deliberately broken copies of the code under test, and their README.
- `.lib/` and `.reports/` are git-ignored.

## Other suites

Planned suites keep their own paths and runners; they are classified here and not moved.

| Path | Level | Runner |
| --- | --- | --- |
| `tests/global-mise-tasks/` (Python `unittest`) | unit, with fakes for the provider, chezmoi and herdr; the age round trip is smoke | `python3 -m unittest discover` |
| `tests/machine/` (a machine harness) | its pytest tests against a fake engine are unit; the stages run in guests are e2e | `uv run pytest`, `mise run machine:*` |

A fake that one of those suites keeps under a scratch path of its own is theirs to change; the rule of this suite is a scratch directory from the test's own temporary directory.

## Platform

Linux only: the wrapper stub reads `/proc`, and the tests use GNU `stat`, `touch` and `find`.
GNU parallel runs the tests of `--jobs` when it is found, and GNU time times the startup when it is found (by a path resolved at run time, because `time` is a reserved word in both shells); `date` is the fallback.

## Scenarios

Each scenario of the three specifications that this suite proves, with the file that proves it, or the reason it is manual.
The rows equal the number of scenarios of `openspec/specs/agent-environment/spec.md`, `shell-startup/spec.md` and `install-scripts/spec.md`.
The ids in parentheses are the names that the old scratch harness gave its cases: each test name of the isolated, render and live files starts with one, except three live cases that were renamed, `bat-live-scratch` (the test `live bat-scratch`), `vimrc-no-N` (`live vimrc`) and `mise-pending` (`live mise-pending`).

| Specification | Scenario | Proof |
| --- | --- | --- |
| agent-environment | Defined in both shells | `unit/agent-env.bats` (the `zsh`, `bash` and `brewbash` tests named `... defined as a function`) |
| agent-environment | Sourcing prints nothing and runs nothing | `unit/agent-env.bats` (sourcing prints nothing, sourcing runs nothing) |
| agent-environment | Syntax and target | `unit/agent-env.bats` (`bash -n`, `zsh -n`) and `smoke/agent-env-live.bats` (the deployed target equals the source) |
| agent-environment | Interactive shells load it | `smoke/agent-env-interactive.bats` |
| agent-environment | The synthetic set is removed | `unit/agent-env.bats` (synthetic set removed, canary scan) |
| agent-environment | A variable added later is covered | `unit/agent-env.bats` (variable added later is covered) |
| agent-environment | No name is written in the file | `unit/agent-env.bats` (no name of a variable is written in the file) and `smoke/agent-env-live.bats` (names of the environment file) |
| agent-environment | A multi-line value does not break the call | `unit/agent-env.bats` (multi-line value) |
| agent-environment | Non-matching names survive | `unit/agent-env.bats` (non-matching names survive) |
| agent-environment | The calling shell keeps its variables | `unit/agent-env.bats` (calling shell keeps its variables) |
| agent-environment | No lowercase secret is hiding | `smoke/agent-env-live.bats` (counts taken by `run.sh` before it hides anything) |
| agent-environment | Arguments are unchanged | `unit/agent-env.bats` (five arguments, glob, empty, quote and dollar arguments) |
| agent-environment | Exit status | `unit/agent-env.bats` (exit status 7 comes back) |
| agent-environment | No recursion | `unit/agent-env.bats` (no recursion) |
| agent-environment | Bypass keeps the environment | `unit/agent-env.bats` (bypass keeps the environment) |
| agent-environment | Documented | `unit/agent-env.bats` (`AGENTS.md` documents the bypass) |
| agent-environment | Live agent process | manual: a herdr tab and a probe agent, counted by process id |
| agent-environment | opencode still works | manual: the probe agent of the live check |
| agent-environment | The probe tab is removed | manual: the probe agent of the live check |
| shell-startup | Interactive startup time | `smoke/startup-live.bats` (median of 7 alternating rounds) |
| shell-startup | Login startup time | `smoke/startup-live.bats` (same rounds) |
| shell-startup | Login zsh | `smoke/startup-single.bats` |
| shell-startup | The other interactive shells | `smoke/startup-single.bats` |
| shell-startup | Non-interactive login zsh | `smoke/startup-single.bats` (zsh once; bash loads no `rc.d`) |
| shell-startup | Completion dump | `smoke/startup-single.bats` (five alternating starts) |
| shell-startup | No output with a terminal | `smoke/startup-silent.bats` |
| shell-startup | No output without a terminal | `smoke/startup-silent.bats` |
| shell-startup | Debug output | `smoke/startup-silent.bats` (debug output is on standard error only) |
| shell-startup | Cache hit | `smoke/startup-cache.bats` and `unit/completion-cache.bats` |
| shell-startup | Tool changed | `unit/completion-cache.bats` (tool resolves to another file, tool newer than the cache, an unrelated cache file is left as it was) |
| shell-startup | Failing generator | `unit/completion-cache.bats` (failing generator, empty output, older file kept) |
| shell-startup | Completion still works | `smoke/startup-behaviour.bats` (registrations with the cache filled) |
| shell-startup | Refresh | `smoke/startup-cache.bats` and `unit/completion-cache.bats` |
| shell-startup | Private environment | `smoke/startup-behaviour.bats` (three shells) |
| shell-startup | opencode function | `smoke/startup-behaviour.bats` (zsh and bash) |
| shell-startup | Aliases and functions | `smoke/startup-behaviour.bats` (every unconditional name is defined) and, against another ref, `smoke/startup-compare.bats` |
| shell-startup | Desktop session environment | `smoke/startup-behaviour.bats` and, against another ref, `smoke/startup-compare.bats` |
| shell-startup | Interactive login shell | `smoke/startup-behaviour.bats` (PATH of login and plain shells) and, against another ref, `smoke/startup-compare.bats` |
| shell-startup | shellcheck | `unit/aliases.bats` |
| shell-startup | Commands that take arguments | `unit/aliases.bats` (bare shells that source the file, not interactive ones) |
| shell-startup | Minimal environment | `smoke/startup-behaviour.bats` (bash login on a bare terminal) |
| install-scripts | Run each script on the provisioned laptop | `smoke/install-scripts-live.bats` (the ten live runs) |
| install-scripts | Second run in a row | `unit/install-scripts-isolated.bats` (`again-*`) |
| install-scripts | Undeclared brew package | `unit/install-scripts-isolated.bats` (`br-drift`) |
| install-scripts | Undeclared pipx venv | `unit/install-scripts-isolated.bats` (`px-miss`: no uninstall call, and the output names the undeclared venv) |
| install-scripts | Undeclared krew plugin | `unit/install-scripts-isolated.bats` (`kr-miss`) |
| install-scripts | Stale mise shim | `smoke/mise-reshim.bats` |
| install-scripts | The mise script refreshes the shims | `unit/install-scripts-isolated.bats` (`mi-reshim`) |
| install-scripts | Nothing to clean on the provisioned laptop | `smoke/install-scripts-live.bats` (`reshim-noop-here`) |
| install-scripts | Limits already match | `unit/install-scripts-isolated.bats` (`lim-match`) |
| install-scripts | Declared value lower than the live one | `unit/install-scripts-isolated.bats` (`lim-lower`, `lim-inf`) |
| install-scripts | Declared value higher than the live one | `unit/install-scripts-isolated.bats` (`lim-absent`, `lim-old`, with the content written) |
| install-scripts | No terminal | `unit/install-scripts-isolated.bats` (standard input is `/dev/null` in every run; `dec-absent`) |
| install-scripts | Input change re-renders the script | `unit/install-scripts-render.bats` (`trigger-matrix`) |
| install-scripts | Unrelated change leaves the script alone | `unit/install-scripts-render.bats` (`trigger-matrix`, `bat-inputs`) |
| install-scripts | No escaped template actions | `unit/install-scripts-render.bats` (`no-escaped`) |
| install-scripts | No literal home or source path | `unit/install-scripts-render.bats` (`no-literal-path`) |
| install-scripts | No absolute path in the pipx spec file | `unit/install-scripts-render.bats` (`pipx-no-abs`) |
| install-scripts | apt only on the Debian family | `unit/install-scripts-render.bats` (`apt-guard`) |
| install-scripts | Tool appears | `unit/install-scripts-render.bats` (`flip-*`) |
| install-scripts | A file that is not executable does not count | `unit/install-scripts-render.bats` (`noexec-pipx`) |
| install-scripts | Rendering does not depend on PATH | `unit/install-scripts-render.bats` (`path-*`) |
| install-scripts | Missing tool is a skip | `unit/install-scripts-isolated.bats` (`mi-none`, `px-nopipx`, `px-nojq`, `kr-nokubectl`, `kr-nokrewbin`, `vm-novim`, `bat-none`, `vs-nocodium`) |
| install-scripts | Tool provided by a mise shim | `unit/install-scripts-isolated.bats` (`px-shim`) and `unit/install-scripts-render.bats` (`flip-kubectl`) |
| install-scripts | Default list | `unit/install-scripts-render.bats` (`dirs-default`) |
| install-scripts | Additional directories | `unit/install-scripts-render.bats` (`dirs-extra`) |
| install-scripts | Override | `unit/install-scripts-render.bats` (`dirs-override`) |
| install-scripts | Bad entry | `unit/install-scripts-render.bats` (`dirs-bad`) |
| install-scripts | Local config wins | `unit/install-scripts-render.bats` (`dirs-config`) |
| install-scripts | A tool in an added directory | `unit/install-scripts-render.bats` (`dirs-flip`) |
| install-scripts | Same directories at run time | `unit/install-scripts-isolated.bats` (`px-extra-dir`) |
| install-scripts | PATH helper | `unit/install-scripts-render.bats` (`usedirs-helper`) |
| install-scripts | Rendered script holds no home path | `unit/install-scripts-render.bats` (`dirs-no-home`) |
| install-scripts | Isolated runs cannot reach real tools | `unit/install-scripts-isolated.bats` (`guard-real`) and `unit/harness.bats` |
| install-scripts | Declarations | `unit/install-scripts-render.bats` (`tools-declared`) |
| install-scripts | What the next apply installs on the provisioned laptop | `smoke/install-scripts-live.bats` (`mise-pending`) |
| install-scripts | Vundle commands under plain Ex mode | `smoke/install-scripts-live.bats` (the repository vimrc under the real Vundle) |
| install-scripts | Extension already installed | `unit/install-scripts-isolated.bats` (`vs-ok`, `vs-case`) |
| install-scripts | Extension missing | `unit/install-scripts-isolated.bats` (`vs-missing`) |
| install-scripts | Identification | `unit/install-scripts-isolated.bats` (`vs-newvsix`, `vs-fb-json`, `vs-fb-name`) |
| install-scripts | Unreadable archive | `unit/install-scripts-isolated.bats` (`vs-badzip`) |
| install-scripts | Listing fails | `unit/install-scripts-isolated.bats` (`vs-listfail`) |
| install-scripts | One failed install | `unit/install-scripts-isolated.bats` (`vs-fail`) |
| install-scripts | Provisioned laptop | `smoke/install-scripts-live.bats` (`live-20-vscodium`, `vscodium-calls`) |
| install-scripts | Linux list | `unit/install-scripts-render.bats` (`krew-lists`) and `unit/install-scripts-isolated.bats` (`kr-ok`) |
| install-scripts | macOS list | `unit/install-scripts-render.bats` (`krew-lists`) and `unit/install-scripts-isolated.bats` (`kr-darwin`) |
| install-scripts | Moving a plugin between lists | `unit/install-scripts-render.bats` (`krew-lists`) |
| install-scripts | Dry run of the brew script | `unit/install-scripts-isolated.bats` (`br-dry`, `br-nobrew-dry`, `br-completions-dry`) |
| install-scripts | Dry-run variable under chezmoi | `unit/install-scripts-isolated.bats` (`dry-chezmoi`) |
| install-scripts | shellcheck on rendered scripts | `unit/install-scripts-static.bats` |

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
