### Homebrew
if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  #export NONINTERACTIVE=1
  export HOMEBREW_AUTO_UPDATE_SECS=3600
  # 1 to enable, empty to disable
  export HOMEBREW_NO_AUTO_UPDATE=
  # 1 to enable, empty to disable
  export HOMEBREW_NO_ENV_HINTS=
  # 1 to enable, empty to disable
  export HOMEBREW_NO_INSTALL_CLEANUP=

  # Load brew shell env
  # Sets HOMEBREW_PREFIX, HOMEBREW_CELLAR, and HOMEBREW_REPOSITORY
  # Loads auto-completions
  # Adds brew bin and sbin dirs to PATH
  # Updates MANPATH and INFOPATH
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv $CURRENT_SHELL)"
  #export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-$(brew --prefix)}"

  # Add brew completions
  case $CURRENT_SHELL in
    "bash")
      if [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
        source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
      else
        for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
          [[ -r "${COMPLETION}" ]] && source "${COMPLETION}"
        done
      fi
      ;;
    "zsh")
      brew completions link &> /dev/null
      zsh_completions="${HOMEBREW_PREFIX}/share/zsh-completions"
      if [ $? -eq 0 ] && [ -d "$zsh_completions" ];then
        fpath=($zsh_completions $fpath)
      fi
      brew_completion="${HOMEBREW_PREFIX}/share/zsh/zsh-site-functions"
      if [ $? -eq 0 ] && [ -d "$brew_completion" ];then
        fpath=($brew_completion $fpath)
      fi
      ;;
  esac

  if command -v brew-file &> /dev/null; then
    #export HOMEBREW_BREWFILE="$HOME/.config/brewfile/Brewfile"
    # brew-file backup file name
    export HOMEBREW_BREWFILE_BACKUP="$HOME/.config/brewfile/Brewfile.backup"
    # Toggle use of full names (tap/name)
    export HOMEBREW_BREWFILE_FULL_NAME=1
    # Only list leaves
    export HOMEBREW_BREWFILE_LEAVES=0
    # Only list packages installed on request. Has priority over leaves
    export HOMEBREW_BREWFILE_ON_REQUEST=1
    # "go,coreutils" # Packages always to be listed
    export HOMEBREW_BREWFILE_TOP_PACKAGES="gcc,g++"

    # brew command wrapper for brew-file
    if [ -f "${HOMEBREW_PREFIX}/etc/brew-wrap" ];then
      source "${HOMEBREW_PREFIX}/etc/brew-wrap"
      # brew-wrap calls this when a brew command changed the Brewfile:
      # copy it back into chezmoi's source and commit it there.
      # Skip the commit once with: BREWFILE_NO_COMMIT=1 brew install …
      _post_brewfile_update () {
        command -v chezmoi >/dev/null 2>&1 || return 0
        local target="${HOMEBREW_BREWFILE:-$HOME/.config/brewfile/Brewfile}"
        local repo src rel diff add del msg
        repo="$(chezmoi source-path)" || return 1
        src="$(chezmoi source-path "$target" 2>/dev/null)" || return 0
        chezmoi re-add "$target" || return 1
        [ -n "${BREWFILE_NO_COMMIT:-}" ] && return 0
        rel="${src#"$repo"/}"
        diff="$(git -C "$repo" diff -U0 -- "$rel")"
        [ -n "$diff" ] || return 0
        # "`a`, `b` and `c`" from added (+) / removed (-) brew and cask lines
        _brewfile_list () {
          printf '%s\n' "$diff" | awk -v s="$1" '
            substr($0,1,1)==s && $1 ~ /^.(brew|cask)$/ {
              gsub(/[",]/,"",$2); k=split($2,p,"/"); a[n++]=p[k] }
            END { for (i=0;i<n;i++)
                    printf "%s`%s`", (i==0 ? "" : (i==n-1 ? " and " : ", ")), a[i] }'
        }
        add="$(_brewfile_list +)"; del="$(_brewfile_list -)"
        if [ -n "$add" ] && [ -z "$del" ]; then msg="feat(pkg:brew): add $add"
        elif [ -n "$del" ] && [ -z "$add" ]; then msg="chore(pkg:brew): remove $del"
        elif [ -n "$add" ]; then msg="chore(pkg:brew): add $add, remove $del"
        else msg="chore(pkg:brew): update Brewfile taps and options"
        fi
        [ "${#msg}" -le 100 ] || msg="${msg:0:97}..."
        git -C "$repo" commit -q --only -m "$msg" -- "$rel" &&
          echo "chezmoi: committed Brewfile: $msg"
      }
    fi
  fi
fi

# vim: set syntax=sh :
