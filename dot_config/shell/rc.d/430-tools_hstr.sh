## HSTR

export HSTR_CONFIG=hicolor       # get more colors

alias hh=hstr                    # hh to be alias for hstr

case "${CURRENT_SHELL}" in
  "bash")
    # shellcheck disable=SC2113
    function hstrnotiocsti {
      # shellcheck disable=SC2086
      { READLINE_LINE="$( { </dev/tty hstr ${READLINE_LINE}; } 2>&1 1>&3 3>&- )"; } 3>&1;
      READLINE_POINT=${#READLINE_LINE}
    }
    # if this is interactive shell, then bind hstr to Ctrl-r (for Vi mode check doc)
    # shellcheck disable=SC3010
    if [[ $- =~ .*i.* ]]; then bind -x '"\C-r": "hstrnotiocsti"'; fi
    export HSTR_TIOCSTI=n
    ;;
  "zsh")
    #hstr_no_tiocsti() {
    #    zle -I
    #    { HSTR_OUT="$( { </dev/tty hstr ${BUFFER}; } 2>&1 1>&3 3>&- )"; } 3>&1;
    #    BUFFER="${HSTR_OUT}"
    #    CURSOR=${#BUFFER}
    #    zle redisplay
    #}
    #zle -N hstr_no_tiocsti
    #bindkey '\C-r' hstr_no_tiocsti
    #export HSTR_TIOCSTI=n
    ;;
esac

