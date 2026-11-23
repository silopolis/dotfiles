## Mise-en-place: the directory of its shims

# Every tool that mise manages is reachable from the desktop session and from a shell that does not activate mise.
# The activation of an interactive shell (415-tools_mise.sh) puts its own tool directories in front of this one.
_path_prepend "${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims"

# vim: set syntax=sh :
