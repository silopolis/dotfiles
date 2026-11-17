#!/usr/bin/env bash
# Fixture builders: stub tools and synthetic files made at run time in a scratch directory,
# so that no copy of a real file is committed. Plain bash, no bats.
# Source it (`. tests/helpers/fixtures.sh`; it loads common.sh and synth.sh), or call one function:
#   tests/helpers/fixtures.sh <function> [args...]
#
# Provides:
#   dt_make_opencode_stub DIR   DIR/bin/opencode, a stub that appends a line to DIR/calls.log, prints how many
#                               names of its own environment match the secret pattern (one number), a marker line,
#                               its arguments one per line and, when STUB_PRESENT lists names, a second marker and
#                               one NAME=present or NAME=absent line per name; it exits with STUB_STATUS (default 0).
#                               It never prints a value. The pattern is the suite's own (DT_SECRET_PATTERN).

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/synth.sh"

dt_make_opencode_stub() {
  local dir=${1:?dt_make_opencode_stub DIR}
  mkdir -p -- "$dir/bin"
  cat > "$dir/bin/opencode" << STUB
#!/bin/sh
here=\$(dirname "\$0")
printf 'call\n' >> "\$here/../calls.log"
names=\$(tr '\0' '\n' < /proc/\$\$/environ | cut -d= -f1)
printf '%s\n' "\$names" | grep -Ec '$DT_SECRET_PATTERN'
printf '%s\n' '--args--'
for a in "\$@"; do
  printf '%s\n' "\$a"
done
if [ -n "\$STUB_PRESENT" ]; then
  printf '%s\n' '--present--'
  for n in \$STUB_PRESENT; do
    if printf '%s\n' "\$names" | grep -qx "\$n"; then
      printf '%s=present\n' "\$n"
    else
      printf '%s=absent\n' "\$n"
    fi
  done
fi
exit "\${STUB_STATUS:-0}"
STUB
  chmod 0755 "$dir/bin/opencode"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn=${1:?usage: fixtures.sh <function> [args...]}
  shift
  "$fn" "$@"
fi
