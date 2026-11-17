# the inherited copy of the variable that rc.d/010-env_user.sh drops is no longer dropped
/^unset [A-Z_][A-Z0-9_]*$/d
