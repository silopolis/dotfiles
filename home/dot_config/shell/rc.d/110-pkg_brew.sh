## Homebrew: completions and the brew-file wrapper

# The environment (PATH, HOMEBREW_* variables) is 041-env_pkg_brew.sh, which every shell and the desktop session load.

if [ -n "${HOMEBREW_PREFIX:-}" ] && [ -x "${HOMEBREW_PREFIX}/bin/brew" ]; then
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
      # No duplicate in fpath, even when this file is sourced again (a re-sourced ~/.zshrc):
      # the completion dump lists the files of fpath and is rebuilt when that list changes.
      # `brew completions link` is not run here: its state is persistent, the brew install script sets it once.
      typeset -U fpath
      zsh_completions="${HOMEBREW_PREFIX}/share/zsh-completions"
      if [ -d "$zsh_completions" ];then
        fpath=($zsh_completions $fpath)
      fi
      brew_completion="${HOMEBREW_PREFIX}/share/zsh/zsh-site-functions"
      if [ -d "$brew_completion" ];then
        fpath=($brew_completion $fpath)
      fi
      ;;
  esac

  if command -v brew-file &> /dev/null; then
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
        # brew-file wrote the Brewfile with its own mode: apply puts back the mode chezmoi expects
        chezmoi apply --exclude=scripts "$target" || return 1
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
