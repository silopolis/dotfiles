#!/usr/bin/env bats
# Proves the spec shell-environment, requirement "The desktop login loads the environment only": the replay of the display
# manager's call, `zsh -l -c` and `bash -l -c`, started on a scratch render under env -i with the PATH that /etc/profile
# gives a login shell. They source shell/environment (the env_ files) and nothing else; a login sh loads nothing.
# Counts of lines and names, and positions in PATH: no scenario prints a name or a value of the real environment.

load ../helpers/bats/load

setup_file() {
  require_tool chezmoi
  RENDER_DEST=$(dt_render "$BATS_FILE_TMPDIR/render") || return 1
  export RENDER_DEST
}

setup() {
  dt_prepare_home "$BATS_TEST_TMPDIR/home" "$RENDER_DEST"
  # mise's shims directory exists on the machines this is written for (see environment-path.bats)
  mkdir -p "$DT_HOME/.local/share/mise/shims"
  require_shell zsh
  require_shell bash
}

# the three kinds that the login of the desktop loads the environment in
login_kinds() { printf '%s\n' desktop zsh-lc bash-lc; }

entries() { # PATH: one entry per line
  printf '%s\n' "$1" | tr ':' '\n'
}

# sh_login SNIPPET [VAR=value ...]: `sh -l -c SNIPPET`, handed the environment that the kinds get; output and errors together
sh_login() {
  local snippet=$1 user
  shift
  user=$(id -un)
  DT_START_PATH=$(dt_login_path) dt_start LANG="$(dt_kind_lang)" SHELL=/usr/bin/zsh USER="$user" LOGNAME="$user" "$@" -- "$SH_BIN" -l -c "$snippet" 2>&1
}

# the names that the desktop replay exports and that a file outside the env_ files must not export or touch
exports_of_non_env_files() { # RC.D-DIRECTORY: the names exported by `export` lines of the files whose names lack -env_
  local f
  for f in "$1"/*.sh; do
    case ${f##*/} in
      *-env_*) continue ;;
    esac
    sed -n 's/^[[:space:]]*export[[:space:]]\{1,\}\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' "$f"
  done | sort -u
}

path_writers() { # RC.D-DIRECTORY: the files whose names lack -env_ and that change PATH, mise's activation apart
  local f
  for f in "$1"/*.sh; do
    case ${f##*/} in
      *-env_* | 415-tools_mise.sh) continue ;;
    esac
    if sed 's/^[[:space:]]*#.*//' "$f" | grep -q -E '(^|[[:space:]])(PATH|path)\+?=|export[[:space:]]+PATH|_path_(prepend|clean)'; then
      printf '%s\n' "${f##*/}"
    fi
  done
}

@test "no rc.d pass in the desktop replay, zsh -l -c and bash -l -c: the environment is loaded once" {
  local kind
  for kind in $(login_kinds); do
    assert_equal "$(dt_kind_debug_count "$kind" 'rc\.d')" 0
    assert_equal "$(dt_kind_debug_count "$kind" '^environment:')" 1
  done
}

@test "what the session keeps: the XDG directories, the locale, EDITOR, CURRENT_SHELL and PATH" {
  local kind names=(PATH XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME LANG LANGUAGE EDITOR CURRENT_SHELL)
  if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    names+=(HOMEBREW_PREFIX)
  fi
  for kind in $(login_kinds); do
    assert_equal "$(dt_kind_exported "$kind" "${names[@]}")" "${#names[@]}"
  done
}

@test "what the session no longer gets: no forgit_, LESS_TERMCAP_ or __MISE_ name, and no LS_COLORS, LESSOPEN, HSTR_CONFIG, MISE_SHELL or LC_ALL" {
  local kind names
  for kind in $(login_kinds); do
    names=$(dt_kind_export_names "$kind")
    [ -n "$names" ] || fail "$kind: no exported name"
    assert_equal "$(printf '%s\n' "$names" | grep -c -E '^(forgit_|LESS_TERMCAP_|__MISE_)' || true)" 0
    assert_equal "$(printf '%s\n' "$names" | grep -c -x -e LS_COLORS -e LESSOPEN -e HSTR_CONFIG -e MISE_SHELL -e LC_ALL || true)" 0
  done
}

@test "the first entry of PATH is a user bin directory in the desktop replay, zsh -l -c and bash -l -c, before mise's shims" {
  local kind p first
  mkdir -p "$DT_HOME/.local/bin" "$DT_HOME/.local/sbin"
  for kind in $(login_kinds); do
    p=$(dt_kind_path "$kind")
    first=$(entries "$p" | head -n 1)
    case $first in
      "$DT_HOME/.local/bin" | "$DT_HOME/.local/sbin") ;;
      *) fail "$kind: the first entry of PATH is not a user bin directory" ;;
    esac
    [ "$(entries "$p" | grep -n -x -F "$DT_HOME/.local/share/mise/shims" | cut -d: -f1)" -gt 2 ] || fail "$kind: mise's shims come before a user bin directory"
  done
}

@test "only env_ files hold the environment: no other rc.d file exports a name the desktop replay sets or changes PATH" {
  local rcd names
  rcd=$(dt_source_file dot_config/shell/rc.d)
  names=$(exports_of_non_env_files "$rcd")
  [ -n "$names" ] || fail "the search found no export at all: it is broken"
  assert_equal "$(dt_kind_export_names desktop | grep -c -x -F -f <(printf '%s\n' "$names") || true)" 0
  assert_equal "$(path_writers "$rcd" | wc -l)" 0
}

@test "the search of the previous test finds an export and a PATH change in a file that is not an env_ file, and ignores an env_ file" {
  local d=$BATS_TEST_TMPDIR/rc.d
  mkdir -p "$d"
  printf 'export EDITOR=vi\n#export IGNORED=1\n' > "$d/100-other.sh"
  printf 'PATH="$PATH:/x"\n' > "$d/110-path.sh"
  printf 'export CONFINED=1\nPATH="$PATH:/y"\n' > "$d/120-env_ok.sh"
  printf 'eval "$(mise activate bash)"\nPATH="$PATH:/z"\n' > "$d/415-tools_mise.sh"
  assert_equal "$(exports_of_non_env_files "$d" | tr '\n' ' ')" 'EDITOR '
  assert_equal "$(path_writers "$d" | tr '\n' ' ')" '110-path.sh '
}

@test "a login sh loads nothing: no output without SHELL_RC_DEBUG, only the line of profile with it, and no name of an env_ file" {
  SH_BIN=$(type -P sh) || skip "no sh on this machine"
  [ "$(basename "$(readlink -f "$SH_BIN")")" != bash ] || skip "sh is bash on this machine: the guard of profile cannot tell it from bash"
  local out
  assert_equal "$(sh_login true | wc -c)" 0
  out=$(sh_login true SHELL_RC_DEBUG=1)
  assert_equal "$(printf '%s\n' "$out" | grep -c -e 'rc\.d' -e '^environment:' || true)" 0
  assert_equal "$(printf '%s\n' "$out" | grep -c '^profile:' || true)" 1
  assert_equal "$(printf '%s\n' "$out" | wc -l)" 1
  out=$(sh_login 'printf "@@N=%s\n" "$(env | cut -d= -f1 | grep -cx -e XDG_DATA_HOME -e XDG_STATE_HOME -e XDG_CACHE_HOME -e XDG_BIN_HOME -e XDG_LIB_HOME -e LANGUAGE -e EDITOR -e HOMEBREW_PREFIX)"')
  assert_equal "$(printf '%s\n' "$out" | sed -n 's/^@@N=//p')" 0
}

@test "profile is POSIX, a login sh reads it: sh, bash and zsh parse it and shellcheck -s sh accepts it; shellrc and environment parse in bash and zsh" {
  require_tool shellcheck
  local f
  f=$(dt_source_file dot_config/shell/profile)
  sh -n "$f"
  bash -n "$f"
  zsh -n "$f"
  run "$DT_TOOL_SHELLCHECK" -s sh "$f"
  [ "$status" -eq 0 ] || fail "shellcheck -s sh refuses profile: $output"
  for f in shellrc environment; do
    f=$(dt_source_file "dot_config/shell/$f")
    bash -n "$f"
    zsh -n "$f"
  done
}
