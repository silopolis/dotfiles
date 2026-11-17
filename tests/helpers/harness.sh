#!/usr/bin/env bash
# The two modes of the install-script harness: run one rendered script with every tool it calls replaced by a logging
# stub. Plain bash, no bats. Source it (`. tests/helpers/harness.sh`; it loads scripts.sh), or call one function:
#   tests/helpers/harness.sh <function> [args...]
#
#   isolated   a scratch HOME (a copy of FIXDIR/userhome when there is one), a PATH of the stubs and of a curated directory of
#              base utilities (dt_realbin) only, and standard input from /dev/null: the script can call nothing but stubs,
#              which log their arguments and answer from FIXDIR/<tool>.
#   live       read-only mode: the real HOME and PATH; the stub forwards an allow-list of read-only calls to the real tool
#              and refuses and logs everything else. `sudo` is a logging stub in both modes: it is never run.
# A script passes when it exits 0 and both the sudo log and the refused log are empty.
#
# Provides:
#   dt_harness_run [-m isolated|live] [-n NAME] [-f FIXDIR] [-s FROM=TO]... [-e VAR=VALUE]... [-a TOOL]...
#                  [-x N] [-u N] [-P] [-E] [-K] SCRIPT
#       -n  name of the run (default: script name and mode); its files are in dt_harness_logdir NAME
#       -f  fixture directory: FIXDIR/userhome is copied to the scratch HOME, FIXDIR/<tool> answers for a stub
#       -s  text substitution applied to a copy of the script (an absolute system path aimed at a scratch file)
#       -e  a variable for the script's environment
#       -a  leave this tool out (missing): its stub, and its link in the curated directory
#       -x, -u  exit status of a refused call (default 1) and of the sudo stub (isolated 0, live 1)
#       -P  leave HOMEBREW_PREFIX unset;  -E  isolated only: sudo logs, then runs the command as the plain user
#       -K  isolated only: keep the scratch HOME of the previous run of the same name, with every log reset
#       The status of the function is the script's (3 when isolated mode refuses it).
#   dt_harness_logdir NAME      the directory of the files of a run: calls.log sudo.log refused.log out.log status home
#   dt_harness_summary NAME     one line: status and the numbers of calls, sudo calls and refused calls
#
# Variables: DT_HARNESS_ROOT (required: the scratch directory that holds the runs), DT_ISO_ROOT (a scratch directory
# whose subdirectories an isolated script may list in use_tool_dirs; `~/` entries are always allowed).
# Isolated mode refuses a script whose use_tool_dirs lists any other directory: a real /usr/bin or Homebrew bin
# in front of the stubs would let real tools run. Live mode only reads: it takes HOME, PATH and the Homebrew
# variables from the environment of the suite, and its real HOME is DOTFILES_TEST_REAL_HOME.

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/scripts.sh"

# The tools that the install scripts call and that a run replaces by the stub.
DT_HARNESS_TOOLS=(sudo apt-get dpkg-query brew pipx mise kubectl kubectl-krew codium vim gh rustup bat unzip chezmoi curl python3)

dt_harness_logdir() {
  printf '%s\n' "${DT_HARNESS_ROOT:?DT_HARNESS_ROOT is not set}/logs/${1:?dt_harness_logdir NAME}"
}

dt_harness_summary() {
  local d
  d=$(dt_harness_logdir "$1")
  printf '== %s exit=%s calls=%s sudo=%s refused=%s\n' "$1" "$(cat "$d/status" 2> /dev/null || echo '?')" \
    "$(wc -l < "$d/calls.log")" "$(wc -l < "$d/sudo.log")" "$(wc -l < "$d/refused.log")"
}

# The [env] table of the synthetic configuration, as NAME=value lines: the variables that chezmoi hands to its scripts.
# `$HOME` in a value is the home of the run (its scratch home, or the real one in live mode).
dt_harness_config_env() {
  local home=${1:-$HOME}
  [ -n "${DT_SCRIPT_CONFIG:-}" ] || return 0
  sed -n '/^\[env\]/,/^$/p' "$DT_SCRIPT_CONFIG" | sed -n 's/^\([A-Z_][A-Z0-9_]*\) = "\(.*\)"[[:space:]]*\(#.*\)\{0,1\}$/\1=\2/p' \
    | while IFS= read -r line; do printf '%s\n' "${line//\$HOME/$home}"; done
}

dt_harness_run() {
  local mode='' name='' fix='' refuse_exit=1 sudo_exit='' unset_prefix=0 sudo_exec=0 keep_home=0 opt
  local subs=() envs=() absent=()
  OPTIND=1
  while getopts m:n:f:s:e:a:x:u:PEK opt; do
    case $opt in
      m) mode=$OPTARG ;;
      n) name=$OPTARG ;;
      f) fix=$OPTARG ;;
      s) subs+=("$OPTARG") ;;
      e) envs+=("$OPTARG") ;;
      a) absent+=("$OPTARG") ;;
      x) refuse_exit=$OPTARG ;;
      u) sudo_exit=$OPTARG ;;
      P) unset_prefix=1 ;;
      E) sudo_exec=1 ;;
      K) keep_home=1 ;;
      *) return 2 ;;
    esac
  done
  shift $((OPTIND - 1))
  local script=${1:?dt_harness_run: script path}
  case $mode in isolated | live) ;; *)
    printf 'dt_harness_run: -m isolated|live\n' >&2
    return 2
    ;;
  esac
  [ -n "$name" ] || name=$(basename "$script")-$mode
  if [ -z "$sudo_exit" ]; then
    if [ "$mode" = live ]; then sudo_exit=1; else sudo_exit=0; fi
  fi

  local logdir kept='' t a skip home real_path path d content py3 status
  logdir=$(dt_harness_logdir "$name")
  if [ "$keep_home" -eq 1 ] && [ "$mode" = isolated ] && [ -d "$logdir/userhome" ]; then
    kept=$DT_HARNESS_ROOT/.kept-home.$$
    rm -rf -- "$kept"
    mv -- "$logdir/userhome" "$kept"
  fi
  rm -rf -- "$logdir"
  mkdir -p -- "$logdir/bin"
  chmod 0700 -- "$logdir"
  : > "$logdir/calls.log"
  : > "$logdir/sudo.log"
  : > "$logdir/refused.log"
  for t in "${DT_HARNESS_TOOLS[@]}"; do
    skip=0
    for a in "${absent[@]:-}"; do [ "$a" = "$t" ] && skip=1; done
    [ "$skip" -eq 1 ] || ln -s -- "$DT_HELPERS_DIR/stub" "$logdir/bin/$t"
  done

  if [ "$mode" = isolated ]; then
    home=$logdir/userhome
    if [ -n "$kept" ]; then
      mv -- "$kept" "$home"
    else
      mkdir -p -- "$home"
      chmod 0700 -- "$home"
      if [ -n "$fix" ] && [ -d "$fix/userhome" ]; then
        cp -a -- "$fix/userhome/." "$home/"
      fi
    fi
    # curated utilities only: no real copy of a stubbed tool (vim, python3, curl...) can be found when its stub is left
    # out with -a; -a also drops a curated utility (jq) from this run's directory
    mkdir -p -- "$logdir/real"
    dt_realbin "$logdir/real"
    for a in "${absent[@]:-}"; do
      [ -n "$a" ] && rm -f -- "$logdir/real/$a"
    done
    real_path=$logdir/real
    path=$logdir/bin:$logdir/real
  else
    home=$(dt_real_home)
    real_path=$PATH
    path=$logdir/bin:$PATH
  fi

  cp -- "$script" "$logdir/script.sh"
  for a in "${subs[@]:-}"; do
    [ -n "$a" ] || continue
    content=$(< "$logdir/script.sh")
    content=${content//"${a%%=*}"/"${a#*=}"}
    printf '%s\n' "$content" > "$logdir/script.sh"
  done

  # The directories the script puts on its PATH (its use_tool_dirs call). Isolated mode must never let a real directory in
  # front of the stubs: refuse any that is not below ~ (the scratch HOME) or DT_ISO_ROOT. Live mode appends them.
  local tool_dirs=()
  while IFS= read -r d; do tool_dirs+=("$d"); done < <(grep -E '^use_tool_dirs ' "$logdir/script.sh" | grep -o "'[^']*'" | tr -d "'")
  for d in "${tool_dirs[@]:-}"; do
    [ -n "$d" ] || continue
    if [ "$mode" = isolated ]; then
      # the literal tilde is the marker that the tools-use template writes, not a path to expand
      # shellcheck disable=SC2088
      case $d in
        '~/'*) ;;
        *)
          if [ -z "${DT_ISO_ROOT:-}" ] || [ "${d#"$DT_ISO_ROOT"/}" = "$d" ]; then
            printf 'harness: isolated mode refused: use_tool_dirs lists %s, a real directory that would come before the stubs on PATH\n' "$d" >&2
            printf '3\n' > "$logdir/status"
            return 3
          fi
          ;;
      esac
    else
      d=${d/#\~\//$home/}
      case ":$path:" in
        *":$d:"*) ;;
        *) path="$path:$d" ;;
      esac
    fi
  done

  # The Homebrew variables that a shell which ran `brew shellenv` holds. `brew shellenv` puts the real brew directory in
  # front of the stubs, so a script must never evaluate it here: it is told the prefix (live: the real one).
  local brewvars=() prefix cfgenv=()
  if [ "$unset_prefix" -eq 0 ]; then
    if [ "$mode" = live ]; then
      prefix=$(dt_brew_prefix 2> /dev/null) || prefix=
      brewvars=(HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-$prefix}" HOMEBREW_CELLAR="${HOMEBREW_CELLAR:-$prefix/Cellar}"
        HOMEBREW_REPOSITORY="${HOMEBREW_REPOSITORY:-$prefix}")
    else
      brewvars=(HOMEBREW_PREFIX="$logdir/prefix")
    fi
  fi
  mapfile -t cfgenv < <(dt_harness_config_env "$home")

  py3=$(dt_find_tool python3 2> /dev/null) || py3=
  {
    printf 'HARNESS_MODE=%q\n' "$mode"
    printf 'HARNESS_LOG=%q\n' "$logdir"
    printf 'HARNESS_BIN=%q\n' "$logdir/bin"
    printf 'REAL_PATH=%q\n' "$real_path"
    printf 'HARNESS_FIX=%q\n' "$fix"
    printf 'SUDO_EXIT=%q\n' "$sudo_exit"
    printf 'HARNESS_PY3=%q\n' "$py3"
    printf 'SUDO_EXEC=%q\n' "$sudo_exec"
    printf 'REFUSE_EXIT=%q\n' "$refuse_exit"
  } > "$logdir/env"

  status=0
  (
    cd "$home" || exit 99
    env -i HOME="$home" PATH="$path" TERM=dumb LANG=C.UTF-8 USER=demo LOGNAME=demo \
      HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1 \
      "${brewvars[@]}" "${cfgenv[@]}" "${envs[@]}" \
      bash "$logdir/script.sh" < /dev/null > "$logdir/out.log" 2>&1
  ) || status=$?
  printf '%s\n' "$status" > "$logdir/status"
  return "$status"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn=${1:?usage: harness.sh <function> [args...]}
  shift
  "$fn" "$@"
fi
