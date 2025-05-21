## Prompt

# If not running interactively, don't do anything
case $- in
  *i*)
    ### Starship prompt
    if command -v starship &> /dev/null; then
      eval "$(starship init $CURRENT_SHELL)"
    else
      PROMPT_SOURCE="${XDG_CONFIG_HOME}/${CURRENT_SHELL}/${CURRENT_SHELL}_prompt"
      if [ -r "${PROMPT_SOURCE}" ]; then
        source "${PROMPT_SOURCE}"
      fi
    fi
    ;;
  *)
    return
    ;;
esac

