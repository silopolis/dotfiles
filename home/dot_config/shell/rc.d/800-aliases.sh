## Aliases

## Source common aliases definitions
if [ -f "${XDG_CONFIG_HOME}/shell/aliases" ]; then
  # shellcheck disable=SC3046,SC1091
  source "${XDG_CONFIG_HOME}/shell/aliases"
fi

## Source shell specific aliases definitions
if [ -f "$HOME/.${CURRENT_SHELL}_aliases" ]; then
  # shellcheck disable=SC3046,SC1090
  source "$HOME/.${CURRENT_SHELL}_aliases"
fi
if [ -f "${XDG_CONFIG_HOME}/${CURRENT_SHELL}/${CURRENT_SHELL}_aliases" ]; then
  # shellcheck disable=SC3046,SC1090
  source "${XDG_CONFIG_HOME}/${CURRENT_SHELL}/${CURRENT_SHELL}_aliases"
fi

