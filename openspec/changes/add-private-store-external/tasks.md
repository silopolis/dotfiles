<!-- Apply after `adopt-chezmoiroot` and `fix-chezmoi-config-template` are archived; paths are in the home/ layout. -->

## 1. Plan

- [x] 1.1 Write the proposal, design, specs and tasks; add the store check to `fresh-machine-bootstrap` task 4.3; add row 23 to the audit change map (`openspec validate --all --strict`)
- [x] 1.2 Propose commit `docs(chezmoi:spec): add the add-private-store-external change`; answer the sender in this tab with the change id (`git show --stat HEAD` lists only `openspec/` and `docs/audits/` files)

## 2. Before

- [ ] 2.1 Check the dependencies are archived and the Neovim external works (`openspec list` shows neither `adopt-chezmoiroot` nor `fix-chezmoi-config-template`; `chezmoi data --format=json | jq -c '.nvim | keys'` prints `["host","owner","repo"]`)
- [ ] 2.2 Record the store's state read-only (`stat -c '%a' ~/.local/share/chezmoi-private`; `git -C ~/.local/share/chezmoi-private status -sb`; `git -C ~/.local/share/chezmoi-private rev-parse HEAD`)

## 3. Location as data

- [ ] 3.1 Add the three questions (`promptStringOnce` for `private.host` defaulting to `github.com`, `private.owner`, `private.repo`) next to the `nvim` ones and emit `[data.private]` after `[data.nvim]`; render and parse (`chezmoi execute-template --init --promptString email=x,gitemail=x,firstname=x,name=x,nvim.owner=o,nvim.repo=r,private.owner=o,private.repo=r < home/.chezmoi.toml.tmpl | python3 -c 'import sys,tomllib; print(sorted(tomllib.loads(sys.stdin.read())["data"]["private"]))'` prints `['host', 'owner', 'repo']`)
- [ ] 3.2 Regenerate in a terminal (`chezmoi init`); only the three new questions are asked (`chezmoi data --format=json | jq -c '.private | keys'` prints `["host","owner","repo"]`)

## 4. External

- [ ] 4.1 Write `home/.chezmoiexternals/private-store.toml.tmpl` as in the design (`chezmoi execute-template < home/.chezmoiexternals/private-store.toml.tmpl | grep -c '^\[".local/share/chezmoi-private"\]'` prints 1; `chezmoi managed | grep -c '^\.local/share/chezmoi-private$'` prints 1)
- [ ] 4.2 Prove the skip paths in a scratch destination (`chezmoi --destination "$(mktemp -d -p /tmp/opencode)" managed | grep -c '^\.local/share/chezmoi-private$'` prints 0 and a warning names the store; `chezmoi --override-data '{"private":{"owner":""}}' managed | grep -c '^\.local/share/chezmoi-private$'` prints 0)
- [ ] 4.3 Prove the clone path and the mode in a fresh 0700 scratch destination with an empty `.config/gh/hosts.yml` and its own `--persistent-state`. Apply the external alone, then compare the remote with the data inside the test without printing it, and measure the clone root's mode. If it is not 700, remove `private = true`, check the 750 umask result, and record the outcome in the design. Delete the scratch destination (`stat -c '%a' <scratch>/.local/share/chezmoi-private`; `test ! -e <scratch>`)
- [ ] 4.4 With the user's go and the store clean and in sync, check read-only that the pull would not move `HEAD` (`git -C ~/.local/share/chezmoi-private fetch --dry-run`, `merge-base --is-ancestor`), apply once, then compare with 2.2 (`chezmoi apply --include=externals --exclude=scripts ~/.local/share/chezmoi-private`; `stat -c '%a'` still prints 700; `HEAD` and `status -sb` as before)
- [ ] 4.5 Note in `AGENTS.md`, next to the Neovim line, that `chezmoi apply -R` also pulls into the store, fast-forward only (`grep -n 'chezmoi-private' AGENTS.md`)
- [ ] 4.6 The location stays out of the repository (the commands of the spec scenario "Location absent from the repository" print nothing and 0)
- [ ] 4.7 Propose commit `feat(editor:nvim): clone the private store through a chezmoi external`

## 5. Global ignore

- [ ] 5.1 Add `*.add.spl` with a comment to `home/dot_config/git/ignore`; apply it alone (`chezmoi apply --exclude=scripts ~/.config/git/ignore`; `chezmoi diff ~/.config/git/ignore` prints nothing)
- [ ] 5.2 Check in a scratch repository (`git check-ignore -v .spell/en.utf-8.add.spl` names `~/.config/git/ignore`; `git check-ignore -q .spell/en.utf-8.add` exits 1); delete it
- [ ] 5.3 Propose commit `feat(git:ignore): ignore compiled Neovim spell lists everywhere`

## 6. Close

- [ ] 6.1 Tell the sender that the external is applied, so its session S16 can merge (`chezmoi managed | grep -c '^\.local/share/chezmoi-private$'` prints 1; `grep -c 'add.spl' ~/.config/git/ignore` prints 1)
- [ ] 6.2 `openspec validate add-private-store-external --strict`; `/opsx-verify add-private-store-external`
- [ ] 6.3 Archive (`openspec archive add-private-store-external --yes`), mark row 23 of the change map as done, and propose commit `docs(chezmoi:spec): archive add-private-store-external`; no cem checklist line exists for this change (`rg -n 'add-private-store-external' ~/Work/cles-en-main/migrations/2026-10-omalap-to-ulap01/checklist.md` prints nothing)

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
