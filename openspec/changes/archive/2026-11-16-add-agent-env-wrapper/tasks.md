## 1. Preparation

- [x] 1.1 Baseline: no function yet (`zsh -i -c 'whence -w opencode' 2>&1 | tail -1` does not print `opencode: function`), and a count above 0 of the matching names an agent of this shell would hold, recorded as a number only (`env | cut -d= -f1 | grep -Ec '(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY|ACCESS_?KEY|PRIVATE_?KEY|CREDENTIAL)'`)
- [x] 1.2 Make the scratch directory with mode 0700 outside the repository (`install -d -m 0700 /tmp/opencode/agent-env && stat -c '%a' /tmp/opencode/agent-env` prints `700`)
- [x] 1.3 Confirm no alias or function named `opencode` exists in the shell startup (`rg -n -w 'opencode' home/dot_config/shell home/dot_config/zsh home/dot_config/bash` prints nothing)

## 2. The function

- [x] 2.1 Write `home/dot_config/shell/rc.d/445-tools_opencode.sh`: a header comment that says what it does and why, the function of the design, the bypass named in a comment (`bash -n home/dot_config/shell/rc.d/445-tools_opencode.sh && zsh -n home/dot_config/shell/rc.d/445-tools_opencode.sh`)
- [x] 2.2 No name of a secret variable and no home path in the file (`rg -n 'DEMO_|_KEY=|_TOKEN=|/home/' home/dot_config/shell/rc.d/445-tools_opencode.sh` prints nothing)

## 3. Tests in the scratch directory

- [x] 3.1 Write the stub `opencode` and the driver, outside the repository, as the spec describes them, each shell started under `env -i` (`sh /tmp/opencode/agent-env/bin/opencode` prints a number and a marker line, and `sh -n /tmp/opencode/agent-env/driver.sh` exits 0)
- [x] 3.2 The synthetic set is removed, in zsh and in bash, and a variable added later is covered (the driver prints `0` for each shell and for the late variable)
- [x] 3.3 Non-matching names survive, the calling shell keeps its variables, a lowercase name survives (the driver prints the expected presence lists)
- [x] 3.4 Arguments with spaces pass unchanged, exit status 7 comes back, no recursion without a real binary (the driver prints five arguments, `7` and `127`)
- [x] 3.5 The bypass keeps the environment (`command opencode` prints the size of the synthetic set)
- [x] 3.6 A multi-line value does not break the call (the driver prints `0` or `1` and the stub's status)
- [x] 3.7 Run the whole driver and keep its output in the scratch directory (the driver exits 0 and prints no canary: `rg -c -F -f /tmp/opencode/agent-env/canaries /tmp/opencode/agent-env/out.txt` prints nothing)

## 4. Document

- [x] 4.1 `AGENTS.md`, Commands: one line saying that agents started from a shell run through the function that strips secret-named variables, that the bypass is `command opencode`, and where the pattern lives (`rg -n 'command opencode' AGENTS.md`)
- [x] 4.2 Record in row 27 of the audit's change map that darse and the other fleet repositories read what is portable from this change's `design.md`, section "Signal darse and the fleet", and that nothing is written to another repository (`rg -n 'Signal darse and the fleet' docs/audits/2026-10-30-environment.md openspec/changes/add-agent-env-wrapper/design.md` lists the row and the section)
- [x] 4.3 Propose the commit `feat(shell:env): start opencode without secret-named variables` (subject at most 80 characters; hook output visible)

## 5. Deploy and check live

- [x] 5.1 With the user's go, apply the single target (`chezmoi -S <worktree> apply --exclude=scripts ~/.config/shell/rc.d/445-tools_opencode.sh`; `chezmoi -S <worktree> diff --exclude=externals,scripts ~/.config/shell/rc.d/445-tools_opencode.sh` prints nothing)
- [x] 5.2 In a new interactive shell the function is defined and the startup prints nothing new (`zsh -i -c 'whence -w opencode' 2>&1 | tail -1` prints `opencode: function`; the medians of six interleaved runs of `zsh -i -c exit` with and without the file differ by less than 20 ms, and both print the same number of lines: GNU time is not installed, so time each run with `date +%s.%N`, and leave the file out of the "without" runs with `SHELL_RC_DOT_DIR` pointing at a directory of symlinks to the other rc.d files, since startup varies by several hundred ms between runs minutes apart)
- [x] 5.3 Live check on a herdr-started agent: create a tab in the workspace, start a probe agent in its pane, count the matching names in its process and in its shell, check it works, close the tab by id (the spec scenarios "Live agent process", "opencode still works" and "The probe tab is removed")
- [x] 5.4 The tab list is as before (`herdr tab list --workspace <id>` shows the same tabs as before 5.3)

## 6. Close

- [x] 6.1 `openspec validate add-agent-env-wrapper --strict` and `openspec validate --all --strict`; `/opsx-verify add-agent-env-wrapper`
- [x] 6.2 Archive (`openspec archive add-agent-env-wrapper --yes`) and tick the item in `TODO.md`
- [x] 6.3 With the user's go, tell nvim-orch directly, and the orchestrator of the fleet repository that asked through chezmoi-orch, which knows who asked, that the wrapper exists, with the commit hash and the pointer to the design section "Signal darse and the fleet" for the repositories that may port it (`herdr agent get <name>`); nothing is written to another repository

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
