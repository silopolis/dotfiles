## Shell history

# The history lives under $XDG_STATE_HOME: zsh/history and bash/history, directories 0700, files 0600.
# The old files, ~/.zsh_history and ~/.bash_history, become links to the new ones, so that the shells that are still running
# append through the link. A running shell that trims its history turns the link back into a regular file: the next start
# merges that file into the new one (zsh: every entry once, in timestamp order; bash, whose file has no timestamp: the new
# lines, then the old lines the new file lacks, a repeated command as many times as it was typed) through a temporary file
# and a move, and puts the link back. Every failure is silent: a shell that cannot migrate uses the new file as it is.

# _history_merge SHELL NEW LEGACY: print the merged history
_history_merge() {
  case "$1" in
    zsh)
      # an entry starts with ": TIMESTAMP:DURATION;" and goes on over the lines that follow; newlines inside an entry are
      # carried as \001 so that sort sees one line per entry
      awk '
        function flush() { if (cur != "" && !(cur in seen)) { seen[cur] = 1; printf "%s\t%s\n", ts, cur } cur = "" }
        FNR == 1 { flush() }
        /^: [0-9]+:[0-9]+;/ { flush(); ts = $0; sub(/^: /, "", ts); sub(/:.*/, "", ts); cur = $0; next }
        { if (cur == "") { ts = 0; cur = $0 } else { cur = cur "\001" $0 } }
        END { flush() }
      ' "$2" "$3" | sort -s -n -t "$(printf '\t')" -k1,1 | cut -f2- | tr '\001' '\n'
      ;;
    *)
      awk 'NR == FNR { n[$0]++; print; next } { if (n[$0] > 0) n[$0]--; else print }' "$2" "$3"
      ;;
  esac
}

# _history_migrate SHELL LEGACY NEW: make the directory of NEW, then move or merge the legacy file into it
_history_migrate() {
  (
    umask 077
    mkdir -p "${3%/*/*}" 2> /dev/null
    [ -d "${3%/*}" ] || mkdir -m 0700 "${3%/*}" || exit 0
    chmod 0700 "${3%/*}"
    [ -f "$2" ] && [ ! -L "$2" ] || exit 0
    if [ ! -e "$3" ]; then
      # a hard link is made only when the new name is free: of two shells that start at once, one gets it
      ln "$2" "$3" || {
        [ -e "$3" ] || { cp -p "$2" "$3.$$" && mv -n "$3.$$" "$3"; rm -f "$3.$$"; }
      }
    else
      tmp=$(mktemp "${3%/*}/.merge.XXXXXX") || exit 0
      # The zsh merge is a pipeline: without pipefail a failed awk would leave an empty or partial output with a status of 0,
      # and the move would replace the new history by it. A merge that fails, or that gives nothing from inputs that are not
      # empty, replaces nothing and leaves the old file a regular file, so that the next start tries again.
      # shellcheck disable=SC3040  # this file is sourced by bash and zsh only, which both know pipefail
      set -o pipefail
      if _history_merge "$1" "$3" "$2" > "$tmp" && { [ -s "$tmp" ] || { [ ! -s "$3" ] && [ ! -s "$2" ]; }; } && mv -f "$tmp" "$3"; then
        :
      else
        rm -f "$tmp"
        exit 0
      fi
    fi
    [ -f "$3" ] || exit 0
    chmod 0600 "$3"
    # the link replaces the old file in one rename: the legacy entries are in the new file before it goes
    ln -s "$3" "$2.$$" && mv -f "$2.$$" "$2"
    rm -f "$2.$$"
  ) > /dev/null 2>&1
}

case "${CURRENT_SHELL}" in
  "bash")
    _history_migrate bash "$HOME/.bash_history" "${XDG_STATE_HOME:-$HOME/.local/state}/bash/history"
    HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/bash/history"
    # shellcheck disable=SC3044
    shopt -s histappend              # append new history items to .bash_history
    export HISTCONTROL=ignorespace   # leading space hides commands from history
    #export HISTCONTROL=ignoreboth    # ignore duplicates and lines starting with a space
    export HISTFILESIZE=10000        # increase history file size (default is 500)
    export HISTSIZE=${HISTFILESIZE}  # increase history size (default is 500)
    # ensure synchronization between bash memory and history file
    export PROMPT_COMMAND="history -a; history -n; ${PROMPT_COMMAND}"
    ;;
  "zsh")
    _history_migrate zsh "$HOME/.zsh_history" "${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
    HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
    HISTSIZE=5000
    # shellcheck disable=SC2034
    SAVEHIST=5000
    setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
    setopt hist_ignore_dups       # ignore duplicated commands history list
    setopt hist_ignore_space      # ignore commands that start with space
    setopt hist_verify            # show command with history expansion to user before running it
    setopt share_history          # share command history data
    alias history="history 0"     # force zsh to show the complete history
    ;;
esac

unset -f _history_merge _history_migrate
