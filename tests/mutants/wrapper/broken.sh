## Deliberately broken replacement of rc.d/445-tools_opencode.sh, for tests/mutants/README.md.
# The function hands the whole environment to the real binary: the wrapper tests must notice.
opencode() { command env opencode "$@"; }

# vim: set syntax=sh :
