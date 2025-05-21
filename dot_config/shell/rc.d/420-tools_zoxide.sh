## Zoxide

# For completions to work, this block must be placed at the end of the shell config file.
# For Zsh, it must anyway be added after compinit is called, You may have to rebuild your
# completions cache by running `rm ~/.zcompdump*; compinit`.
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init $CURRENT_SHELL)"
fi

# vim: set syntax=sh :
