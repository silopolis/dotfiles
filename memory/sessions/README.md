# memory/sessions: redacted session transcripts

Transcripts of the agent sessions that worked on this repository.
They are raw memory: not curated, not edited after export, redacted for a public repository.
They are not chezmoi targets: they sit outside `home/`, the source state selected by `.chezmoiroot`.

## Naming

```text
{YYYYMMDDHHMM}-{slug}.md
```

- The timestamp is the session's creation time, local time.
- Sub-agent sessions sit next to their parent; their slug starts with the parent's slug.
- Slugs are neutral on purpose: a file name is not redacted, so it must not carry a name that the text masks.

## Contents

| File | Session | Notes |
| --- | --- | --- |
| `202610301854-harden_sensitive_targets.md` | `ses_e720ce42affen6d11Mjrfbnxpi` | Orchestrator session of the repository. Change `harden-sensitive-targets`: apply, hook probes, verify, archive; then the rtk and system git hook findings, the signal to the project factory, the first export, the hand-over of the git source evaluation, and the state of the other agents' changes; then the roadmap and launch changes (`add-repo-roadmap`, `add-agent-launch-tasks`, which replaces `fix-prompt-delivery`), the model of one worktree per branch and one workspace per worktree, the rule on naming sibling repositories, and the fixes to the redaction store. Re-exported in full on 2026-11-08 (a continued session is overwritten, not duplicated), main session only: the sub-agent sessions of the last days are not exported, their summaries are in the main file |
| `202610311807-harden_sensitive-explore_dispatch_rules.md` | `ses_e6d11a624ffePObu4C6kjRjMqm` | Sub-agent: how a fleet repository signals the project factory, and where rtk is configured |
| `202610311807-harden_sensitive-explore_export_machinery.md` | `ses_e6d11c8cdffe3dVrtrei30j3UH` | Sub-agent: the existing session export machinery |
| `202611022007-adopt_global_mise_tasks.md` | `ses_e6256e898ffeOM7EdjLhs55t0k` | Session of the agent that received three briefs from the Neovim repository: change `adopt-global-mise-tasks` (review, cleanup fixes, apply, archive), change `fix-prompt-delivery` (proposed, then amended after the sender's real-TUI test), change `add-private-store-external` (proposed); then the hand-over of its pending signals and this export. No sub-agents |
| `202611061418-add_mise_app_desktop_entries.md` | `ses_e4efce262ffeS3bDu0gR1sU9xA` | Change `add-mise-app-desktop-entries` (Obsidian from mise: KDE menu entry, icon, `obsidian://` handler for Firefox): all four artifacts; the `modify_` decision for `mimeapps.list` recorded in `manage-xdg-basics`; the Kali menu layout set aside for a later change; this export. No sub-agents |
| `202611061844-adopt_chezmoiroot_and_test_infra.md` | `ses_e4e09db8cffemmn27kyPyjtsNs` | Change `adopt-chezmoiroot` (move of the source state into `home/`, path and ignore fixes, `install.sh`, verify, archive); then the design of `add-machine-lifecycle-test-infra` (Incus against Vagrant, containers and VMs, OCI images, the Kali cloud image inspected) and its split into `add-incus-host-setup`, `add-incus-setup-hook`, `add-kali-vm-target` and `add-machine-smoke-ci`; `remove-brew-libvirt`, the Kali VM UEFI and Secure Boot stubs, the flag prompt in `fix-chezmoi-config-template`, the packaging backlog and the planned order of changes in `TODO.md`; this export. Redacted with the public profile and sibling repository names masked, plus three extra terms added for this export (a client-looking directory name, a VM name and a hosting provider). No sub-agents |
| `202611080814-fix_chezmoi_config_template.md` | `ses_e45fdd942ffecxz5Yn9vrFRbR0` | Change `fix-chezmoi-config-template`, led in a separate checkout: plan-mode review against the current tree and the audit findings, the three decisions (colour, live check of the brew hook, external folder modes), then the build: change documents, template (encryption, umask, diff, Incus question), removal of the frozen config, the two `chezmoi init` runs by the user, the Neovim external with scratch proofs and one no-op pull, the brew hook with a scratch replay, verify, archive, rebase and the report to the orchestrator; this export. Redacted with the public profile, plus a throwaway terms file for this export: the location of the Neovim repository (the owner everywhere, the repository name in URL forms) and the diagnostic output and commentary that would let the repository name be inferred. No sub-agents |

Each file's header states how far it goes (`<!-- session-export: through msg_... -->`).
The main file stops when it was exported: the commit of the export and anything after it are not in it.
The session keeps going after an export, so the file is replaced by a longer one at each re-export.

## Redaction

The public profile of the redaction tool rewrites each raw export before it enters this repository:

1. secrets (API keys, tokens, age secret keys, private key blocks) become `[redacted:secret]`;
2. private terms, repository names, credential variable names, token scope lines, IP addresses, e-mail addresses and non-public git hosts become `[redacted:private]`, `[redacted:repo]`, `[redacted:ip]` and similar markers;
3. identity values (name, e-mail address, login name) become `[redacted:user_...]` markers, and the worktrees root becomes `[redacted:worktrees_root]`;
4. home directories become `~`; `/home/linuxbrew` (Homebrew's prefix) and the placeholder `/home/user` stay.

The settings are in `.session-redact.toml` at the root of this repository: the public profile, the `dotfiles` terms directory of the private store, and the files that the tool's `--check` covers.
Run the tool from the repository root; the terms come from the private store, never from this repository.
The store's `dotfiles` directory sets the switch for sibling repository names to `redact`, so every sibling repository name is masked; it must not go back to `keep` until the tool keeps only public names readable.
Details the tool does not know are added for one export in a throwaway terms directory with mode 0700, selected with the environment variable `SESSION_REDACT_TERMS_DIR`, after reading the raw export for them.
Two gaps of the tool are covered the same way until it is fixed: a term right after a literal `\n` (JSON-escaped tool input) and a name next to a hyphen are not matched, so the throwaway directory holds a pattern for each term and name that allows those two contexts.
The tool and the store are recorded in the user's private notes; the tool is transitional.

Redaction only knows what it is told.
Before committing, run the tool's `--check` on the redacted files, run the repository's secret scan on `memory/sessions/`, and search the files for what this export is known to be about; none of these is proof on its own.

## Reproduce

1. Export the session to a scratch directory with mode 0700, through a file and never through a pipe (the exporter loses its tail when piped), as a full export.
2. Redact each raw file into this directory, using a neutral slug for the new file name.
3. Check with the tool's `--check`, scan with your own counts (store terms and sibling names including the contexts above, identity values, credential variable names, private key blocks), read samples, then commit.
4. Delete the raw files.

These files do not follow the Markdown rules of this repository (one sentence per line, no dashes, modeline): they are verbatim transcripts.
Linters added later must exclude `memory/sessions/`.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
