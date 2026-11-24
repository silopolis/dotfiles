# the zsh merge, a pipeline, is no longer checked as a whole: a failed awk that printed part of its output replaces the new file
/^      set -o pipefail$/d
