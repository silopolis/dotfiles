# a stricter umask is no longer a reason to leave the live value: the umask is overwritten
s/^weakens_umask() .*/weakens_umask() { return 1; }/
