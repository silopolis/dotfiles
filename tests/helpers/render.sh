#!/usr/bin/env bash
# The scratch render: the shell targets of the source state, applied into an empty scratch destination
# with a synthetic chezmoi configuration. Plain bash, no bats.
# Source it (`. tests/helpers/render.sh`; it loads common.sh), or call one function:
#   tests/helpers/render.sh <function> [args...]
#
# Provides:
#   dt_render_config FILE             write the synthetic configuration: identity values that start with `demo-`,
#                                     `machine.type`, `cpu`, `github`, `features`, `nvim` and `tools.search` set as
#                                     the template would, the [env] table of home/.chezmoi.toml.tmpl copied as it
#                                     is, no `encryption` and no `age` key. It is not rendered from the template, so
#                                     it needs neither hostnamectl nor lscpu.
#   dt_render DIR [SOURCE]            render the shell targets of SOURCE (default: DOTFILES_TEST_SOURCE) below DIR:
#                                     DIR/destination (empty, mode 0750, made first: chezmoi creates neither the
#                                     root nor the parent of a directory target; one that exists is an error, status
#                                     2), DIR/state, DIR/cache, DIR/stubs
#                                     (a stub aqua, which a template calls at render time) and DIR/chezmoi.toml.
#                                     Prints the destination. The only place of the suite that applies anything.
#   dt_render_ref REF DIR             the same for another git ref: `git archive` (read-only on the repository) into
#                                     DIR/source, then dt_render on that copy. Prints the destination.
#   dt_render_targets                 the targets of the render, relative to the destination, one per line
#   dt_prepare_home HOME RENDER       make HOME (mode 0700) from a copy of the render (dt_render prints its
#                                     destination), plus what the startup expects and no target manages: the
#                                     synthetic broot launcher of tests/fixtures/ and a bin directory holding the
#                                     real mise when it was found; sets DT_HOME
#   dt_mise_vars                      the assignments that confine mise to DT_HOME, one per line (a test that builds its
#                                     own environment adds them: mise asks for trust on a terminal when it finds an
#                                     untrusted configuration in a directory above the scratch home)
#   dt_start [VAR=value ...] -- COMMAND [ARGS...]
#                                     run COMMAND under env -i from DT_HOME as a terminal of the desktop does:
#                                     HOME, XDG_CONFIG_HOME, TERM, LANG, SHELL, PATH (DT_HOME/bin first), and mise
#                                     confined to DT_HOME (it must not read a configuration above it)
#   dt_start_pty [VAR=value ...] -- COMMAND [ARGS...]
#                                     the same under a pseudo-terminal
#   dt_start_pty_argv [VAR=value ...] -- COMMAND [ARGS...]
#                                     build that command line in the array _dt_pty_argv, to run from DT_HOME (see
#                                     dt_pty_argv); DT_START_PATH, when set, replaces the default PATH of the start
#
# The apply excludes scripts, externals and encrypted files, so nothing is installed, downloaded or decrypted,
# and it never writes outside DIR. A failure prints the status and the first lines of chezmoi's standard error.

# shellcheck disable=SC2154  # _dt_vars and _dt_cmd are set by _dt_split_args of scratch.sh
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/scratch.sh"

# The shell targets: the three directories that hold the shell startup and the dot files that link into them.
dt_render_targets() {
  printf '%s\n' .config/shell .config/zsh .config/bash .config/envrc \
    .profile .bashrc .bash_aliases .bash_logout .zprofile .zshrc .zsh_aliases .hushlogin
}

dt_render_config() {
  local file=${1:?dt_render_config FILE} template
  template=$(dt_source_file .chezmoi.toml.tmpl)
  {
    printf '%s\n' 'umask = 0o027' 'color = "off"' ''
    printf '%s\n' '[data]'
    printf '  %s = "demo-%s"\n' email email gitemail gitemail name name firstname firstname
    printf '\n%s\n  %s\n' '[data.machine]' 'type = "desktop"'
    printf '\n%s\n  %s\n  %s\n' '[data.cpu]' 'cores = 1' 'threads = 1'
    printf '\n%s\n  %s\n' '[data.github]' 'is_codespaces = false'
    printf '\n%s\n  %s\n' '[data.features]' 'incus = false'
    printf '\n%s\n  %s\n  %s\n  %s\n' '[data.nvim]' 'host = ""' 'owner = ""' 'repo = ""'
    printf '\n%s\n  %s\n  %s\n\n' '[data.tools.search]' 'extra = []' 'override = []'
    # the [env] table is copied from the template: one source for the brew-file variables
    sed -n '/^\[env\]/,/^$/p' "$template"
  } > "$file"
}

dt_render() {
  local dir=${1:?dt_render DIR} src=${2:-$DOTFILES_TEST_SOURCE}
  local dest=$dir/destination chezmoi_bin rc t
  local targets=()
  chezmoi_bin=${DT_TOOL_CHEZMOI:-$(dt_find_tool chezmoi)} || return 2
  mkdir -p -- "$dir/stubs" "$dir/state" "$dir/cache"
  mkdir -m 0700 -- "$dir/home" || return 2
  printf '#!/bin/sh\necho "# stub aqua completion"\n' > "$dir/stubs/aqua"
  chmod 0755 "$dir/stubs/aqua"
  dt_render_config "$dir/chezmoi.toml"
  # an empty destination of mode 0750 (what the umask of the configuration gives) with .config below it:
  # made here and never reused, so a destination that exists is an error and not a start from a used one
  mkdir -m 0750 -- "$dest" || return 2
  mkdir -m 0750 -- "$dest/.config" || return 2
  while IFS= read -r t; do
    targets+=("$dest/$t")
  done < <(dt_render_targets)
  rc=0
  env -i PATH="$dir/stubs:$PATH" HOME="$dir/home" LANG=C.UTF-8 "$chezmoi_bin" -S "$src" --config "$dir/chezmoi.toml" --persistent-state "$dir/state/chezmoistate.boltdb" --cache "$dir/cache" --destination "$dest" --no-tty --no-pager apply --exclude=scripts,externals,encrypted "${targets[@]}" > "$dir/apply.out" 2> "$dir/apply.err" < /dev/null || rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'dt_render: the render exited %s: %s\n' "$rc" "$(head -n 3 "$dir/apply.err")" >&2
    return "$rc"
  fi
  printf '%s\n' "$dest"
}

dt_render_ref() {
  local ref=${1:?dt_render_ref REF} dir=${2:?dt_render_ref DIR}
  mkdir -p -- "$dir/source"
  git -C "$DT_ROOT" archive "$ref" .chezmoiroot home | tar -x -C "$dir/source"
  DOTFILES_TEST_SOURCE=$dir/source dt_render "$dir" "$dir/source"
}

dt_prepare_home() {
  local home=${1:?dt_prepare_home HOME} render=${2:?dt_prepare_home RENDER} mise_bin
  mkdir -p -- "$home"
  chmod 0700 -- "$home"
  cp -a -- "$render/." "$home/"
  mkdir -p -- "$home/bin" "$home/.config/mise-scratch"
  mkdir -p -- "$home/.cache"
  chmod 0700 -- "$home/.cache"
  install -D -m 0644 -- "$DT_TESTS_DIR/fixtures/broot-launcher" "$home/.config/broot/launcher/bash/br"
  mise_bin=${DT_TOOL_MISE:-$(dt_find_tool mise 2> /dev/null)} || mise_bin=
  if [ -n "$mise_bin" ]; then
    ln -sfn -- "$mise_bin" "$home/bin/mise"
  fi
  DT_HOME=$home
  export DT_HOME
}

# The mise variables keep mise from reading a configuration in a directory above the scratch home:
# a scratch home below TMPDIR may sit inside a repository or a home.
dt_mise_vars() {
  printf '%s\n' "MISE_CEILING_PATHS=$DT_HOME" "MISE_GLOBAL_CONFIG_FILE=$DT_HOME/.config/mise-scratch/config.toml" \
    "MISE_SYSTEM_CONFIG_FILE=$DT_HOME/.config/mise-scratch/system.toml" "MISE_CONFIG_DIR=$DT_HOME/.config/mise-scratch" \
    "MISE_DATA_DIR=$DT_HOME/.local/share/mise" "MISE_CACHE_DIR=$DT_HOME/.cache/mise" "MISE_STATE_DIR=$DT_HOME/.local/state/mise"
}

# The environment of a terminal on the render.
_dt_start_vars() {
  local mise_vars
  mapfile -t mise_vars < <(dt_mise_vars)
  _dt_start=(XDG_CONFIG_HOME="$DT_HOME/.config" TERM="${DT_TERM:-xterm-256color}" SHELL=/bin/zsh "${mise_vars[@]}")
}

dt_start() {
  _dt_split_args "$@"
  _dt_start_vars
  (cd "$DT_HOME" && DT_PATH=${DT_START_PATH:-$DT_HOME/bin:/usr/local/bin:/usr/bin:/bin} dt_clean "${_dt_start[@]}" "${_dt_vars[@]}" -- "${_dt_cmd[@]}")
}

dt_start_pty_argv() {
  _dt_split_args "$@"
  _dt_start_vars
  DT_PATH=${DT_START_PATH:-$DT_HOME/bin:/usr/local/bin:/usr/bin:/bin} dt_pty_argv "${_dt_start[@]}" "${_dt_vars[@]}" -- "${_dt_cmd[@]}"
}

dt_start_pty() {
  dt_start_pty_argv "$@" || return $?
  (cd "$DT_HOME" && "${_dt_pty_argv[@]}" < /dev/null)
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn=${1:?usage: render.sh <function> [args...]}
  shift
  "$fn" "$@"
fi
