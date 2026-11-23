#!/usr/bin/env bash
# The shell kinds of the shell-environment capability, started on a scratch render: plain bash, no bats.
# Source it (`. tests/helpers/kinds.sh`; it loads render.sh and fixtures.sh), or call one function:
#   tests/helpers/kinds.sh <function> [args...]
# Every function works on the home named by DT_HOME, made by dt_prepare_home, and starts its shells with
# dt_start or dt_start_pty (env -i, a scratch home, mise confined to it). The environment a kind is handed is
# the one a desktop terminal gets from the user manager: the PATH that /etc/profile gives a login shell, the
# session LANG, SHELL, USER and LOGNAME. Extra `VAR=value` arguments come after it and win.
#
# The kinds (names are the first column):
#   desktop         the call of the display manager replayed: a non-interactive zsh, emulate -R zsh, then
#                   /etc/zsh/zprofile and ~/.zprofile sourced
#   zsh-i, zsh-li, bash-i, bash-li      zsh -i, zsh -l -i, bash -i, bash -l -i, under a pseudo-terminal
#   zsh-lc, zsh-c, bash-lc, bash-c      zsh -l -c, zsh -c, bash -l -c, bash -c
#   zsh-i-nolang, bash-i-nolang, bash-li-nolang    the interactive kinds started without LANG (env -u LANG)
#   bash-ssh        bash -c as sshd starts it for a command: SSH_CLIENT set and a shell level of 0
#
# Provides:
#   dt_kinds                     the thirteen kind names, one per line
#   dt_kinds_env                 the ten that load the environment (every kind but zsh-c, bash-c and bash-ssh)
#   dt_login_path                the PATH that /etc/profile gives a login shell, read at run time from a login bash
#                                under an empty scratch home (no user file), so that it is what the machine produces
#   dt_kind_lang                 the LANG of the session: fr_FR.UTF-8 when it is generated, else C.UTF-8
#   dt_kind_run KIND SNIPPET [VAR=value ...]
#                                run SNIPPET (POSIX, for zsh and bash) in that kind; print its standard output and
#                                error together, carriage returns removed; a test makes its own markers (`@@NAME=value`)
#   dt_kind_value KIND NAME [VAR=value ...]       print the value of a variable after startup, `<unset>` when not set
#   dt_kind_path KIND [VAR=value ...]             print PATH after startup
#   dt_kind_exported KIND NAME... [VAR=value ...] print how many of the names the kind exports (a count)
#   dt_kind_export_names KIND [VAR=value ...]     print the names the kind exports, sorted, one per line
#   dt_kind_debug_count KIND PATTERN [VAR=value ...]   print how many lines that match the grep pattern a start
#                                with SHELL_RC_DEBUG=1 prints (the lines hold no value)
#   dt_kind_locale_warnings KIND [VAR=value ...]  print how many lines of a start and of a child `perl -e1` hold
#                                `setlocale` or `locale failed`, in any case
#
# Every function that prints a fact prints a number or a public value (a PATH of the scratch home, a name from the
# scratch render): no value of the real environment is read, because the shells run under env -i.

# shellcheck disable=SC2016  # the snippets are text for another shell, single-quoted on purpose
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/render.sh"
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

dt_kinds() {
  printf '%s\n' desktop zsh-i zsh-li bash-i bash-li zsh-lc zsh-c bash-lc bash-c zsh-i-nolang bash-i-nolang bash-li-nolang bash-ssh
}

dt_kinds_env() {
  printf '%s\n' desktop zsh-i zsh-li bash-i bash-li zsh-lc bash-lc zsh-i-nolang bash-i-nolang bash-li-nolang
}

dt_login_path() {
  local bash_bin dir path
  bash_bin=$(dt_shell_path bash) || return 2
  dir=$(mktemp -d "${TMPDIR:-/tmp}/dt-login.XXXXXX") || return 2
  path=$(env -i HOME="$dir" PATH=/usr/bin:/bin LANG=C.UTF-8 "$bash_bin" -l -c 'printf "%s" "$PATH"' < /dev/null 2> /dev/null)
  case $dir in
    */dt-login.*) rm -rf -- "$dir" ;;
  esac
  [ -n "$path" ] || return 1
  printf '%s\n' "$path"
}

dt_kind_lang() {
  if dt_locale_generated fr_FR.UTF-8; then
    printf '%s\n' fr_FR.UTF-8
  else
    printf '%s\n' C.UTF-8
  fi
}

dt_kind_run() {
  local kind=${1:?dt_kind_run KIND SNIPPET [VAR=value ...]} snippet=${2:?dt_kind_run KIND SNIPPET [VAR=value ...]}
  local zsh_bin bash_bin user login_path pty=0 cmd=() extra=()
  shift 2
  zsh_bin=$(dt_shell_path zsh) || return 2
  bash_bin=$(dt_shell_path bash) || return 2
  user=$(id -un)
  login_path=$(dt_login_path) || return 2
  case $kind in
    desktop) cmd=("$zsh_bin" -c "emulate -R zsh; [ -f /etc/zsh/zprofile ] && . /etc/zsh/zprofile; [ -f \"\$HOME/.zprofile\" ] && . \"\$HOME/.zprofile\"; $snippet") ;;
    zsh-i) pty=1 cmd=("$zsh_bin" -i -c "$snippet") ;;
    zsh-li) pty=1 cmd=("$zsh_bin" -l -i -c "$snippet") ;;
    bash-i) pty=1 cmd=("$bash_bin" -i -c "$snippet") ;;
    bash-li) pty=1 cmd=("$bash_bin" -l -i -c "$snippet") ;;
    zsh-lc) cmd=("$zsh_bin" -l -c "$snippet") ;;
    zsh-c) cmd=("$zsh_bin" -c "$snippet") ;;
    bash-lc) cmd=("$bash_bin" -l -c "$snippet") ;;
    bash-c) cmd=("$bash_bin" -c "$snippet") ;;
    zsh-i-nolang) pty=1 cmd=(env -u LANG "$zsh_bin" -i -c "$snippet") ;;
    bash-i-nolang) pty=1 cmd=(env -u LANG "$bash_bin" -i -c "$snippet") ;;
    bash-li-nolang) pty=1 cmd=(env -u LANG "$bash_bin" -l -i -c "$snippet") ;;
    bash-ssh)
      extra=(SSH_CLIENT="ssh-client-demo 50000 22" SHLVL=0)
      cmd=("$bash_bin" -c "$snippet")
      ;;
    *)
      printf 'dt_kind_run: unknown kind %s\n' "$kind" >&2
      return 2
      ;;
  esac
  if [ "$pty" -eq 1 ]; then
    DT_START_PATH=$login_path dt_start_pty LANG="$(dt_kind_lang)" SHELL=/usr/bin/zsh USER="$user" LOGNAME="$user" "${extra[@]}" "$@" -- "${cmd[@]}" 2>&1 | tr -d '\r'
  else
    DT_START_PATH=$login_path dt_start LANG="$(dt_kind_lang)" SHELL=/usr/bin/zsh USER="$user" LOGNAME="$user" "${extra[@]}" "$@" -- "${cmd[@]}" 2>&1
  fi
}

# _dt_kind_split ARGS...: the arguments with an `=` are variables (a name has none), the others are names
_dt_kind_split() {
  _dtk_names=()
  _dtk_vars=()
  local a
  for a in "$@"; do
    case $a in
      *=*) _dtk_vars+=("$a") ;;
      *) _dtk_names+=("$a") ;;
    esac
  done
}

dt_kind_value() {
  local kind=${1:?dt_kind_value KIND NAME [VAR=value ...]} name=${2:?dt_kind_value KIND NAME [VAR=value ...]} snippet
  shift 2
  printf -v snippet 'printf "@@V=%%s\\n" "${%s-<unset>}"' "$name"
  dt_kind_run "$kind" "$snippet" "$@" | sed -n 's/^@@V=//p' | tail -n 1
}

dt_kind_path() {
  local kind=${1:?dt_kind_path KIND [VAR=value ...]}
  shift
  dt_kind_value "$kind" PATH "$@"
}

dt_kind_exported() {
  local kind=${1:?dt_kind_exported KIND NAME... [VAR=value ...]} n args='' snippet
  shift
  _dt_kind_split "$@"
  for n in "${_dtk_names[@]}"; do
    args+=" -e $n"
  done
  printf -v snippet 'printf "@@N=%%s\\n" "$(env | cut -d= -f1 | grep -cx%s)"' "$args"
  dt_kind_run "$kind" "$snippet" "${_dtk_vars[@]}" | sed -n 's/^@@N=//p' | tail -n 1
}

dt_kind_export_names() {
  local kind=${1:?dt_kind_export_names KIND [VAR=value ...]}
  shift
  dt_kind_run "$kind" 'env | sed -n "s/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/@@X \1/p"' "$@" | sed -n 's/^@@X //p' | sort -u
}

dt_kind_debug_count() {
  local kind=${1:?dt_kind_debug_count KIND PATTERN [VAR=value ...]} pattern=${2:?dt_kind_debug_count KIND PATTERN [VAR=value ...]}
  shift 2
  dt_kind_run "$kind" true SHELL_RC_DEBUG=1 "$@" | grep -c -e "$pattern" || true
}

dt_kind_locale_warnings() {
  local kind=${1:?dt_kind_locale_warnings KIND [VAR=value ...]}
  shift
  dt_kind_run "$kind" 'perl -e1' "$@" | grep -c -i -e setlocale -e 'locale failed' || true
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn=${1:?usage: kinds.sh <function> [args...]}
  shift
  "$fn" "$@"
fi
