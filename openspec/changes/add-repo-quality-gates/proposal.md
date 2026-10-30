## Why

Only secret scanning guards commits (from `harden-sensitive-targets`); shell syntax errors, broken templates, malformed TOML or YAML, invalid specs and off-convention commit messages are caught by hand, if at all.
The brew hook and agents commit on the user's behalf, which makes automated checks more important (process need, no single audit finding).

## What Changes

- Extend `hk.pkl` with checks on staged files:
  - shellcheck and shfmt on shell sources, including rendered `.sh.tmpl` scripts;
  - a template render check (`chezmoi execute-template` on changed `.tmpl` files that render non-interactively);
  - taplo for TOML, yamllint for YAML, markdownlint for docs;
  - `openspec validate --all --strict` when `openspec/` changes;
  - a commit-msg check for `type(domain:subject): summary` with the domain list of `AGENTS.md` and an 80-character subject limit.
- Make the brew hook's generated messages pass the same check.
- Optionally run `hk check --all` in a GitHub Actions workflow (decided in the session, see cem milestone `M-009`).

## Capabilities

### New Capabilities

- `quality-gates`: automated checks on commits and on the whole tree.

### Modified Capabilities

None.

## Impact

- `hk.pkl`, `mise.toml` (linters pinned), possibly `.github/workflows/`; existing files may need fixes to pass.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
