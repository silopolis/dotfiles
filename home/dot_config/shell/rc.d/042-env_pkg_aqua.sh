## Aqua package manager

if command -v aqua > /dev/null 2>&1; then
  export AQUA_ROOT_DIR="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua}"
  # An inherited AQUA_BIN_DIR stays as it is: a nested shell must not add one more level to it.
  export AQUA_BIN_DIR="${AQUA_BIN_DIR:-${AQUA_ROOT_DIR}/bin}"
  _path_prepend "${AQUA_BIN_DIR}"
  #source <(aqua completion $CURRENT_SHELL)
fi

# vim: set syntax=sh :
