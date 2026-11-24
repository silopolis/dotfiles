# the non-interactive branch of profile runs a whole rc.d pass, as shellrc did, instead of sourcing shell/environment
/shell\/environment" \]; then$/,/^ *fi$/c\
        if [ -n "${SHELL_RC_DEBUG:-}" ]; then echo "shellrc: sourcing rc.d" >&2; fi\
        for rc_script in "${XDG_CONFIG_HOME:-$HOME/.config}"/shell/rc.d/*.sh; do . "$rc_script"; done
