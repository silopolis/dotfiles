## Completion

case "${CURRENT_SHELL}" in
  "bash")
    # shellcheck disable=SC3044
    if ! shopt -oq posix; then
      if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
      elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
      fi
    fi
    ;;
  "zsh")
    autoload -Uz +X compinit
    compinit -d "$HOME/.cache/zcompdump"
    #zstyle ':completion:*' use-cache on
    #zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/.zcompcache"
    zstyle ':completion:*:*:*:*:*' menu select
    zstyle ':completion:*' auto-description 'specify: %d'
    zstyle ':completion:*' completer _extensions _expand _complete _approximate
    zstyle ':completion:*' format 'Completing %d'
    zstyle ':completion:*' group-name ''
    zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or the character to insert%s'
    zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
    zstyle ':completion:*' rehash true
    zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
    zstyle ':completion:*' use-compctl false
    zstyle ':completion:*' verbose true
    # shellcheck disable=SC2016
    zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
    # Take advantage of $LS_COLORS for completion as well
    if [ -x /usr/bin/dircolors ]; then
      # shellcheck disable=SC2296
      zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
      zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
    else
      zstyle ':completion:*' list-colors ''
    fi

    autoload -U +X bashcompinit && bashcompinit
    ;;
esac

## Load completion scripts
SHELL_COMP_DIR="${SHELL_COMP_DIR:-$XDG_CONFIG_HOME/$CURRENT_SHELL/completions.d}"
for comp_script in "${SHELL_COMP_DIR}"/*.sh; do
  # shellcheck disable=SC3046,SC1090
  source "${comp_script}"
done

## Source gcloud CLI completion
case "${CURRENT_SHELL}" in
  "bash")
    . /usr/share/google-cloud-sdk/completion.bash.inc
    ;;
  "zsh")
    . /usr/share/google-cloud-sdk/completion.zsh.inc
    ;;
esac


# vim: set syntax=sh :
