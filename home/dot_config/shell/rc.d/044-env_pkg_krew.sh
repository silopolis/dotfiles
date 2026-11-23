## Krew plugin manager for kubectl

export KREW_ROOT="${KREW_ROOT:-$HOME/.krew}"
# FIXME move KREW_PLUGIN_DIR to .local/[share|lib]/krew
export KREW_PLUGINS_DIR="${KREW_PLUGINS_DIR:-$KREW_ROOT/bin}"

_path_prepend "$KREW_PLUGINS_DIR"

# vim: set syntax=sh :
