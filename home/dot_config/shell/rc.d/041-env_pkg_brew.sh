## Homebrew: the environment of every shell and of the desktop session

# PATH (brew's bin and sbin), the HOMEBREW_* variables, MANPATH and INFOPATH.
# The completions, `fpath` and the brew-file wrapper are interactive and stay in 110-pkg_brew.sh.

if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  #export NONINTERACTIVE=1
  export HOMEBREW_AUTO_UPDATE_SECS=3600
  # 1 to enable, empty to disable
  export HOMEBREW_NO_AUTO_UPDATE=
  # 1 to enable, empty to disable
  export HOMEBREW_NO_ENV_HINTS=
  # 1 to enable, empty to disable
  export HOMEBREW_NO_INSTALL_CLEANUP=

  # Load brew shell env
  # Sets HOMEBREW_PREFIX, HOMEBREW_CELLAR, and HOMEBREW_REPOSITORY
  # Loads auto-completions
  # Adds brew bin and sbin dirs to PATH
  # Updates MANPATH and INFOPATH
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv $CURRENT_SHELL)"
  #export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-$(brew --prefix)}"
  # brew shellenv puts its directories in front of PATH at each call: drop the copy that a nested shell already holds
  _path_clean

  if command -v brew-file > /dev/null 2>&1; then
    #export HOMEBREW_BREWFILE="$HOME/.config/brewfile/Brewfile"
    # brew-file backup file name
    export HOMEBREW_BREWFILE_BACKUP="$HOME/.config/brewfile/Brewfile.backup"
    # Toggle use of full names (tap/name)
    export HOMEBREW_BREWFILE_FULL_NAME=1
    # Only list leaves
    export HOMEBREW_BREWFILE_LEAVES=0
    # Only list packages installed on request. Has priority over leaves
    export HOMEBREW_BREWFILE_ON_REQUEST=1
    # "go,coreutils" # Packages always to be listed
    export HOMEBREW_BREWFILE_TOP_PACKAGES="gcc,g++"
  fi
fi

# vim: set syntax=sh :
