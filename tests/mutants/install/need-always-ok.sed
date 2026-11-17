# need() of the shared helper succeeds whether or not the tool is found: a missing tool no longer makes the script skip
/^need() {/,/^}/ s/\[ "\${#lacking\[@\]}" -eq 0 \] && return 0/return 0/
