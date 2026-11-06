## Set XDG_* FreeDesktop directories

# Base directory relative to which user-specific configuration files should be stored
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
# Preference-ordered, colon separated, list of base directories to search for configuration
# files in addition to the $XDG_CONFIG_HOME base directory. Defaults to '/etc/xdg'
#export XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"
# Base directory relative to which user-specific data files should be stored
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
# Preference-ordered, colon separated, list of base directories to search for data files
# in addition to the $XDG_DATA_HOME base directory. Defaults to '/usr/local/share/:/usr/share/'
#export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share/:/usr/share/}"
# Base directory relative to which user-specific state files should be stored
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
# Base directory relative to which user-specific executable files should be stored
export XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
export XDG_LIB_HOME="${XDG_LIB_HOME:-$HOME/.local/lib}"
# Base directory relative to which user-specific non-essential data files should be stored
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
# Base directory relative to which user-specific non-essential runtime files and other file
# objects (such as sockets, named pipes, …) should be stored. Check spec for the many requirements
# about this directory here https://specifications.freedesktop.org/basedir-spec/latest/.
# Defaults to 'null'
#export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}"

# vim: set syntax=sh :
