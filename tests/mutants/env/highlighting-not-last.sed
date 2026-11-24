# the last rc.d file stops loading zsh-syntax-highlighting: highlighting is no longer what loads last
s|^\( *\)source "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting\.zsh"|\1: "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"|
