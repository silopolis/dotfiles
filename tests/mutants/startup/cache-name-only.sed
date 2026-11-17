# the cache is keyed on the tool name only: the recorded real path and the modification time are no longer looked at
s/\[ "\$_cc_bin" -ef "\$_cc_known" \]/true/
s/! \[ "\$_cc_bin" -nt "\$_cc_file" \]/true/
