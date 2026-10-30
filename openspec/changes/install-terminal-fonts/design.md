## Context

- `fc-list | grep -ci nerd` printed 0 on 2026-10-30; `~/.local/share/fonts` held two unmanaged families; `~/.fonts` is a managed symlink to it.
- Fonts are not command-line tools, so the tool priority rule does not decide by itself.

## Goals / Non-Goals

**Goals:**

- Terminal glyphs and icons render on every machine this repository sets up.
- Font versions are declared and updatable.

**Non-Goals:**

- Desktop UI fonts (KDE settings, change `manage-kde-desktop-config`).

## Decisions

Options to compare in the session:

- chezmoi `archive` externals from the Nerd Fonts GitHub releases into `~/.local/share/fonts/<family>/`, with `include` patterns and a weekly refresh; works on any distro, no root;
- apt packages (`fonts-cascadia-code`, `fonts-jetbrains-mono`) for the upstream fonts plus externals for the patched variants;
- a font manager installed through mise (for example `getnf`).

Default proposal: externals for Nerd Fonts and iA Writer, apt for Libertinus, one `run_onchange_after_` script running `fc-cache -f` hashed on the externals file.

## Risks / Trade-offs

- [Risk] Large archives slow every apply. → `include` only the needed styles; weekly refresh.
- [Risk] Font names differ between releases (`NF`, `Nerd Font`, `Nerd Font Mono`). → Check with `fc-list : family | sort -u` before editing configs.

## Open Questions

- Which family for terminals?

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
