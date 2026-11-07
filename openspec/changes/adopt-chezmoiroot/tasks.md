## 1. Snapshot

- [x] 1.1 Capture the before state (`mkdir -p /tmp/opencode/chezmoiroot-before && cd /tmp/opencode/chezmoiroot-before && chezmoi managed > managed && chezmoi status > status && chezmoi data --format=json > data.json && chezmoi diff --exclude=externals --no-pager > diff`)
- [x] 1.2 List what moves and what stays (`git ls-files | cut -d/ -f1 | sort -u`); confirm no other root entry is a source file

## 2. Move

- [x] 2.1 `mkdir home` and `git mv` into it: `.chezmoi.toml.tmpl .chezmoidata .chezmoiexternals .chezmoiignore .chezmoiremove .chezmoiscripts .chezmoitemplates dot_* empty_* symlink_* key.txt.age` (`git status --short | grep -vc '^R'` prints 0)
- [x] 2.2 Write `.chezmoiroot` with the single line `home` (`chezmoi source-path`)
- [x] 2.3 Compare with the snapshot (`chezmoi managed | diff - /tmp/opencode/chezmoiroot-before/managed`; same for `status` and `diff`)
- [x] 2.4 Propose commit `refactor(chezmoi:layout): move the source state into home/` (renames only)

## 3. Paths and ignores

- [x] 3.1 `home/.chezmoiscripts/run_onchange_before_05-install.sh.tmpl:18,73`: replace `$HOME/.local/share/chezmoi` with `{{ .chezmoi.sourceDir }}` (`rg -n '\.local/share/chezmoi' home/` prints nothing)
- [x] 3.2 `home/.chezmoiignore`: drop `README.md`, `TODO.md`, `scripts` and the temporary repository-files block (`AGENTS.md`, `docs`, `openspec`, `mise.toml`, `hk.pkl`) (`chezmoi managed | diff - /tmp/opencode/chezmoiroot-before/managed`)
- [x] 3.3 `.gitignore`: `dot_config/tmux/plugins` becomes `home/dot_config/tmux/plugins` or is dropped (nothing creates it in the source) (`git check-ignore -v home/dot_config/tmux/plugins/x`)
- [x] 3.4 Fix the path in the comment at `home/.chezmoidata/vscodium.yaml:1`
- [x] 3.5 Update `AGENTS.md` ("Where things live") and `openspec/config.yaml` (layout paragraph) to the `home/` layout
- [x] 3.6 Propose commit `chore(chezmoi:layout): fix source paths and ignores for home/`

## 4. Checks

- [x] 4.1 Snapshots match (managed, status, diff) apart from the `05-install` script entry, already pending, and the new `decrypt-private-key` entry, whose rendered key path gains `/home`
- [x] 4.2 `chezmoi data` identical apart from `sourceDir` (now ending in `/home`) and `commandDir` (where chezmoi ran) (`chezmoi data --format=json | diff - /tmp/opencode/chezmoiroot-before/data.json`)
- [x] 4.3 `chezmoi doctor`: `source-dir` and `working-tree` ok, no new warning
- [x] 4.4 Externals unaffected (`chezmoi apply --dry-run --verbose --include=externals 2>&1 | head`) shows no forced re-download
- [x] 4.5 Replay the brew hook in a scratch clone: a changed Brewfile in `home/dot_config/brewfile/` produces one commit touching only that file (`git -C <clone> show --stat HEAD`)
- [x] 4.6 `cmcd`, `cmll` aliases land in `home/` (`zsh -i -c 'alias cmll'`)

## 5. Close

- [ ] 5.1 `openspec validate adopt-chezmoiroot --strict`; `/opsx-verify adopt-chezmoiroot`
- [ ] 5.2 Archive (`openspec archive adopt-chezmoiroot --yes`)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
