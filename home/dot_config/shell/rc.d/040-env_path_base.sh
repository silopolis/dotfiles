## Base PATH

# Keep what the shell inherited (a login shell's PATH comes from /etc/profile, any other shell's from its parent),
# add the system directories that are missing, and clean: no duplicate, no directory that does not exist.
# The same file runs again in a nested shell, in the desktop session and in every terminal, and gives the same PATH.
### Same system directories for root and users
for _path_base_dir in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/local/games /usr/games; do
  case ":${PATH}:" in
    *":${_path_base_dir}:"*) ;;
    *) PATH="${PATH:+$PATH:}${_path_base_dir}" ;;
  esac
done
unset _path_base_dir

_path_clean

# vim: set syntax=sh :
