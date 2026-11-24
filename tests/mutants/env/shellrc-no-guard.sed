# shellrc loses its interactive guard: a non-interactive shell that sources it runs the whole rc.d
/^case \$- in$/,/^esac$/d
