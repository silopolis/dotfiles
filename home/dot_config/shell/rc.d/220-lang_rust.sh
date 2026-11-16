## Rust setup

# The rustup that brew installs keeps its proxies in its own opt directory: the path `brew --prefix rustup` prints,
# without starting brew (and the brew-file wrapper), which costs about half a second.
if [ -d "${HOMEBREW_PREFIX:-}/opt/rustup/bin" ]; then
  PATH="${HOMEBREW_PREFIX}/opt/rustup/bin:$PATH"
fi

export PATH

# vim: set syntax=sh :
