## 1. Rule wording

- [x] 1.1 `AGENTS.md`, "Writing for a public repository": the bullet on secret variable names (commit `26a2da4`)
- [x] 1.2 `openspec/config.yaml`, proposal rule, and the briefs of `add-agent-env-wrapper` and `add-repo-roadmap` (commit `26a2da4`)

## 2. Main spec

- [x] 2.1 `openspec validate allow-public-secret-names --strict` passes
- [x] 2.2 Run the scenario command and list the distinct names it prints, with counts: only `GITHUB_TOKEN` (a provider convention) and synthetic `DEMO_` names
- [x] 2.3 Archive: `openspec archive allow-public-secret-names --yes`, then `rg -n 'names of secret variables' openspec/specs/spec-workflow/spec.md` prints nothing and `openspec validate --all --strict` passes

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
