## Rust setup

# The rustup that brew installs keeps its proxies in its own opt directory: the path `brew --prefix rustup` prints,
# without starting brew (and the brew-file wrapper), which costs about half a second.
if [ -n "${HOMEBREW_PREFIX:-}" ]; then
  _path_prepend "${HOMEBREW_PREFIX}/opt/rustup/bin"
fi

# vim: set syntax=sh :
