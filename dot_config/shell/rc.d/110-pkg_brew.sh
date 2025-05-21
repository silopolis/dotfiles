### Homebrew
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

  # Add brew completions
  case $CURRENT_SHELL in
    "bash")
      if [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
        source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
      else
        for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
          [[ -r "${COMPLETION}" ]] && source "${COMPLETION}"
        done
      fi
      ;;
    "zsh")
      brew completions link &> /dev/null
      zsh_completions="${HOMEBREW_PREFIX}/share/zsh-completions"
      if [ $? -eq 0 ] && [ -d "$zsh_completions" ];then
        fpath=($zsh_completions $fpath)
      fi
      brew_completion="${HOMEBREW_PREFIX}/share/zsh/zsh-site-functions"
      if [ $? -eq 0 ] && [ -d "$brew_completion" ];then
        fpath=($brew_completion $fpath)
      fi
      ;;
  esac

  if command -v brew-file &> /dev/null; then
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

    # brew command wrapper for brew-file
    if [ -f "${HOMEBREW_PREFIX}/etc/brew-wrap" ];then
      source "${HOMEBREW_PREFIX}/etc/brew-wrap"
    fi
  fi
fi

# vim: set syntax=sh :
