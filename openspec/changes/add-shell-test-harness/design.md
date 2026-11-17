## Context

The shell code of this repository is proved by three harnesses built in a scratch directory outside the repository, by three archived changes:

| Harness | Change | Proves | Size |
| --- | --- | --- | --- |
| `scripts-test` | `make-install-scripts-idempotent` | spec `install-scripts` | `all.sh` of 552 lines (155 checks), `run.sh`, a one-file stub, `render.sh`, two reshim helpers, a `fix/` tree of 123 files, a self-test |
| `agent-env` | `add-agent-env-wrapper` | spec `agent-environment` | `driver.sh` (39 checks in zsh, system bash and a Homebrew bash), a stub binary, a synthetic set |
| `shell-startup` | `fast-correct-shell-startup` | spec `shell-startup` | a shared `lib.sh`, seven `t-*.sh` scripts, a unit body, a stub; they print values, they do not assert |

They were read from a staged copy in the lead's worktree (`.state/tmp/old-harness/`); the originals are not read or changed.
The checks below are the inventory of that reading.

What does not travel as it is:

- Hard-coded scratch and worktree paths (`/tmp/...`, the worktree of each change) in every script.
- Machine paths: the brew prefix, the mise install of shellcheck, `~/.local/bin/mise`, `/usr/bin/jq`, `/usr/bin/unzip`, `/usr/bin/python3`, the brew build of vim.
- Reads of private state: `chezmoi dump-config` for the environment table, `chezmoi data` for the VSCodium list, a launcher file copied from the real home, the real chezmoi configuration for every render.
- Literal canaries and names: over the main files of the three harnesses, the redaction tool (public profile) counts 55 home paths, 3 identity matches, 3 private terms and 21 credential variable names, and the secret scanner reports 11 findings, all on the literal canaries.
- A verdict by eye: the startup harness compares a render of the previous commit with one of the working tree and prints both.
- Gaps of the staged copy: the two snippets `t-behaviour.sh` sources (`snip/zsh-state.zsh`, `snip/bash-state.bash`) and the list of base utilities of `realbin/` were not copied; both are recoverable from the committed session exports of the two changes.
  The brew completions block of `run_onchange_after_10-brew.sh.tmpl` (`brew-block-test.sh`) is outside the 155 checks.
  Three fixture directories (`fresh`, `krew-tty`, `vim-noycm`) are used by nothing.

Facts checked on 2026-11-17, with the tools of the laptop (chezmoi 2.73.3, mise 2026.10, zsh 5.9, bash 5.3.15 for both the system and the Homebrew builds, GNU parallel 20261022) and the bats-core 1.14.0 documentation (bats itself is installed at apply):

- The pins are the latest tags, and the commits they resolve to (`git ls-remote`, annotated tags peeled):

  | Library | Tag | Commit |
  | --- | --- | --- |
  | bats-support | v0.3.0 | `24a72e14349690bcbf7c151b9d2d1cdd32d36eb1` |
  | bats-assert | v2.2.4 | `f1e9280eaae8f86cbe278a687e6ba755bc802c1a` |
  | bats-file | v0.4.0 | `13ad5e2ffcc360281432db3d43a306f7b3667d60` (a lightweight tag) |

  bats-core v1.14.0 resolves to `eb7f42f8d608ac693d7a4b67474f6714ea68cfc5`.
  The aqua registry entry is a `github_archive` (release v1.14.0 has no asset and the entry has no checksum), so mise downloads the source tarball of the tag and nothing verifies it: bats-core is pinned by tag only, and `mise exec -- bats --version` is the check (found at apply, 2026-11-17).
- The mise registry maps `bats` to `aqua:bats-core/bats-core`.
- bats 1.14 exits with an error when it finds no test (`--allow-empty-suite` reverts it), `run` honours `set -e`, `--report-formatter junit` writes `report.xml` into the directory of `--output`, which must exist, and `setup_suite.bash` is searched in the directory of the first test file only.
- `chezmoi apply` with a generated configuration, a scratch home, cache, state and destination renders the shell targets in 1.1 s (64 entries) and the whole source state in 10.6 s (748 entries, 2.8 MB).
  It fails on a destination that does not exist (the first target is a symlink, and chezmoi creates neither the root nor the parent of a directory target when the targets are listed), and works on an empty pre-created destination of mode 0700, 0750 or 0755.
  The brief says a pre-created directory with another mode than 0750 made an apply fail before: that did not reproduce here, and the first failure is the missing root.
  The only stderr line of a successful apply is a warning that the configuration template has changed, which is expected for a hand-generated configuration.
- `home/dot_config/zsh/completions.d/aqua.sh.tmpl` runs `aqua completion zsh` at render time, and `home/.chezmoitemplates/{cpu,machine-type}.toml.tmpl` call `lscpu` and `hostnamectl`, so a render needs a stub `aqua` and a configuration that is not rendered from `home/.chezmoi.toml.tmpl`.

## Goals / Non-Goals

**Goals:**

- One suite, one command, runnable by anyone on a Linux machine with mise, with the checks and the strictness of the three harnesses.
- Tests that are isolated from the machine by construction, so that a mistake cannot touch the real home, the real chezmoi state, a package or a system file.
- A clear line between what is portable and what reads the machine (opt-in), and a clear level for each test.
- Proof that each suite can fail, kept and repeatable.
- Fixtures with no private content and no literal that a scanner takes for a secret.
- Helpers that another runner (pytest later) can reuse without a rewrite.

**Non-Goals:**

- CI (`add-machine-smoke-ci` will call the entry point and read the report).
- Moving or editing the planned Python suites or their changes.
- Adding pytest, or any Python tooling to the repository.
- Changing the code under test, the Brewfile or `hk.pkl`.
- Automating the live probe of the wrapper (a herdr tab and a probe agent): it stays a manual check.
- macOS or Windows: the wrapper stub reads `/proc` and the tests use GNU `stat` and `touch`.

## Decisions

### 1. Runner, libraries and pins

bats-core 1.14.0 is installed by mise (`"aqua:bats-core/bats-core" = "1.14.0"` in `mise.toml`); the three helper libraries are fetched by `tests/deps.sh`, run by the mise task `test:deps`, into `tests/.lib/<name>`.
`tests/deps.txt` has one line per library: name, URL, tag, commit.
The pin is strict:

- the task clones the tag shallow (`git clone --depth 1 --branch <tag>`) into a temporary directory next to the target, reads `git rev-parse HEAD`, and compares it with the commit of the line;
- on a match it moves the directory into place, on a mismatch or a failed fetch it removes the temporary directory and exits 1 with one message that names the library, the tag and, for a mismatch, both commits;
- a library already at its pinned commit is left alone with no network call, so a second run works offline;
- the tests load the libraries with `bats_load_library` and `BATS_LIB_PATH=tests/.lib`, so a missing library fails the file at load and never turns into a silent skip.

Offline and 401: the fetch is anonymous.
The clone runs under `env -i` with a scratch `HOME` (no `~/.gitconfig`, so no credential helper and no rewrite rule), `GIT_CONFIG_NOSYSTEM=1` and `GIT_TERMINAL_PROMPT=0`, so a token variable that the shell holds, or once held, cannot be sent to a host and GitHub has nothing to answer 401 to.
`mise install aqua:bats-core/bats-core` is a separate step that uses mise's own login (`credential_command`); the short name `bats` would install a second copy under `installs/bats`, because the pin key of `mise.toml` is the long name.
Alternatives: git submodules (a pin by commit, but a heavier checkout and a second place that holds the version), vendoring the libraries (about 1 MB of third-party code in a public history), a mise `github:` backend for each library (a release asset check, but the libraries publish no asset and the tags would not give a commit).

### 2. Layout and levels

```
tests/
  README.md            levels, the two modes of the install-script harness, variables, commands, scenario table
  run.sh               entry point (plain bash)
  deps.sh  deps.txt    the pinned libraries
  helpers/*.sh         plain bash, no bats
  helpers/bats/*.bash  the bats glue: load.bash, setup_suite.bash
  fixtures/            small synthetic files (each under 4 KiB)
  mutants/             the mutated copies of the proof of failure, and README.md
  unit/  smoke/        the .bats files; smoke/*-live.bats are the opt-in tests
  .lib/  .reports/     git-ignored
```

The definitions go in `tests/README.md`, as the spec says, and are short on purpose:

- **Unit**: one file or one rendered script is run under `env -i` with a scratch home, every tool it calls is a stub, nothing reaches the network, a file takes seconds.
  The shell is real (zsh, bash), the tools are not.
- **Smoke**: real interactive shells start on a scratch render, under a pseudo-terminal when the check is about a terminal, or a real tool runs in a sandbox of scratch directories (the real `mise reshim`).
  It runs by default and may take a few seconds per file.
- **E2E**: an apply into a scratch destination or a disposable machine, opt-in.
  Defined in the README, with no directory and no test now: bats 1.14 errors on an empty suite, and none of the three suites belongs there.

The tests that read the real machine are smoke files named `*-live.bats` and tagged `live` (`# bats file_tags=live`), so that one command selects them and one variable switches them on (decision 7).

Other suites, classified in the README without moving them:

| Path | Planned by | Level | Runner |
| --- | --- | --- | --- |
| `tests/global-mise-tasks/` | `add-secret-tasks`, `add-repo-roadmap`, `add-agent-launch-tasks`, `add-incus-host-setup` | unit (fakes for the provider, chezmoi and herdr), the age round trip is smoke | `python3 -m unittest discover` |
| `tests/machine/` | `add-machine-lifecycle-test-infra`, `add-kali-vm-target` and others | its pytest tests against a fake engine are unit; the stages run in guests are e2e | `uv run pytest`, `mise run machine:*` |

Neither change needs to move: their paths are named by subject, mine by level, and the README is the one place that says which is which.
One consequence: a fake that one of those changes keeps under `/tmp/opencode` (the fake herdr) is theirs to change, and the shared rule of this suite (scratch from the test's own temporary directory) is noted in the README for them.

### 3. Helpers and bats glue

Plain scripts in `tests/helpers/`, sourced by tests and runnable alone, each with a header that says what it provides:

| File | Provides |
| --- | --- |
| `common.sh` | repository root, `DOTFILES_TEST_SOURCE` (default: the repository root), tool lookup by `command -v` with a fixed extra list, the GNU time resolver |
| `scratch.sh` | scratch directories (mode 0700), `env -i` runner with `PATH`, `HOME` and the named variables, pseudo-terminal runner (`script -qec`) |
| `synth.sh` | the synthetic variable set and the canaries, built from parts at run time, the list of canaries, the name that `010-env_user.sh` unsets (read from the file) |
| `render.sh` | the generated chezmoi configuration, the stub `aqua`, the restricted render, the render of a git ref (`git archive`, read-only) |
| `harness.sh`, `stub` | the isolated and live read-only modes of the install-script harness (ported from `run.sh` and `stub`), the curated utility directory (`realbin`) |
| `fixtures.sh` | the fixture builders: stub tools with state in the scratch home, package lists generated from the repository data, `.vsix` archives |

Bats glue in `tests/helpers/bats/`: `load.bash` (loads the three libraries, defines `require_tool`, `require_shell` and `require_live`, each a `skip` with a message that names what is missing), and `setup_suite.bash` (resolves tools once and checks the libraries).
The runner passes `--setup-suite-file` explicitly, because bats looks for `setup_suite.bash` in the directory of the first test file only and the suite has two directories.
A plain helper returns a status and prints a reason; the glue turns that into a skip.
That is the whole rule that keeps the helpers reusable.

### 4. The scratch render and the synthetic configuration

`render.sh` writes a configuration with only synthetic data (`demo-` values for the four identity keys; `machine.type`, `cpu`, `github`, `features`, `nvim` and `tools.search` set as the template would; no `encryption`, no `age`), and copies the `[env]` table of `home/.chezmoi.toml.tmpl` as it is, so there is one source for those four brew-file variables and the old read of `dump-config` is gone.
It makes an empty destination (mode 0750, what the umask of the configuration gives) and the `.config` directory below it, puts a stub `aqua` first on `PATH`, and runs `chezmoi apply` with `--config`, `--persistent-state`, `--cache`, `--destination`, `--exclude=scripts,externals,encrypted` and the shell targets only: `.config/shell`, `.config/zsh`, `.config/bash` and the dot files that link into them.
That is 1.1 s instead of 10.6 s for the whole source state.
Each test file renders once into its own temporary directory, and each test copies the render (`cp -a`, 64 entries) into its scratch home, because the startup tests write caches there and a parallel run must not share them.
The launcher file that the old harness copied from the real home becomes a one-line synthetic file in `fixtures/`.

The tests of the config template itself (`init-keeps`, `init-default`) render `home/.chezmoi.toml.tmpl`, which calls `hostnamectl` and `lscpu`: they skip, naming the tool, when one is absent.
Locale: shells start with `LANG=C.UTF-8`, which exists everywhere, where the old harness used a generated `fr_FR.UTF-8`; the unset-locale case is finding F21, owned by `correct-shell-environment`.

### 5. Isolation

- The code under test always runs through one function of `scratch.sh` that starts it under `env -i` with `PATH`, `HOME` (a directory below `BATS_TEST_TMPDIR`) and only the variables the test names.
- `tests/run.sh` itself runs bats with a scratch `HOME`, `PARALLEL=--will-cite`, and without the exported variables whose names match the secret pattern (the way the `opencode` function does it, names computed at the call), so that even a test that forgot `env -i` cannot print one.
  The real home is handed to the live tests explicitly (`DOTFILES_TEST_REAL_HOME`) and they only read it.
- No test applies except through `render.sh`, no test sets `CHEZMOI_SCRIPTS_DRY_RUN` on an apply (it is set on a rendered script run by the harness, as the old suite did), and `sudo` is a logging stub in both modes of the harness; the spec scenarios check these with `rg` on the test sources and by listing the real home before and after a run.
- A small unit file, `harness.bats`, is the port of the old `selftest/`: it checks that a stub logs and answers from a fixture, that `sudo` logs and does not elevate, that a live-mode call outside the allow-list is refused and logged, that isolated mode refuses a script whose `use_tool_dirs` lists a real directory, and that `env -i` hides a synthetic secret-named variable.

### 6. Synthetic names, canaries and the unset name

- Names are built from parts (`DEMO_` + a word + `_` + a suffix taken from a list of the pattern's suffixes), so the committed files hold no `DEMO_..._TOKEN`-like literal.
  The redaction tool counted 21 credential variable names in the old files for exactly that shape.
- A canary is `cnry` + a number + a padding of a lowercase word, 20 characters or more, assembled in `synth.sh`.
  The secret scanner flagged the old canaries (`CNRY0001QWERTYUIOPAS` in an `export NAME=` line) as a generic API key: built at run time, none is in a file, and the shape has no run of capitals that looks like a key.
  If a scanner still flags a runtime value in an output file, the shape changes; the allow-list of the scanner is not touched without asking.
- The private-environment scenario of `shell-startup` must set the variable that `rc.d/010-env_user.sh` unsets (a provider's documented name, already in that file).
  The helper reads it from the `unset` line at run time, so the tests hold `DEMO_` names only.
- Package lists come from the repository: the pipx fixture is built from `home/dot_config/pipx/packages.json` (the old fixture copied a 48 KB file, three times), the VSCodium list from `home/.chezmoidata/vscodium.yaml` through `chezmoi execute-template '{{ .vscodium.extensions | toJson }}'` under the synthetic configuration, and the krew lists from the data file.
  Nothing is copied from `chezmoi dump`, `chezmoi managed`, brew, pipx, an installed-extension list or a history.

### 7. Opt-in tests that read the machine

A live test calls `require_live`, which skips unless `DOTFILES_TEST_LIVE=1`, with a message that names the variable.
They are:

- install scripts: the ten live runs (real read-only queries, everything else refused and logged, `sudo` a stub), the call count of the live VSCodium run, the bat scratch build, the vimrc under the real Vundle, `mise install --dry-run-code` against a copy of the repository configuration, and the reshim preview against the real installs;
- shell startup: the two timing thresholds (medians of at least 7 alternating rounds under a pseudo-terminal) and the cache with the real tools;
- wrapper: the deployed target equals the source (`chezmoi diff`), the count of lowercase secret-like names in the user's own environment, and the names of the user's environment file searched in the source file (counts only).

`mise run test:live` runs everything with the variable set, serially (`--jobs 1`): the timing tests must not share the machine with other tests.
They only read, print counts and test names, and never print a name or value of the real environment; `--print-output-on-failure` is not used and no `bats-file` assertion that displays file contents is used on a log that could hold one.

### 8. Inventory of the ports

The level of each check, by what it needs:

| Suite | Unit | Smoke | Opt-in (live or compare) |
| --- | --- | --- | --- |
| Wrapper (`driver.sh`, spec `agent-environment`) | 44: 39 per-shell checks (13 in each of zsh, system bash, Homebrew bash), the canary scan, `bash -n` and `zsh -n` (2), no secret-like name in the file (1), the documentation line in `AGENTS.md` (1) | 1: an interactive zsh on the scratch render defines the function | 3 live: deployed target, lowercase names, names of the environment file |
| Shell startup (spec `shell-startup`) | 53: the cache helper (17 checks in each of zsh and bash), the alias fixes (9 in each), shellcheck on the aliases file | 39: silent startup 9, single load 7 (six shell kinds and the dump header), behaviour invariants 15, cache with stub tools 8 | 5 compare (base ref: alias and function names in two shells, desktop replay, login names in two shells), 4 live (two timings, cache with real tools in two shells) |
| Install scripts (spec `install-scripts`) | 133: 61 isolated runs, 17 call counts, 4 second runs, 31 render checks, 20 static checks (10 scripts, two renders), plus 3 new for the brew completions block | 7: `mise reshim` in a sandbox with the real binary | 15 live |

The behaviour invariants of the startup smoke are: the private environment in three shells, the `opencode` function in two, the desktop replay in two (the synthetic names are set, the unset name is not), login `PATH` equal to non-login `PATH` in two shells, no duplicate in `fpath`, the registrations with a filled cache in two shells, the bare-terminal bash login, and the lists of repository aliases and functions in two shells (every name the repository defines is defined).
Those are absolute checks.
The old before and after comparison is kept as the opt-in compare of decision 9.

Golden lists of alias and function names were considered and rejected: the startup also loads the integrations of whatever tools are installed (zoxide, fzf, mise, broot, direnv, the completions under the brew prefix), which define hundreds of functions in zsh, so a committed list would fail on the next tool upgrade without any repository change, would differ on every other machine, and would tell which tools this laptop has.

What depends on this machine, and where it went:

- Unit checks that need a real utility (`jq`, `unzip`, `python3`, `shellcheck`, the second bash) resolve it at run time and skip, naming it, when it is absent; the `init-*` checks need `hostnamectl` and `lscpu`.
- The smoke shells load the brew integration when `110-pkg_brew.sh` finds the prefix, so the set of functions differs between machines; every smoke assertion is an invariant that holds either way.
- The shim cleanup is smoke, not unit: it runs the real `mise` binary, but only in scratch directories, offline, with fake installs.
- Everything that read the real home, the deployed targets, a real tool's state or the real timing is live.

The ported counts are compared with the old ones at each suite: 39, about 101 (the startup harness had no count: the figure is that of the inventory above) and 155.
If the apply finds that an inventory figure is off, the spec scenario "Counts against the old harnesses" is amended before the archive, not the other way round.

### 9. Comparison with another ref

`DOTFILES_TEST_BASE_REF=<ref>` makes the startup tests render that ref (`git archive <ref> .chezmoiroot home` into a scratch directory, read-only on the repository, then the same render as the working tree) and compare: the names and values of the desktop-session replay (values of secret-pattern names left out), the exported names of login shells, the alias and function names of interactive shells.
Differences that the change claims are listed one name per line in the file named by `DOTFILES_TEST_BASE_ALLOW`; any other difference fails the test and is printed as names and counts.
Without the variable the tests skip, naming it.
This is the old before and after, as a tool for the next changes that touch the startup (`correct-shell-environment`, `port-omalap-shell-aliases`); it is not part of the default proof.

### 10. Reports, canary scan, parallel runs, GNU time

- `tests/run.sh` creates `tests/.reports/`, runs `bats --report-formatter junit --output tests/.reports --setup-suite-file ... --jobs N -r tests/unit tests/smoke` (levels without a test file are left out), tees the output, then runs `rg -c -F -f <canaries>` on the report and the output and fails when the count is not 0, printing the count only.
  `N` is the number of cores capped at 8, 1 without GNU parallel (one line says so) or for a live run.
- `PARALLEL=--will-cite` is set in the environment of that one bats process, never exported by a startup file (`rg -n 'will-cite' home` prints nothing); GNU parallel creates `~/.parallel` on a first run, and under the scratch home that is the scratch.
- GNU time is resolved at run time by `common.sh`: `$HOMEBREW_PREFIX/opt/gnu-time/bin/time` when the variable is set and the file executable, then `time` found in the directories of the standard list if `--version` names GNU, else none.
  `brew --prefix gnu-time` is not used: it starts brew's Ruby at every call and brew is not on `PATH` in a minimal shell.
  The binary is called by path because `time` is a reserved word in both shells; without it the timing tests wrap `date +%s.%N`.
- `rg -n 'linuxbrew' tests` prints nothing: the prefix comes from the environment.

### 11. Proof that a suite can fail

`mise run test:mutants` runs `tests/run.sh` on one suite at a time with `DOTFILES_TEST_SOURCE` pointing at a scratch copy of `.chezmoiroot` and `home/` that one mutant has changed, and checks the failure count against the expected one in `tests/mutants/README.md`.
A mutant is a small `sed` script or a replacement file; one that changes nothing (the source moved under it) is an error, so a stale mutant cannot pass for a proof.

First mutants, with counts settled at apply:

- wrapper: the one-line broken function `opencode() { command env opencode "$@"; }`, 9 failures (3 per shell), as before;
- startup: the cache keyed on the tool name only (tool-changed checks fail), a completion generator that prints, `profile` sourcing `rc.d` twice for an interactive login shell;
- install scripts: `run()` of the shared helper that ignores `CHEZMOI_SCRIPTS_DRY_RUN` (every dry-run check fails), `need()` that always succeeds (the missing-tool skips fail), the limits script that writes a lower value.

The repository is never changed: mutants are built in the scratch directory, and `git status --porcelain` is the check.
The default run does not call them.

### 12. Specs, documents and the archive

- One capability `shell-test-harness` holds the requirements above; three requirements of `install-scripts` are reworded (a `MODIFIED` delta with the full blocks) because they name an unnamed "harness".
- The preamble of `agent-environment` sits outside any requirement, and a delta cannot change it: after the archive, the commit edits that paragraph by hand (scratch directory under the old scratch path, and "the driver") to say that the scenarios run from `tests/unit/` with a scratch directory below the test's temporary directory.
  This is the one edit of a main spec outside the delta mechanism, and the proposal declares it.
  The preamble of the new capability has the same fate (a delta carries requirements only): after the archive, check that the merged `shell-test-harness` spec kept its Purpose and its preamble, and that no stray modeline sits inside a requirement.
  How `openspec archive` treats text outside requirement blocks is verified on a scratch copy before the real archive.
- `AGENTS.md`, Commands section: the bullet "The proof of a script is a harness kept outside the repository (`/tmp/opencode/scripts-test` during `make-install-scripts-idempotent`)" and its three sub-bullets are replaced, after the wording is shown to the user, by:

  > - The proof of the shell code is the bats suite under `tests/`: `mise run test` runs the unit and smoke levels in a scratch home and writes a JUnit report to `tests/.reports/`, and `mise run test:live` adds the read-only tests that read this machine.
  >   `tests/README.md` describes the levels, the isolated and live read-only modes of the install-script harness, and the opt-in variables.

  The sentence about `CHEZMOI_SCRIPTS_DRY_RUN` that sits above that bullet stays.
- `tests/README.md` also holds the scenario table: each scenario of `agent-environment`, `shell-startup` and `install-scripts` with the file that proves it, or the reason it is manual.
- Audit change map: row 29, `add-shell-test-harness`, process, no dependency, before the changes that touch the startup again.
  `TODO.md`: a sub-item of the planned order, ahead of `port-omalap-shell-aliases`, because renumbering the list would break the "item N" references written in it.

## Risks / Trade-offs

- [A suite that cannot fail passes for a proof] → `test:mutants` (decision 11), the broken wrapper kept, a stale mutant is an error, and each port shows a failing run before it is called done.
- [A test touches the real home, state or destination] → `env -i` with a scratch home, a scratch home for the bats process too, a destination that is an empty scratch directory, one render helper that is the only caller of `chezmoi apply`, and spec scenarios that list the real home before and after a run and search the sources with `rg`.
- [A canary or a real value reaches a committed file or the report] → names and canaries built at run time, a scan of the report and the output after every run that fails the run, the redaction tool and the secret scanner on `tests/` before every commit, counts only.
- [Fetching the libraries writes and deletes] → `test:deps` writes only below `tests/.lib/` (inside the repository, inside `$HOME`), builds in a sibling temporary directory and moves it into place, removes only that temporary directory on failure, and is idempotent (a library at its pinned commit is not touched).
- [Scratch directories outside `$HOME`] → bats puts its temporary directories under `$TMPDIR` or `/tmp`; they are mode 0700, named by bats, removed by bats at the end (`--no-tempdir-cleanup` is a debugging flag, not used), and nothing else is written outside the home; `mise install aqua:bats-core/bats-core` and `mise run test:deps` write under the home and download from GitHub, run once with the user's go.
- [`sudo`, installs, uninstalls, applies] → none runs: `sudo` is a logging stub in both modes, the harness refuses a real directory ahead of the stubs, the mise reshim runs against a sandbox with fake installs, and the only apply is the render into a scratch destination.
- [A mutated copy is applied to the repository by mistake] → mutants are built from copies in a scratch directory, the suite reads its source from `DOTFILES_TEST_SOURCE`, and `git status --porcelain` is checked after `test:mutants`.
- [The render depends on tools of the machine] → a stub `aqua`, a generated configuration, and a skip that names `hostnamectl` or `lscpu` for the two tests that render the configuration template.
- [Startup assertions differ between machines because of the brew integration] → every smoke assertion is an invariant; the machine-specific figures (timing) are live.
- [Parallel runs break tests that share state] → each test has its own scratch home and a copy of the render, the live run is serial, and a spec scenario compares counts of a serial and a parallel run.
- [The Linux-only assumptions (`/proc`, GNU `stat` and `touch`)] → stated in the README; other systems are out of scope.
- [Reading the staged copy is not reading the originals] → the staged files are the scripts as they were; the two snippets and the utility list that were not staged are rebuilt from the session exports and checked against the old counts.
- [A fixture or test becomes part of a public history for good] → synthetic fixtures built at run time, a review of every new file before each commit, and a 4 KiB ceiling on fixtures as a proxy for "no copy of a real listing".

## Migration Plan

1. Proposal, design, specs, tasks, the audit row and the `TODO.md` entry; commit after the user validates the message.
2. With the user's go: `mise install aqua:bats-core/bats-core` and `mise run test:deps`.
3. Port the wrapper suite first (the pattern for the others), with its broken copy; then the shell startup; then the install scripts; each with a mutant and a count against the old harness.
4. Run the whole suite in both shells where the code runs in both, serially and with `--jobs`, then the scans on `tests/`, then show the `AGENTS.md` wording and write it.
5. Verify, archive on the user's go, edit the `agent-environment` preamble in the archive commit, check the merged specs, rebase on `main`, validate, report.

Rollback: delete `tests/`, remove the pin and the four tasks from `mise.toml`, the two lines from `.gitignore` and the paragraph from `AGENTS.md`; nothing is deployed, so nothing else changes.

## Open Questions

- Should a fast subset (the wrapper and the helper unit tests, a few seconds) run in the pre-commit hook next to the secret scan?
  `hk.pkl` is untouched here; the cost is a slower commit and the need for the libraries in every checkout, the gain is that the shell code is proved before it is committed.
  For the user.
- Does `openspec archive` keep the text outside requirement blocks of a main spec, and what does it write as the Purpose of a new capability?
  Verified on a scratch copy before the archive; the answer decides whether the two preamble edits are one hand edit each or one.
- The exact failure counts of the startup and install mutants, and the final count of the startup suite, are fixed at apply and written to `tests/mutants/README.md` and `tasks.md`.
- Whether the bats-core pin should be strict like the libraries: the aqua entry is a `github_archive` with no checksum, so nothing verifies the tarball today, and the extracted tree carries no commit to compare.
  A `mise.lock` would record the checksum, but it would also lock gitleaks and hk; left as a tag pin until the user decides.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
