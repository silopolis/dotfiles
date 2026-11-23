## PATH helpers for the env_ files that follow

# Written for bash and zsh and checked as POSIX sh: no array, no `local`, no process spawned.
# Both are defined again by each pass that sources the env_ files, and each leaves PATH exported.

# _path_prepend DIR...: put each directory at the front of PATH, once.
# A directory that is already on PATH moves to the front, whatever the number of its copies; one that is not a
# directory is skipped; nothing else changes. Several directories behave as one call each, in order.
_path_prepend() {
  for _pp_dir in "$@"; do
    [ -d "$_pp_dir" ] || continue
    _pp_rest=
    _pp_in=${PATH}:
    while [ -n "$_pp_in" ]; do
      _pp_entry=${_pp_in%%:*}
      _pp_in=${_pp_in#*:}
      [ "$_pp_entry" = "$_pp_dir" ] && continue
      _pp_rest=${_pp_rest:+$_pp_rest:}$_pp_entry
    done
    PATH=$_pp_dir${_pp_rest:+:$_pp_rest}
  done
  export PATH
  unset _pp_dir _pp_rest _pp_in _pp_entry
}

# _path_clean: drop the entries of PATH that are empty, that are not a directory or that were seen before.
# The first occurrence stays, in its place.
_path_clean() {
  _pc_out=
  _pc_in=${PATH}:
  while [ -n "$_pc_in" ]; do
    _pc_entry=${_pc_in%%:*}
    _pc_in=${_pc_in#*:}
    [ -n "$_pc_entry" ] && [ -d "$_pc_entry" ] || continue
    case ":$_pc_out:" in
      *":$_pc_entry:"*) continue ;;
    esac
    _pc_out=${_pc_out:+$_pc_out:}$_pc_entry
  done
  PATH=$_pc_out
  export PATH
  unset _pc_out _pc_in _pc_entry
}

# vim: set syntax=sh :
