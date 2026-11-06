## Aqua package manager

if command -v aqua &> /dev/null; then
  export AQUA_ROOT_DIR="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua}"
  export AQUA_BIN_DIR="${AQUA_BIN_DIR:-${AQUA_ROOT_DIR}}/bin"
  export PATH="${AQUA_BIN_DIR}:$PATH"
  #source <(aqua completion $CURRENT_SHELL)
fi

# vim: set syntax=sh :
