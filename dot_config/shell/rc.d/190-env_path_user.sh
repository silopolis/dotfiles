# Include user's private "bin" directories if they exist
#if [ "$(id -u)" -eq 0 ]; then
  # Include user's private ~/bin if it exists
  if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
  fi
  # Include user's private ~/sbin if it exists
  if [ -d "$HOME/sbin" ] ; then
    PATH="$HOME/sbin:$PATH"
  fi
  # Include user's private ~/.local/bin if it exists
  if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
  fi
  # Include user's private ~/.local/sbin if it exists
  if [ -d "$HOME/.local/sbin" ] ; then
    PATH="$HOME/.local/sbin:$PATH"
  fi
#else
#  # Include user's private ~/bin if it exists
#  if [ -d "$HOME/bin" ] ; then
#    echo "bin"
#    PATH="$HOME/bin:$PATH"
#  fi
#  # Include user's private ~/.local/bin if it exists
#  if [ -d "$HOME/.local/bin" ] ; then
#    PATH="$HOME/.local/bin:$PATH"
#  fi
#fi

export PATH

# vim: set syntax=sh :
