check_language() {
   local lang="$1"
   local string="$2"

   if [ -z "$lang" ] || [ -z "$string" ]; then
     echo "Usage: check_language <language> <string>"
     return 1
   fi

   echo "$string" | pylanguagetool -l "$lang"
}

alias lt=check_language

