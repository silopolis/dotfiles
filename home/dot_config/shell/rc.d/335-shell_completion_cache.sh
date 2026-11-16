## Cached completion scripts

# A tool prints its completion script from a command that costs tens to thousands of milliseconds
# (localstack about 1.6 s). Running it at every start made the shell wait for it every time.
#
#   _cached_completion <tool> <command...> && . "$_CC_FILE"
#
# - <tool> is the command to find on PATH; <command...> prints its completion script for the current shell,
#   for example `kubectl completion "$CURRENT_SHELL"`.
# - The script lives in $XDG_CACHE_HOME/shell/completions/<shell>/<tool>; _CC_FILE is set to it, and the
#   caller sources it at the top level, because `source` inside a function would make the top-level
#   `typeset`/`local` statements of a completion script local to the function in zsh.
# - The file is used while the tool still resolves to the file it was made for (first line,
#   `[ -ef ]`: no subprocess) and is not newer than the cache file. A brew upgrade or a mise install moves
#   the link to a new directory, so the next start regenerates. A tool replaced in place with an older
#   modification time, or behind a mise shim, keeps its file until SHELL_COMPLETION_REFRESH=1 or until the
#   directory is deleted: the scripts ask the tool for completions when TAB is pressed, so they stay correct.
# - Generation is silent and goes through a temporary file moved into place, so a shell that starts
#   at the same moment never sources a half-written file. A command that fails or prints nothing caches
#   nothing, and an older file stays in use.
# - SHELL_RC_DEBUG prints one line on standard error for each regeneration.
# shellcheck disable=SC3043
_cached_completion() {
  local _cc_tool _cc_bin _cc_dir _cc_file _cc_hdr _cc_known _cc_out _cc_real _cc_tmp
  _cc_tool=$1
  shift
  _CC_FILE=
  _cc_bin=$(command -v "$_cc_tool" 2> /dev/null)
  case $_cc_bin in
    /*) ;;
    *) return 1 ;;
  esac
  _cc_dir="${XDG_CACHE_HOME:-$HOME/.cache}/shell/completions/${CURRENT_SHELL}"
  _cc_file="$_cc_dir/$_cc_tool"

  if [ -f "$_cc_file" ] && [ -z "${SHELL_COMPLETION_REFRESH:-}" ] && ! [ "$_cc_bin" -nt "$_cc_file" ]; then
    IFS= read -r _cc_hdr < "$_cc_file"
    _cc_known=${_cc_hdr#*: }
    if [ "$_cc_bin" -ef "$_cc_known" ]; then
      _CC_FILE=$_cc_file
      return 0
    fi
  fi

  _cc_out=$("$@" 2> /dev/null < /dev/null) || _cc_out=
  if [ -n "$_cc_out" ]; then
    _cc_real=$(command readlink -f "$_cc_bin" 2> /dev/null) || _cc_real=$_cc_bin
    _cc_tmp="$_cc_dir/.$_cc_tool.$$"
    if (
      umask 077
      command mkdir -p "$_cc_dir" && printf '#cached-completion: %s\n%s\n' "$_cc_real" "$_cc_out" > "$_cc_tmp"
    ) 2> /dev/null && command mv -f "$_cc_tmp" "$_cc_file" 2> /dev/null; then
      if [ -n "${SHELL_RC_DEBUG:-}" ]; then
        echo "completion cache: regenerated $_cc_tool" >&2
      fi
      _CC_FILE=$_cc_file
      return 0
    fi
    command rm -f "$_cc_tmp" 2> /dev/null
  fi

  # Nothing new could be made: an older file is better than no completion.
  if [ -f "$_cc_file" ]; then
    _CC_FILE=$_cc_file
    return 0
  fi
  return 1
}

# vim: set syntax=sh :
