## command-not-found handler

# Handler for Bash is already defined 
if [ "${CURRENT_SHELL}" = "zsh" ] && [ -f /etc/zsh_command_not_found ]; then
    source /etc/zsh_command_not_found
fi

# TODO Include handler from Debian /etc/bash.basrc
# TODO Include Zsh handler and apply same logic as for Bash

# vim: set syntax=sh :
