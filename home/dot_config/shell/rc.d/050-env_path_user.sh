## User's private bin directories, first on PATH

# bin, sbin, .local/bin and .local/sbin of the home, those that exist, in this order of preference:
# each call puts its directory in front, so the last one named ends up first.
_path_prepend "$HOME/bin" "$HOME/sbin" "$HOME/.local/bin" "$HOME/.local/sbin"

# vim: set syntax=sh :
