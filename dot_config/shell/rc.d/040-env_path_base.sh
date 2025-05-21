## Base PATH

#if [ "$(id -u)" -eq 0 ]; then
#  PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
#else
#  PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"
#fi
### Set same PATH for root and users
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games"

export PATH

# vim: set syntax=sh :
