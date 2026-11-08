## Working notes

- This change is built in a git worktree, which is not chezmoi's default source.
  Set `W` to the worktree root (`W=$(git rev-parse --show-toplevel)`) and define `chezmoi() { command chezmoi -S "$W" "$@"; }` in the shell that runs the checks: every chezmoi command below then reads the worktree.
  The exceptions spell `-S` out (the user's `chezmoi init` runs, and the Brewfile checks, which read the default source because the brew hook does).
- chezmoi comes from brew: in a minimal shell run `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` first.
- Scratch files live under `/tmp/opencode/fcct/` (mode 0700) and are deleted at the close (6.3).
- `chezmoi diff`, `status` and `apply --verbose` pipe through `delta`: add `--no-pager` when the output is filtered.
- The Neovim location (host, owner, repository) never appears in a committed file, a printed output or a message: checks print verdicts (`match`), key names or lengths, and filter the error output of git commands that reach the remote.

## 1. Before

- [x] 1.1 Save the current config and effective settings (`mkdir -p -m 700 /tmp/opencode/fcct; cp -p ~/.config/chezmoi/chezmoi.toml /tmp/opencode/fcct/chezmoi.toml.before; chezmoi dump-config --format=json > /tmp/opencode/fcct/dump-config.before.json`)
- [x] 1.2 Decrypt check baseline: pick one encrypted target (`t=$(chezmoi managed --include=encrypted | head -1); chezmoi cat ~/"$t" >/dev/null; echo $?` prints 0)

## 2. Template

- [x] 2.1 Move `pager` and `color` above the includes and add `encryption = "age"` and `umask = 0o027` there; `color = "auto"` (paths under `home/` after `adopt-chezmoiroot`)
- [x] 2.2 Add the `[age]` table with the identity path and the recipient copied from the current config
- [x] 2.3 `[diff]`: replace `diff.exclude = ["externals"]` with `exclude = ["externals"]`
- [x] 2.4 `[git]`: remove the `commitMessageTemplate` prompt line
- [x] 2.5 Add the Incus question (`promptBoolOnce . "features.incus" "Install and enable Incus on this machine" false`) above the includes and emit it as a `[data.features]` table after `[data]` (`chezmoi --override-data '{"features":{"incus":true},"email":"x","gitemail":"x","firstname":"x","name":"x"}' execute-template --init < home/.chezmoi.toml.tmpl | python3 -c 'import sys,tomllib; print(tomllib.loads(sys.stdin.read())["data"]["features"]["incus"])'` prints `True`; without the `features` key it prints `False`)
- [x] 2.6 Render non-interactively and parse (`chezmoi --override-data '{"email":"x","gitemail":"x","firstname":"x","name":"x"}' execute-template --init < home/.chezmoi.toml.tmpl | python3 -c 'import sys,tomllib; d=tomllib.loads(sys.stdin.read()); print(d["encryption"], oct(d["umask"]), d["pager"], d["color"], d["diff"]["exclude"], sorted(d["data"]["github"]))'` prints `age 0o27 bat auto ['externals'] ['is_codespaces']`)
- [x] 2.7 Preview what `chezmoi init` will write, from the stored values (`chezmoi execute-template --init < home/.chezmoi.toml.tmpl` against `/tmp/opencode/fcct/chezmoi.toml.before`): flatten both to key paths and print only the paths present on one side, plus `data.cpu` and `data.machine` of both sides, never the identity values; expected: `color`, `pager`, `umask`, `diff.exclude` and `data.features.incus` new (the deployed snapshot already holds `encryption` and `age.*`), `diff.diff.exclude` and `git.commitMessageTemplate` gone, cpu 6 and 12, machine `laptop`, no other path changed

## 3. Remove the frozen config

- [x] 3.1 `git rm -r home/dot_config/chezmoi`; check the target is forgotten, not removed (`chezmoi managed | grep -c '^\.config/chezmoi/chezmoi\.toml$'` prints 0; `chezmoi --no-pager status --exclude=scripts,externals | grep -c '\.config/chezmoi'` prints 0 (a status on the unmanaged path itself only errors); `test -f ~/.config/chezmoi/chezmoi.toml` succeeds)
- [x] 3.2 The user regenerates in a terminal (`chezmoi -S "$W" init`, which asks the Incus question: answer no); compare with the saved copy as in 2.7: expected data changes are machine type and cpu counts only, plus the new keys; check the mode of the new file (`stat -c %a ~/.config/chezmoi/chezmoi.toml`)
- [x] 3.3 Effective settings (`chezmoi dump-config --format=json | jq -c '{u: .umask, p: .pager, c: .color, d: .diff.exclude, e: .encryption}'` prints `{"u":23,"p":"bat","c":"auto","d":["externals"],"e":"age"}`)
- [x] 3.4 Decryption still works (task 1.2 command); `chezmoi doctor 2>&1 | grep -c '^warning *suspicious-entries'` prints 0 (the `ok` line of that check always mentions its name; run doctor through `chezmoi -S "$W"`, not through `timeout chezmoi`, which skips the shell function); `chezmoi data --format=json | jq -c '{g: (.github | keys), c: .cpu, m: .machine}'` shows `is_codespaces` only, 6 and 12, `laptop` (compare with `lscpu`)
- [ ] 3.5 Propose commit `fix(chezmoi:config): configure encryption, umask and diff in the template`

## 4. Neovim external (F05)

- [x] 4.1 Add the three questions (`promptStringOnce` for `nvim.host` defaulting to `github.com`, `nvim.owner`, `nvim.repo`) above the includes and emit them as a `[data.nvim]` table after `[data]`; render and parse (`chezmoi --override-data '{"email":"x","gitemail":"x","firstname":"x","name":"x","nvim":{"owner":"o","repo":"r"}}' execute-template --init < home/.chezmoi.toml.tmpl | python3 -c 'import sys,tomllib; print(sorted(tomllib.loads(sys.stdin.read())["data"]["nvim"]))'` prints `['host', 'owner', 'repo']`)
- [x] 4.2 The user regenerates in a terminal (`chezmoi -S "$W" init`); only the three new questions are asked, and the values stay in the local config, outside the repository (`chezmoi data --format=json | jq -c '.nvim | map_values(length > 0)'` prints `{"host":true,"owner":true,"repo":true}`)
- [x] 4.3 Write `home/.chezmoiexternals/nvim.toml.tmpl` as in the design; check without printing the location (`chezmoi execute-template < home/.chezmoiexternals/nvim.toml.tmpl | python3 -c 'import sys,tomllib; e=tomllib.loads(sys.stdin.read())[".config/nvim"]; print(e["type"], e["refreshPeriod"], e["pull"]["args"])'` prints `git-repo 0 ['--ff-only']`; the rendered `url` equals `https://<host>/<owner>/<repo>.git` built from `chezmoi data`, compared in the shell with a `match` verdict only; `chezmoi managed | grep -c '^\.config/nvim$'` prints 1)
- [x] 4.4 Prove the skip paths (`chezmoi --destination /tmp/opencode/fcct/nvim-home managed | grep -c '^\.config/nvim$'` prints 0 with no clone and no login file, and its standard error holds one warning, `... 2>&1 >/dev/null | grep -c 'skipping the Neovim external'` prints 1; `chezmoi --override-data '{"nvim":{"owner":""}}' managed | grep -c '^\.config/nvim$'` prints 0, with no warning)
- [x] 4.5 Prove the clone path and the keep-work rule in the scratch destination
  - Create an empty `/tmp/opencode/fcct/nvim-home/.config/gh/hosts.yml` and apply: `chezmoi apply --destination /tmp/opencode/fcct/nvim-home --persistent-state /tmp/opencode/fcct/nvim-state.boltdb --include=externals --exclude=scripts /tmp/opencode/fcct/nvim-home/.config/nvim`, with URL-like tokens masked in the output (masking bare owner or repository strings would also hide path names such as `.config/nvim` and reveal the values by inference).
  - The `origin` URL of the clone equals the one built from the data (`match` verdict only).
  - Add a local commit and an untracked file in the clone: a plain apply is skipped (the state record exists); `apply -R` asks "has changed since chezmoi last wrote it?" and fails without a terminal (the folder is 0775, the recorded state 0750); `apply -R --force` runs the pull (`Already up to date.`); `HEAD` is unchanged, `status -sb` still lists the commit as ahead and the untracked file.
  - Offline variant of the step-4.6 shape (pre-existing clone of a local bare repository, no state record, no terminal): the first plain apply pulls and records without asking.
  - Delete the scratch paths.
- [x] 4.6 With the user's go and the Neovim work idle (checks of the design, "First apply on the existing clone")
  - Record `git -C ~/.config/nvim rev-parse HEAD` and `status -sb`; the clone is clean, on a branch with an upstream.
  - The upstream's commit on the remote (`git -C ~/.config/nvim ls-remote origin refs/heads/<branch> 2>/dev/null`) is `HEAD` or an ancestor of it (`merge-base --is-ancestor`); when the commit is unknown locally, stop and ask.
  - Apply once: `chezmoi apply --include=externals --exclude=scripts ~/.config/nvim`, output filtered.
  - Compare `HEAD` and `status -sb`; check the record by its key (`chezmoi state dump --format=json | jq --arg k "$HOME/.config/nvim" '.gitRepoExternalState | has($k)'` prints `true`).
- [x] 4.7 In `AGENTS.md`: replace the "Not here: Neovim" line (the clone is now a chezmoi external, its location kept in the local config), and note that `chezmoi apply -R` also pulls into `~/.config/nvim`, fast-forward only, after a confirmation (the folder mode differs from the recorded one; `--force` skips the question), and that `~/.config/chezmoi/chezmoi.toml` is generated by `chezmoi init` and not managed (`grep -n 'nvim' AGENTS.md`)
- [ ] 4.8 Propose commit `feat(editor:nvim): clone the Neovim config through a chezmoi external`

## 5. Brew hook mode (F41)

- [ ] 5.1 In `home/dot_config/shell/rc.d/110-pkg_brew.sh`, after `chezmoi re-add "$target" || return 1` and before the `BREWFILE_NO_COMMIT` early return, add `chezmoi apply --exclude=scripts "$target" || return 1` (`zsh -n` and `bash -n` on the file)
- [ ] 5.2 Prove it
  - Replay the hook in a scratch clone (mode 0700): a local clone of the branch with the edited hook copied over, a `chezmoi` function pointing at the clone, a scratch destination and a scratch state, `umask = 0o027`; the function body is extracted from the hook file, a changed Brewfile produces one commit touching only that file (`git -C <clone> show --stat HEAD`), the target is mode 640 and `chezmoi status` on it is empty.
  - Apply the rc file alone: `chezmoi --no-pager apply --dry-run --verbose --exclude=scripts,externals ~/.config/shell/rc.d/110-pkg_brew.sh`, then without `--dry-run`; `stat -c %a` prints 640.
  - Run the hook once on the live Brewfile without a commit (`BREWFILE_NO_COMMIT=1 zsh -i -c _post_brewfile_update`): the Brewfile goes from 644 to 640, `chezmoi -S ~/.local/share/chezmoi --no-pager status ~/.config/brewfile/Brewfile` prints nothing, and `git -C ~/.local/share/chezmoi rev-parse HEAD` is unchanged.
- [ ] 5.3 Propose commit `fix(pkg:brew): re-apply the Brewfile after re-adding it`

## 6. Close

- [ ] 6.1 Record in this change's `design.md` (section "Measured at close") the count of targets whose mode the next full apply will change (`chezmoi --no-pager status --exclude=scripts | grep -c '^.M'`) and the `git-repo` external folders that stay listed, for `reconcile-drift-and-supervised-apply`
- [ ] 6.2 `openspec validate fix-chezmoi-config-template --strict`; `/opsx-verify fix-chezmoi-config-template`
- [ ] 6.3 Archive (`openspec archive fix-chezmoi-config-template --yes`); tick line 1 of `TODO.md`; set row 3 of the change map in `docs/audits/2026-10-30-environment.md` to done with the archive date; propose commit `docs(chezmoi:spec): archive fix-chezmoi-config-template`; delete `/tmp/opencode/fcct/`
- [ ] 6.4 Rebase the branch on main (the brew hook commits there) and report to the chezmoi orchestrator

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
