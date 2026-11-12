# shellcheck disable=SC2329
# Shared helper of the chezmoi scripts: included right after the shebang with
#   template "script-lib.sh" "<script name>"
# It holds no data beyond the script name, so a data change reaches only the scripts that read that data.
# Editing it makes every script that includes it run once more, all of them no-ops on a provisioned machine.
set -euo pipefail

script_name={{ . | squote }}

log() { printf '%s: %s\n' "$script_name" "$*" >&2; }
warn() { printf '%s: warning: %s\n' "$script_name" "$*" >&2; }
have() { command -v "$1" > /dev/null 2>&1; }

dry_run() { [ "${CHEZMOI_SCRIPTS_DRY_RUN:-}" = 1 ]; }

# run <command...>: execute, or print the command instead when CHEZMOI_SCRIPTS_DRY_RUN=1.
# Read-only queries are written without run, so they still execute in dry-run mode.
run() {
  if dry_run; then
    printf '%s: would run:' "$script_name" >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  "$@"
}

# as_root <why> <command...>: say why root is needed, then run the command through sudo (directly when already root).
as_root() {
  local why=$1
  shift
  log "needs root: $why"
  if [ "$(id -u)" -eq 0 ]; then
    run "$@"
  else
    run sudo "$@"
  fi
}

# load_brew <prefix>: give the script the environment of the user's shell; the prefix comes from the brew.prefix data.
# Homebrew keeps its trust file under XDG_CONFIG_HOME (else ~/.homebrew): without it, third-party taps are untrusted
# and brew-file lists every installed tap formula as missing.
load_brew() {
  local prefix=${1:?load_brew needs the Homebrew prefix}
  export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
  if [ -z "${HOMEBREW_PREFIX:-}" ] && [ -x "$prefix/bin/brew" ]; then
    eval "$("$prefix/bin/brew" shellenv)"
  fi
}

# use_tool_dirs <dir>...: put the directories where the scripts look for tools on PATH (the list comes from the tools-use
# template, so it is the one the tools-present line of the script was computed from; see tools.search in the data).
# A directory that exists and is missing from PATH is prepended, in list order: with the default list a mise tool then wins over
# Homebrew and the distribution (install priority: mise, brew, apt). A directory already on PATH keeps its place.
use_tool_dirs() {
  local dir front=''
  for dir in "$@"; do
    # "~/x" is below the home directory: expanded here, so that a rendered script holds no home path.
    # The literal tilde is the marker the tools-dirs template writes, not a path to expand: the quotes are intended.
    # shellcheck disable=SC2088
    case "$dir" in
      '~/'*) dir="$HOME/${dir#'~/'}" ;;
    esac
    [ -d "$dir" ] || continue
    case ":$PATH:" in
      *":$dir:"*) ;;
      *) front="${front:+$front:}$dir" ;;
    esac
  done
  if [ -n "$front" ]; then
    PATH="$front:$PATH"
  fi
  export PATH
}

# need <tool>...: succeed when every tool is found; otherwise warn and fail, and the script ends with `exit 0` (a skip).
# chezmoi records a skip like a run, and the script's hash comment holds one `tool=present|absent` entry per tool, looked up
# in the directories of the tools-dirs template, so the script runs again at the apply after the tool appears there.
need() {
  local tool lacking=()
  for tool in "$@"; do
    have "$tool" || lacking+=("$tool")
  done
  [ "${#lacking[@]}" -eq 0 ] && return 0
  warn "${lacking[*]} not found, skipping; the script runs again once it is installed in one of the directories of tools.search"
  return 1
}

# report_undeclared <what> <installed names> <declared names>: both lists one name per line; lists the installed names
# that are not declared and never removes anything.
report_undeclared() {
  local what=$1 extra
  extra=$(LC_ALL=C comm -23 <(printf '%s\n' "$2" | LC_ALL=C sort -u) <(printf '%s\n' "$3" | LC_ALL=C sort -u) | sed '/^$/d')
  if [ -n "$extra" ]; then
    log "$what installed but not declared (nothing is removed):"
    printf '%s\n' "$extra" | sed 's/^/  /' >&2
  fi
}

if dry_run && [ -n "${CHEZMOI:-}" ]; then
  warn "CHEZMOI_SCRIPTS_DRY_RUN=1 under chezmoi: chezmoi records this script as run, so a real apply would skip it"
fi
