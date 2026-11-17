#!/usr/bin/env bash
# Shared by the tests and by tests/run.sh: plain bash, no bats.
# Source it (`. tests/helpers/common.sh`), or call one function from a shell or another runner:
#   tests/helpers/common.sh <function> [args...]
#
# Provides:
#   DT_ROOT, DT_TESTS_DIR      the repository root and its tests directory, from the location of this file
#   DOTFILES_TEST_SOURCE       the tree under test: a directory holding .chezmoiroot and home/
#                              (default DT_ROOT; the mutants point it at a scratch copy)
#   DT_SECRET_PATTERN          the name fragments of the agent-environment requirement, as an extended regex
#   dt_source_file RELATIVE    the path of a file of the source state, below the directory that .chezmoiroot names
#   dt_find_tool NAME          print the path of a usable tool, or return 1
#   dt_resolve_tools [NAME...] export DT_TOOL_<NAME> for each tool found (default: DT_KNOWN_TOOLS) and
#                              DT_TOOLS_RESOLVED=1: done once, before HOME is replaced by a scratch home
#   dt_shell_path SHELL        print the path of a shell build: zsh, bash (system) or brewbash
#   dt_gnu_time                print the path of GNU time, or return 1
#   dt_jobs                    print the number of jobs for a parallel run (cores, at most 8)
#   dt_secret_names            print the exported variable names of this shell that match the pattern
#   dt_secret_name_counts      print two numbers, "upper any": how many exported names match the pattern in upper
#                              case, and how many match it in any case (counts only, never a name)
#
# A function returns a status and prints a reason on standard error; it never skips or fails a test.
# The bats glue (the directory tests/helpers/bats) turns a status into a skip.

DT_HELPERS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
DT_TESTS_DIR=$(dirname "$DT_HELPERS_DIR")
DT_ROOT=$(dirname "$DT_TESTS_DIR")
: "${DOTFILES_TEST_SOURCE:=$DT_ROOT}"
export DOTFILES_TEST_SOURCE

# Name fragments of the variables that the opencode function removes from the agent's environment.
# A test checks that this is the pattern of home/dot_config/shell/rc.d/445-tools_opencode.sh.
DT_SECRET_PATTERN='(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY|ACCESS_?KEY|PRIVATE_?KEY|CREDENTIAL)'

# dt_source_file RELATIVE: where chezmoi reads the file, whatever .chezmoiroot says (the mutants copy it too).
dt_source_file() {
  local root
  root=$(cat "${DOTFILES_TEST_SOURCE:?}/.chezmoiroot" 2> /dev/null) || root=.
  printf '%s\n' "$DOTFILES_TEST_SOURCE/${root:-.}/${1:?dt_source_file RELATIVE}"
}

# The home of the user who runs the suite: only the live tests and the tool lookup read it.
dt_real_home() {
  printf '%s\n' "${DOTFILES_TEST_REAL_HOME:-$HOME}"
}

# The Homebrew prefix: the variable of a shell that ran `brew shellenv`, else the parent of the bin
# directory of a `brew` found on PATH. Never a path written in a file.
dt_brew_prefix() {
  local brew
  if [ -n "${HOMEBREW_PREFIX:-}" ]; then
    printf '%s\n' "$HOMEBREW_PREFIX"
    return 0
  fi
  brew=$(type -P brew) || return 1
  printf '%s\n' "${brew%/bin/brew}"
}

# The tools that tests look up through dt_find_tool; run.sh resolves them before it hides the real home.
DT_KNOWN_TOOLS=(bats shellcheck script jq unzip python3 mise hostnamectl lscpu chezmoi git vim)

# dt_find_tool NAME: the first usable executable of that name on PATH.
# A mise shim whose tool is not active in this directory is on PATH but fails when run: it is asked
# through `mise which`, and passed over (the next directory of PATH is tried) when mise does not give
# a usable path. A tool that is not on PATH is absent: the standard directories are not searched, so a
# PATH without the tool makes it missing.
dt_find_tool() {
  local name=$1 p found seen=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    seen=1
    case $p in
      */shims/*)
        if command -v mise > /dev/null 2>&1; then
          found=$(mise which "$name" 2> /dev/null) || found=
          if [ -n "$found" ] && [ -x "$found" ]; then
            printf '%s\n' "$found"
            return 0
          fi
          continue
        fi
        ;;
    esac
    printf '%s\n' "$p"
    return 0
  done < <(type -aP "$name" 2> /dev/null)
  if [ "$seen" -eq 1 ]; then
    printf 'dt_find_tool: %s is only a mise shim that is not active here\n' "$name" >&2
  else
    printf 'dt_find_tool: no %s on PATH\n' "$name" >&2
  fi
  return 1
}

# dt_resolve_tools [NAME...]: look the tools up once and export DT_TOOL_<NAME> (upper case, hyphens as
# underscores) for each one found. A tool that is not found leaves its variable unset, and a variable that
# already names an executable is kept (a nested run is handed the paths of its parent). The tests read the
# variables (require_tool), so the lookup does not depend on the home they run with.
dt_resolve_tools() {
  local name var path names=("$@")
  [ $# -gt 0 ] || names=("${DT_KNOWN_TOOLS[@]}")
  for name in "${names[@]}"; do
    var=DT_TOOL_$(printf '%s' "${name^^}" | tr -c 'A-Z0-9\n' '_')
    if [ -n "${!var:-}" ] && [ -x "${!var}" ]; then
      continue
    fi
    if path=$(dt_find_tool "$name" 2> /dev/null); then
      export "$var=$path"
    else
      unset "$var"
    fi
  done
  export DT_TOOLS_RESOLVED=1
}

# dt_shell_path zsh|bash|brewbash
dt_shell_path() {
  local prefix p
  case $1 in
    zsh)
      if [ -x /usr/bin/zsh ]; then
        printf '%s\n' /usr/bin/zsh
      else
        type -P zsh || { printf 'dt_shell_path: no zsh\n' >&2; return 1; }
      fi
      ;;
    bash)
      # the system build, not the first bash of PATH (a Homebrew shell puts its own first)
      for p in /usr/bin/bash /bin/bash; do
        if [ -x "$p" ]; then
          printf '%s\n' "$p"
          return 0
        fi
      done
      printf 'dt_shell_path: no system bash\n' >&2
      return 1
      ;;
    brewbash)
      prefix=$(dt_brew_prefix 2> /dev/null) || prefix=
      if [ -n "$prefix" ] && [ -x "$prefix/bin/bash" ]; then
        printf '%s\n' "$prefix/bin/bash"
      else
        printf 'dt_shell_path: no Homebrew bash (HOMEBREW_PREFIX is unset or holds no bin/bash)\n' >&2
        return 1
      fi
      ;;
    *)
      printf 'dt_shell_path: unknown shell %s\n' "$1" >&2
      return 1
      ;;
  esac
}

# dt_gnu_time: `time` is a reserved word in bash and zsh, so the binary is called by path.
# Resolved at run time: the brew package first, then a distribution `time` whose --version names GNU.
dt_gnu_time() {
  local prefix p
  prefix=$(dt_brew_prefix 2> /dev/null) || prefix=
  if [ -n "$prefix" ] && [ -x "$prefix/opt/gnu-time/bin/time" ]; then
    printf '%s\n' "$prefix/opt/gnu-time/bin/time"
    return 0
  fi
  for p in /usr/bin/time /usr/local/bin/time /bin/time; do
    if [ -x "$p" ] && "$p" --version 2>&1 | grep -q 'GNU'; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  printf 'dt_gnu_time: no GNU time (the timing tests use date)\n' >&2
  return 1
}

# dt_jobs: jobs of a parallel run, the number of cores capped at 8.
dt_jobs() {
  local n
  n=$(nproc 2> /dev/null || echo 1)
  [ "$n" -gt 8 ] && n=8
  printf '%s\n' "$n"
}

# dt_secret_names: the names of the exported variables of this shell that match the secret pattern.
# Callers keep them in memory (a variable or a pipe) and print a count, never a name.
dt_secret_names() {
  env | sed -n 's/^\([A-Z_][A-Z0-9_]*\)=.*/\1/p' | grep -E "$DT_SECRET_PATTERN" || true
}

# dt_secret_name_counts: the live test of the wrapper compares the two numbers, taken before run.sh hides anything.
dt_secret_name_counts() {
  local upper any
  upper=$(env | cut -d= -f1 | grep -Ec "$DT_SECRET_PATTERN" || true)
  any=$(env | cut -d= -f1 | grep -Eic "$DT_SECRET_PATTERN" || true)
  printf '%s %s\n' "$upper" "$any"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn=${1:?usage: common.sh <function> [args...]}
  shift
  "$fn" "$@"
fi
