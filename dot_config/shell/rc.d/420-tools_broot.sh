## broot

# load broot `br` launcher function
if command -v broot &> /dev/null; then
  case $CURRENT_SHELL in
    "bash")
      . "${HOME}/.config/broot/launcher/bash/br"
      ;;
    "zsh")
      source "${HOME}/.config/broot/launcher/bash/br"
      ;;
  esac
fi

# vim: set syntax=sh :
