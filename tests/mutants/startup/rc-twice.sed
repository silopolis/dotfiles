# profile sources the shared configuration itself for an interactive login shell, on top of the rc file of the shell
/^  \*i\*)$/a\
    . "$HOME/.config/shell/shellrc"
