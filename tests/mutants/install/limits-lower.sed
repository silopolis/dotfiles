# the limits script declares half of the soft limit it was given: it writes, and would lower, a value
s/^soft={{ \$soft }}$/soft={{ div $soft 2 }}/
