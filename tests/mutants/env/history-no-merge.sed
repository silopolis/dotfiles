# the merge writes the new file as it is: the entries of a legacy file that a trim turned back into a regular file are lost
s|_history_merge "\$1" "\$3" "\$2" > "\$tmp"|cat "\$3" > "\$tmp"|
