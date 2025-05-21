## fzf

# Set up fzf key bindings and fuzzy completion
if command -v fzf &> /dev/null; then
  case $CURRENT_SHELL in
    "bash")
      eval "$(fzf --$CURRENT_SHELL)"
      ;;
    "zsh")
      source <(fzf --$CURRENT_SHELL)
      ;;
  esac
fi

# vim: set syntax=sh :
