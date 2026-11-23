## Environment variables

### User environment configuration
if [ -f "${XDG_CONFIG_HOME}/envrc" ]; then
  source "${XDG_CONFIG_HOME}/envrc"
fi

### Revoked variable
# A parent process (terminal, multiplexer) started before the token was revoked still holds it: drop that inherited copy.
unset GITHUB_TOKEN

### User private environment: not loaded here
# The private file holds the keys, and no process gets them unless the user asks: `secrets load` in an interactive
# shell (446-tools_secrets.sh), which hands them to that shell and its children only. Neither a new shell nor the
# desktop session starts with them.

# vim: set syntax=sh :
