## Environment variables

### User environment configuration
if [ -f "${XDG_CONFIG_HOME}/envrc" ]; then
  source "${XDG_CONFIG_HOME}/envrc"
fi

### User private environment configuration
# A parent process (terminal, multiplexer) started before the token was removed from the file still holds it:
# drop that inherited copy first, then let the file set it again if it ever does
unset GITHUB_TOKEN
if [ -f "${XDG_CONFIG_HOME}/env" ]; then
  source "${XDG_CONFIG_HOME}/env"
fi

# vim: set syntax=sh :
