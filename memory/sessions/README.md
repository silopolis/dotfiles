# memory/sessions: redacted session transcripts

Transcripts of the agent sessions that worked on this repository.
They are raw memory: not curated, not edited after export, redacted for a public repository.
They are not chezmoi targets (`.chezmoiignore`).

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
| `202610301854-harden_sensitive_targets.md` | `ses_e720ce42affen6d11Mjrfbnxpi` | Orchestrator session of the repository. Change `harden-sensitive-targets`: apply, hook probes, verify, archive; then the rtk and system git hook findings, the signal to the project factory, the first export, the hand-over of the git source evaluation, and the state of the other agents' changes. Re-exported in full on 2026-11-03 (a continued session is overwritten, not duplicated) |
| `202610311807-harden_sensitive-explore_dispatch_rules.md` | `ses_e6d11a624ffePObu4C6kjRjMqm` | Sub-agent: how a fleet repository signals the project factory, and where rtk is configured |
| `202610311807-harden_sensitive-explore_export_machinery.md` | `ses_e6d11c8cdffe3dVrtrei30j3UH` | Sub-agent: the existing session export machinery |
| `202611022007-adopt_global_mise_tasks.md` | `ses_e6256e898ffeOM7EdjLhs55t0k` | Session of the agent that received three briefs from the Neovim repository: change `adopt-global-mise-tasks` (review, cleanup fixes, apply, archive), change `fix-prompt-delivery` (proposed, then amended after the sender's real-TUI test), change `add-private-store-external` (proposed); then the hand-over of its pending signals and this export. No sub-agents |
| `202611061418-add_mise_app_desktop_entries.md` | `ses_e4efce262ffeS3bDu0gR1sU9xA` | Change `add-mise-app-desktop-entries` (Obsidian from mise: KDE menu entry, icon, `obsidian://` handler for Firefox): all four artifacts; the `modify_` decision for `mimeapps.list` recorded in `manage-xdg-basics`; the Kali menu layout set aside for a later change; this export. No sub-agents |

Each file's header states how far it goes (`<!-- session-export: through msg_... -->`).
The main file stops when it was exported: the commit of the export and anything after it are not in it.
The session keeps going after an export, so the file is replaced by a longer one at each re-export.

## Redaction

The public profile of the redaction tool rewrites each raw export before it enters this repository:

1. secrets (API keys, tokens, age secret keys, private key blocks) become `[redacted:secret]`;
2. private terms, repository names, credential variable names, token scope lines, IP addresses, e-mail addresses and non-public git hosts become `[redacted:private]`, `[redacted:repo]`, `[redacted:ip]` and similar markers;
3. identity values (name, e-mail address, login name) become `[redacted:user_...]` markers, and the worktrees root becomes `[redacted:worktrees_root]`;
4. home directories become `~`; `/home/linuxbrew` (Homebrew's prefix) and the placeholder `/home/user` stay.

The private terms come from a private terms directory selected with the environment variable `SESSION_REDACT_TERMS_DIR`, never from this repository.
For this public repository the directory used is a throwaway copy of the private store's `dotfiles` terms with the switch that keeps sibling repository names readable removed, so every sibling repository name is masked.
Details the tool does not know are added to that copy as extra terms before the export, after reading the raw export for them.
The tool and the directory are recorded in the user's private notes; the tool is transitional.

Redaction only knows what it is told.
Before committing, run the tool's `--check` on the redacted files, run the repository's secret scan on `memory/sessions/`, and search the files for what this export is known to be about; none of these is proof on its own.

## Reproduce

1. Export the session to a scratch directory with mode 0700, through a file and never through a pipe (the exporter loses its tail when piped), as a full export.
2. Redact each raw file into this directory, using a neutral slug for the new file name.
3. Check, scan, read samples, then commit.
4. Delete the raw files.

These files do not follow the Markdown rules of this repository (one sentence per line, no dashes, modeline): they are verbatim transcripts.
Linters added later must exclude `memory/sessions/`.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
