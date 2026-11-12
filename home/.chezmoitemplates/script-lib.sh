# shellcheck disable=SC2329
# Shared helper of the chezmoi scripts: included right after the shebang with
#   template "script-lib.sh" (dict "name" "<script>" "root" .)
# Editing it makes every script that includes it run once more, all of them no-ops on a provisioned machine.
set -euo pipefail

script_name={{ .name | squote }}
brew_prefix={{ .root.brew.prefix | squote }}

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

# load_brew: give the script the environment of the user's shell.
# Homebrew keeps its trust file under XDG_CONFIG_HOME (else ~/.homebrew): without it, third-party taps are untrusted
# and brew-file lists every installed tap formula as missing.
load_brew() {
  export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
  if [ -z "${HOMEBREW_PREFIX:-}" ] && [ -x "$brew_prefix/bin/brew" ]; then
    eval "$("$brew_prefix/bin/brew" shellenv)"
  fi
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
