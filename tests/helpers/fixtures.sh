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
#   dt_write_private_env FILE   a synthetic private environment file (what ~/.config/env is on a machine): two exports
#                               with the names of dt_alpha_name and dt_beta_name and plain demo values
#   dt_write_zsh_history FILE   a synthetic zsh history file in the extended format (`: <time>:<seconds>;<command>`): five
#                               entries from 1700000100 to 1700000500, two of them on several lines (a backslash at the
#                               end of a line continues the entry); mode 0600
#   dt_write_zsh_history_extra FILE  a second one, five entries: one of the first file's (1700000300) and four others,
#                               two of them between the first file's entries and one on two lines
#   dt_write_bash_history FILE   a synthetic bash history file, four plain lines, one command typed twice; mode 0600
#   dt_write_bash_history_extra FILE  a second one, five lines: the repeated command three times and two other lines
#   dt_locale_generated NAME     succeed when `locale -a` lists the locale, names compared without case and without `-`
#   dt_missing_locale            print the name of a locale that no machine generates (`locale -a` never lists it)
#   dt_make_startup_tools DIR   DIR/bin/<tool> stubs for the eight tools whose completion scripts are cached (gh, glab,
#                               infracost, docker, kubectl, minikube, kind, localstack): a call appends a line to the
#                               file named by STUBLOG; `completion zsh` and `completion bash` print a script that
#                               registers a completion for the tool, other calls print nothing
#   dt_make_completion_tools DIR  six synthetic tools for the completion cache: DIR/inst/<name>-<version>/<name> with a
#                               VERSION file, and DIR/bin/<name> links to the first version, all older than any cache
#                               file. A tool appends a line to the file named by CALLS, then prints a completion
#                               script (two lines, the second names the version); demo-fail exits 1 and demo-empty
#                               prints nothing. Names: demo-a (versions 1 and 2), demo-b, demo-c, demo-fail, demo-empty.

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

dt_write_private_env() {
  printf 'export %s=demo-one\nexport %s=demo-two\n' "$(dt_alpha_name)" "$(dt_beta_name)" > "${1:?dt_write_private_env FILE}"
}

dt_write_zsh_history() {
  local f=${1:?dt_write_zsh_history FILE}
  (umask 077 && : > "$f")
  chmod 0600 "$f"
  cat >> "$f" << 'HISTORY'
: 1700000100:0;echo demo-one
: 1700000200:0;for i in 1 2; do\
echo demo-loop $i\
done
: 1700000300:0;echo demo-three
: 1700000400:0;echo 'demo-quote'\
echo demo-four
: 1700000500:0;echo demo-five
HISTORY
}

dt_write_zsh_history_extra() {
  local f=${1:?dt_write_zsh_history_extra FILE}
  (umask 077 && : > "$f")
  chmod 0600 "$f"
  cat >> "$f" << 'HISTORY'
: 1700000150:0;echo demo-extra-a
: 1700000250:0;echo demo-extra-b
: 1700000300:0;echo demo-three
: 1700000450:0;echo demo-extra-c\
echo demo-extra-d
: 1700000600:0;echo demo-extra-e
HISTORY
}

dt_write_bash_history() {
  local f=${1:?dt_write_bash_history FILE}
  (umask 077 && : > "$f")
  chmod 0600 "$f"
  printf '%s\n' 'echo demo-bash-one' 'ls demo-dir' 'echo demo-bash-one' 'echo demo-bash-two' >> "$f"
}

dt_write_bash_history_extra() {
  local f=${1:?dt_write_bash_history_extra FILE}
  (umask 077 && : > "$f")
  chmod 0600 "$f"
  printf '%s\n' 'echo demo-bash-one' 'echo demo-bash-one' 'echo demo-bash-one' 'echo demo-bash-three' 'ls demo-extra' >> "$f"
}

dt_locale_generated() {
  local want have
  want=${1:?dt_locale_generated NAME}
  want=${want,,}
  want=${want//-/}
  while IFS= read -r have; do
    have=${have,,}
    [ "${have//-/}" = "$want" ] && return 0
  done < <(locale -a 2> /dev/null)
  return 1
}

dt_missing_locale() {
  printf '%s\n' zz_ZZ.UTF-8
}

dt_make_startup_tools() {
  local dir=${1:?dt_make_startup_tools DIR} t
  mkdir -p -- "$dir/bin"
  for t in gh glab infracost docker kubectl minikube kind localstack; do
    cat > "$dir/bin/$t" << 'TOOL'
#!/bin/sh
[ -n "$STUBLOG" ] && echo "$(basename "$0") $*" >> "$STUBLOG"
tool=$(basename "$0")
case " $* " in
  *" completion "*) ;;
  *) exit 0 ;;
esac
case " $* " in
  *" zsh "*) printf '#compdef %s\n_stub_%s() { :; }\ncompdef _stub_%s %s\n' "$tool" "$tool" "$tool" "$tool" ;;
  *" bash "*) printf '__start_%s() { :; }\ncomplete -o default -F __start_%s %s\n' "$tool" "$tool" "$tool" ;;
esac
TOOL
    chmod 0755 "$dir/bin/$t"
  done
}

dt_make_completion_tools() {
  local dir=${1:?dt_make_completion_tools DIR} spec name ver t
  mkdir -p -- "$dir/bin"
  for spec in demo-a:1 demo-a:2 demo-b:1 demo-c:1 demo-fail:1 demo-empty:1; do
    name=${spec%%:*}
    ver=${spec#*:}
    mkdir -p -- "$dir/inst/$name-$ver"
    cat > "$dir/inst/$name-$ver/$name" << 'TOOL'
#!/bin/sh
echo "$(basename "$0") $*" >> "$CALLS"
case "$(basename "$0")" in
  demo-fail) exit 1 ;;
  demo-empty) exit 0 ;;
esac
echo "# completion script, version $(cat "$(dirname "$(readlink -f "$0")")/VERSION")"
echo ": line for $*"
TOOL
    chmod 0755 "$dir/inst/$name-$ver/$name"
    printf '%s\n' "$ver" > "$dir/inst/$name-$ver/VERSION"
    touch -d 2001-01-01 "$dir/inst/$name-$ver/$name"
  done
  for t in demo-a demo-b demo-c demo-fail demo-empty; do
    ln -sfn "$dir/inst/$t-1/$t" "$dir/bin/$t"
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn=${1:?usage: fixtures.sh <function> [args...]}
  shift
  "$fn" "$@"
fi
