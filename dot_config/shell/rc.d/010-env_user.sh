## Environment variables

### User environment configuration
if [ -f "${XDG_CONFIG_HOME}/envrc" ]; then
  source "${XDG_CONFIG_HOME}/envrc"
fi

### User private environment configuration
if [ -f "${XDG_CONFIG_HOME}/env" ]; then
  source "${XDG_CONFIG_HOME}/env"
fi

# vim: set syntax=sh :
