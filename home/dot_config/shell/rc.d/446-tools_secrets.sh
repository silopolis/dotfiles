## Keys on demand: the private environment file is loaded when the user asks

# A shell does not start with the keys of the private environment file, and neither does the desktop session: every
# process that inherits them (an agent, a plugin, a script) could print or send them.
#   secrets load     export the file's variables into this shell, and so into everything it starts,
#                    and set the marker DOTFILES_SECRETS=loaded
#   secrets unload   unset them and the marker
#   secrets          print how many of the file's variables are set (a number, never a name)
# The user types it; an agent never does.
# The names are read from the file at each call: no name is written in this repository.
# The marker has a secret-pattern name, so the opencode function removes it from an agent's environment with the keys.
#
# A new interactive shell starts without the marker unless a parent loaded the keys on purpose: it then unsets the
# copies it inherited, which terminals and multiplexers started by an older session still hold.
# With the marker, the shell is a child of a shell that loaded them, and keeps them.

# Interactive shells only: a script, a desktop session or a command run by ssh neither gets the function nor loses a
# variable here.
case $- in
  *i*) ;;
  *) return 0 ;;
esac

# The private file, and the names it sets (one per line: assignments, with or without export; comments and blank
# lines are not names).
_secrets_file() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/env"
}

_secrets_names() {
  [ -f "$(_secrets_file)" ] || return 0
  sed -n 's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}\([A-Za-z_][A-Za-z0-9_]*\)=.*/\2/p' "$(_secrets_file)"
}

secrets() {
  case "${1:-}" in
    load)
      if [ ! -f "$(_secrets_file)" ]; then
        echo "secrets: no private environment file" >&2
        return 1
      fi
      # allexport: a plain assignment of the file is exported too; the option goes back as it was
      case $- in
        *a*) _secrets_was_a=1 ;;
        *) _secrets_was_a=0 ;;
      esac
      set -a
      # shellcheck disable=SC1090
      . "$(_secrets_file)"
      [ "$_secrets_was_a" = 1 ] || set +a
      unset _secrets_was_a
      export DOTFILES_SECRETS=loaded
      ;;
    unload)
      for _secrets_name in $(_secrets_names); do
        unset "$_secrets_name" 2> /dev/null || :
      done
      unset _secrets_name DOTFILES_SECRETS
      ;;
    "")
      _secrets_count=0
      for _secrets_name in $(_secrets_names); do
        eval "[ -n \"\${$_secrets_name+set}\" ]" && _secrets_count=$((_secrets_count + 1))
      done
      printf '%s\n' "$_secrets_count"
      unset _secrets_count _secrets_name
      ;;
    *)
      echo "usage: secrets [load|unload]" >&2
      return 2
      ;;
  esac
}

# A parent that loaded the keys on purpose leaves the marker: this shell keeps what it inherited.
if [ -z "${DOTFILES_SECRETS:-}" ]; then
  for _secrets_name in $(_secrets_names); do
    unset "$_secrets_name" 2> /dev/null || :
  done
  unset _secrets_name
fi

# vim: set syntax=sh :
