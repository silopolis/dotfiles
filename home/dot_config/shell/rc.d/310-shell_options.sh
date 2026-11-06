## Shell options

case "${CURRENT_SHELL}" in
  "bash")
    # check the window size after each command and update LINES and COLUMNS values if necessary.
    # shellcheck disable=SC3044
    shopt -s checkwinsize

    # Use "**" in a pathname expansion context to match all files and zero or more directories
    # and subdirectories.
    # shellcheck disable=SC3044
    shopt -s globstar
    ;;
  "zsh")
    setopt autocd              # change directory just by typing its name
    setopt correct             # auto correct mistakes
    setopt interactivecomments # allow comments in interactive mode
    setopt magicequalsubst     # enable filename expansion for arguments of the form ‘anything=expression’
    setopt nonomatch           # hide error message if there is no match for the pattern
    setopt notify              # report the status of background jobs immediately
    setopt numericglobsort     # sort filenames numerically when it makes sense
    setopt promptsubst         # enable command substitution in prompt

    # Do not condider '\' as part of words when using word-based keyboard shortcuts and operations
    # shellcheck disable=SC3060
    WORDCHARS=${WORDCHARS//\/} 

    # configure `time` format
    # shellcheck disable=SC2034,SC3003
    TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'
    ;;
esac

