## Shell history

case "${CURRENT_SHELL}" in
  "bash")
    # shellcheck disable=SC3044
    shopt -s histappend              # append new history items to .bash_history
    export HISTCONTROL=ignorespace   # leading space hides commands from history
    #export HISTCONTROL=ignoreboth    # ignore duplicates and lines starting with a space
    export HISTFILESIZE=10000        # increase history file size (default is 500)
    export HISTSIZE=${HISTFILESIZE}  # increase history size (default is 500)
    # ensure synchronization between bash memory and history file
    export PROMPT_COMMAND="history -a; history -n; ${PROMPT_COMMAND}"
    ;;
  "zsh")
    HISTFILE=~/.zsh_history
    HISTSIZE=5000
    # shellcheck disable=SC2034
    SAVEHIST=5000
    setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
    setopt hist_ignore_dups       # ignore duplicated commands history list
    setopt hist_ignore_space      # ignore commands that start with space
    setopt hist_verify            # show command with history expansion to user before running it
    setopt share_history          # share command history data
    alias history="history 0"     # force zsh to show the complete history
    ;;
esac

