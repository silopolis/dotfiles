## Krew plugin manager for kubectl

export KREW_ROOT="${KREW_ROOT:-$HOME/.krew}"
# FIXME move KREW_PLUGIN_DIR to .local/[share|lib]/krew
export KREW_PLUGINS_DIR="${KREW_PLUGINS_DIR:-$KREW_ROOT/bin}"

if [ -d "$KREW_PLUGINS_DIR" ]; then
  PATH="$KREW_PLUGINS_DIR:$PATH"
fi

export PATH

# vim: set syntax=sh :
