## GoLang setup

export GOPATH="$HOME/.local/go"
export GOBIN="$GOPATH/bin"
# Add Go bin dir to PATH
if [ -d "$GOBIN" ] ; then
  PATH="$GOBIN:$PATH"
fi

export PATH

# vim: set syntax=sh :
