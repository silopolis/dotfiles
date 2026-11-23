# 010 sources the private file again at every start, after it unsets the revoked variable
/^unset GITHUB_TOKEN$/a\
if [ -f "${XDG_CONFIG_HOME}/env" ]; then\
  source "${XDG_CONFIG_HOME}/env"\
fi
