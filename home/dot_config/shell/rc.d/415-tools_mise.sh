## Mise-en-place

if command -v mise &> /dev/null; then
  case $CURRENT_SHELL in
    "bash")
      source <(eval "$(mise activate $CURRENT_SHELL)")
      ;;
    "zsh")
      source <(mise activate $CURRENT_SHELL)
      ;;
  esac
fi

# vim: set syntax=sh :
