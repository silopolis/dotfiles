## Context

- `add-incus-host-setup` deploys `~/.config/mise/tasks/sys/virt/incus/setup`; this change only calls it.
- `make-install-scripts-idempotent` moves package managers to numbered `run_onchange_after_` scripts that read deployed files, with a shared helper, a dry-run mode and `{{ include "<path>" | sha256sum }}` hash lines; 15 follows its numbering.
- Checked on chezmoi 2.73.3:
  - a script template that renders empty (whitespace trimmed with `{{ end -}}`) leaves no entry in `chezmoi status`; with the whitespace left in place it does;
  - a machine's local config overrides a `.chezmoidata` default, and `--override-data` sets data for one command;
  - `.chezmoidata` files cannot be templates, so the flag is a plain YAML default and the machine-specific value comes from the config template (`fix-chezmoi-config-template`);
  - a script that ran with the flag on leaves no pending entry once the flag is off, and switching the flag on again does not re-run it while its content is unchanged (`run_onchange` is keyed by content), so a machine runs the task again only when the task's file changes or when the user runs it by hand;
  - one script can be applied alone as a target (`chezmoi apply --include=scripts <target>`, dry run checked).
- mise may not be on `PATH` in a non-interactive shell (audit F22), so the hook calls the deployed file by path.

## Goals / Non-Goals

**Goals:**

- A machine that opts in gets Incus through the same task, with the same guarantees, on its first apply.
- A machine that does not opt in sees nothing: no pending script, no `sudo`.

**Non-Goals:**

- The task itself, its guarantees and its tests (`add-incus-host-setup`).
- The prompt that records the flag (`fix-chezmoi-config-template`).
- Defaults per profile (`fresh-machine-bootstrap`, cem `T-012`).

## Decisions

### After-script that runs the deployed file

`home/.chezmoiscripts/run_onchange_after_15-incus.sh.tmpl`:

- an after-script, because the task file has to be deployed first;
- its first lines render empty unless `features.incus` is true;
- its hash line is `{{ include "dot_config/mise/tasks/sys/virt/incus/executable_setup" | sha256sum }}`, so a change to the task re-triggers it (possible now that the task lives inside the source directory);
- it calls the deployed file by its path under `{{ .chezmoi.homeDir }}`;
- it passes no `--add-user`, no `--group` and no `--source`: the task's defaults apply (restricted group, distribution package), and a machine that wants another source runs the task by hand.

### Flag file

`home/.chezmoidata/features.yaml` holds `features: { incus: false }` and nothing else, so that other features can join it.
The `[data.features]` table in the config template (from `fix-chezmoi-config-template`) overrides it per machine.

### Alternatives considered

- Keeping the hook in `add-incus-host-setup`: that change would stay open until two earlier changes are archived.
- Putting the flag in `packages.yaml`: `make-install-scripts-idempotent` and `rationalize-package-ownership` both edit it, which would couple three changes for one boolean.

## Risks / Trade-offs

- [Risk] The hook runs `sudo` during an apply on machines that opt in. → The flag defaults to off, the task is a no-op when the host is ready, and the dry-run review rule of `AGENTS.md` applies.
- [Risk] A template that renders whitespace leaves a pending script. → A scenario checks `chezmoi status` with the flag off.
- [Risk] The task's path or name changes. → The hash line includes the file, so the render fails loudly if the path is wrong.

## Migration Plan

1. After `add-incus-host-setup`, `fix-chezmoi-config-template` and `make-install-scripts-idempotent` are archived, add the flag file and the hook.
2. Check the script renders empty by default and runs the task when the flag is on (scratch config, destination and state).
3. On the laptop, which already ran the task by hand: opt in, review `chezmoi apply --dry-run --verbose`, and let the supervised apply find nothing to do.

Rollback: `git revert`; the flag file and the script disappear, Incus stays installed.

## Open Questions

None at this point; the behaviour of a flag that is switched off and on again is recorded in the Context.

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
