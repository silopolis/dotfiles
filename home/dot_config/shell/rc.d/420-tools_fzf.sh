## fzf

# Set up fzf key bindings and fuzzy completion
if command -v fzf &> /dev/null; then
  case $CURRENT_SHELL in
    "bash")
      eval "$(fzf --$CURRENT_SHELL)"
      ;;
    "zsh")
      # The integration binds keys and widgets of the line editor and sets the zle option, which zsh
      # refuses without a controlling terminal: an agent or a script running `zsh -i -c` would get
      # "can't change option: zle" twice. `[[ -o zle ]]` alone is not enough, it reads "on" there.
      # shellcheck disable=SC3010,SC3062
      if [[ -o zle ]] && { : < /dev/tty; } 2> /dev/null; then
        source <(fzf --$CURRENT_SHELL)
      fi
      ;;
  esac
fi

# vim: set syntax=sh :
