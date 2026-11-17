#!/usr/bin/env bash
# Listings of a shell started on a render, and their comparison with the listings of another render: plain bash, no bats.
# Source it (`. tests/helpers/compare.sh`; it loads render.sh), or call one function:
#   tests/helpers/compare.sh <function> [args...]
#
# Provides (each works on the home named by DT_HOME, made by dt_prepare_home):
#   dt_list_names TAG            the aliases and functions of an interactive zsh or bash, as `alias NAME` and `function NAME`
#   dt_list_login_names TAG      the exported variable names of `TAG -l -i`
#   dt_list_desktop              the environment of the display manager's call replayed (a non-interactive zsh that
#                                sources the profile files), as NAME=value; the scratch home is written S, a name that
#                                matches the secret pattern is listed without its value, and the shell's own
#                                bookkeeping variables are left out
#   dt_diff_lists A B [ALLOW]    the lines that only one of two sorted listings holds, minus the entries of the ALLOW file
#                                (one per line: a whole listing line, or just the alias, function or variable name);
#                                prints the number of lines and the lines, and returns 1 when any is left
#
# The listings hold names of the repository (aliases, functions) and of the shell's own variables, never a
# value of a name that matches the secret pattern.

# shellcheck disable=SC2016  # the snippets are text for another shell, single-quoted on purpose
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/render.sh"
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/synth.sh"

dt_list_names() {
  local tag=${1:?dt_list_names TAG} snippet
  case $tag in
    zsh) snippet='print -r -- @@alias; print -rl -- ${(ko)aliases}; print -r -- @@function; print -rl -- ${(ko)functions}' ;;
    bash) snippet='echo @@alias; alias | sed "s/^alias \([^=]*\)=.*/\1/"; echo @@function; declare -F | awk "{print \$3}"' ;;
    *) return 2 ;;
  esac
  dt_start_pty -- "$tag" -i -c "$snippet" 2> /dev/null | tr -d '\r' \
    | awk '/^@@alias$/ {k = "alias"; next} /^@@function$/ {k = "function"; next} k {print k " " $0}' | sort -u
}

dt_list_login_names() {
  local tag=${1:?dt_list_login_names TAG}
  dt_start_pty -- "$tag" -l -i -c env 2> /dev/null | tr -d '\r' | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' | cut -d= -f1 | sort -u
}

dt_list_desktop() {
  dt_start "$(dt_unset_name)=$(dt_canary 4)" -- zsh -c 'emulate -R zsh; [ -f /etc/zsh/zprofile ] && . /etc/zsh/zprofile; [ -f $HOME/.zprofile ] && . $HOME/.zprofile; env' 2> /dev/null \
    | sed -e "s#$DT_HOME#S#g" | grep -v -E '^(__MISE_SESSION|__MISE_DIFF|SHLVL|_)=' \
    | awk -F= -v pat="$DT_SECRET_PATTERN" '{ if ($1 ~ pat) print $1 "=<omitted>"; else print $0 }' | sort
}

dt_diff_lists() {
  local a=${1:?dt_diff_lists A B} b=${2:?dt_diff_lists A B} allow=${3:-} line name left='' n=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    # an allowed entry is a whole line, or the name in it: an alias or function name, or the name before `=`
    name=${line#alias }
    name=${name#function }
    name=${name%%=*}
    if [ -n "$allow" ] && [ -f "$allow" ] && grep -qxF -e "$line" -e "$name" "$allow"; then
      continue
    fi
    left+=$line$'\n'
    n=$((n + 1))
  done < <(comm -3 "$a" "$b" | sed 's/^\t//')
  [ "$n" -eq 0 ] && return 0
  printf '%s differences:\n%s' "$n" "$left"
  return 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn=${1:?usage: compare.sh <function> [args...]}
  shift
  "$fn" "$@"
fi
