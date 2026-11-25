## 1. Tests first

- [x] 1.1 `tests/unit/nvim-dev.bats`: the seven scenarios, a stub `nvim` under `env -i`, one test per interpreter; all 16 tests failed on the tree without the script and pass with it
- [x] 1.2 `tests/mutants/nvim-dev/no-refusal.sed` and its row in `tests/mutants/README.md`: the refusal no longer exits, so the missing-profile checks fail (at least 3)
- [x] 1.3 `tests/README.md`: the rows of the seven scenarios in the scenario table, and the sentence that says which specifications the table covers

## 2. The managed file

- [x] 2.1 `chezmoi add ~/.local/bin/nvim-dev`, then `cmp` of the source with the live file: identical
- [x] 2.2 Replace the one comment line that says the file is not managed by chezmoi, and nothing else
- [x] 2.3 `shellcheck -s sh`, `dash -n` and `bash -n` on the source file pass, and `mise run test tests/unit/nvim-dev.bats` passes

## 3. Checks

- [x] 3.1 `mise run test` passes with the same skips as before the change: 529 tests, 0 failures, 30 skips on 2026-11-25 (the 513 of before and the 16 new ones)
- [x] 3.2 `tests/mutants/run.sh nvim-dev-no-refusal` fails exactly 3 tests, and the repository is unchanged afterwards
- [x] 3.3 `openspec validate --all --strict` passes, the redaction tool's `--check --documents` on the new files and `gitleaks dir` on the change folder and the tests report nothing

## 4. Apply and close

- [ ] 4.1 With the user's go: `chezmoi diff ~/.local/bin/nvim-dev` shows only the mode and the comment line, then `chezmoi apply --exclude=scripts ~/.local/bin/nvim-dev`; `chezmoi managed` lists the target and `nvim-dev` still starts (a read-only check with `command -v nvim-dev`, and the start itself only if the user asks)
- [ ] 4.2 Archive with the user's go: `openspec archive manage-nvim-dev-command --yes`, then extend the purpose of `neovim-config` by hand, check its modeline, and run `openspec validate --all --strict`
- [ ] 4.3 Tell the orchestrator of the Neovim repository that the command is managed and applied, with `herdr agent prompt`; information only

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
