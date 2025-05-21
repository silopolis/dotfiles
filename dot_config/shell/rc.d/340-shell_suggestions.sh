## Shel auto-suggestions

case "${CURRENT_SHELL}" in
  "bash")
    return
    ;;
  "zsh")
    # enable auto-suggestions based on the history
    if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
      # shellcheck disable=SC3046,SC1094
      source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
      # change suggestion color
      # shellcheck disable=SC2034
      ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#999'
    fi
    ;;
esac



