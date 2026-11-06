## Get current shell info

#CURRENT_SHELL="$(ps -p $$ --no-header | tr -s ' ' | cut -d' ' -f5)"
#export CURRENT_SHELL="${CURRENT_SHELL:-$(ps -p $$ -o comm=)}"
CURRENT_SHELL="$(ps -p $$ -o comm=)"

#CURRENT_SHELL=${0#-}
#CURRENT_SHELL=${CURRENT_SHELL##*/}

#echo "CURRENT_SHELL=$CURRENT_SHELL"
export CURRENT_SHELL

# vim: set syntax=sh :
