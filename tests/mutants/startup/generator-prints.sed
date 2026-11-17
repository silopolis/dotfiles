# the regeneration of a completion script prints its line whether or not debugging was asked for
s/if \[ -n "\${SHELL_RC_DEBUG:-}" \]; then/if true; then/
