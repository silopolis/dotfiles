## direnv

if command -v direnv &> /dev/null; then
  eval "$(direnv hook $CURRENT_SHELL)"
fi

# vim: set syntax=sh :
