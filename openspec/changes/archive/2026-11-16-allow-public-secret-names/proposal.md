## Why

The writing rule for this public repository forbade every name of a secret variable.
On 2026-11-16 the user decided that names a provider documents as its convention are fine to publish: they appear in public repositories by the thousands and tell nothing about this workstation.
`AGENTS.md` and the proposal rules in `openspec/config.yaml` were reworded the same day (commit `26a2da4`), which left the main `spec-workflow` spec stricter than the rule it describes.

## What Changes

- The requirement "Public writing" allows the names of secret variables that a provider documents as its convention, and keeps out any name that is specific to this workstation or chosen by the user.
- Values stay secret whatever the name, and the rule for doubt is to describe the variable and leave the name out.
- No file other than the main spec changes: the wording in `AGENTS.md`, `openspec/config.yaml` and the two launch briefs is already committed.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `spec-workflow`: the requirement "Public writing" lets publicly well-known variable names through and states what stays out.

## Impact

- `openspec/specs/spec-workflow/spec.md` after archive.
- Dated records keep the wording they had when written: the audit of 2026-10-30, archived changes and the session transcripts.
- A change that needs a name in a committed file now checks the name against a provider's documentation instead of leaving every name out.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
