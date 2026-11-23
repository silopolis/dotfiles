#!/usr/bin/env bats
# Proves the spec shell-environment, requirements "The desktop login loads the environment only" and "Clean PATH", for
# each env_ file that puts something on PATH, one file at a time and in zsh and bash: the PATH helper, the base PATH,
# brew, aqua, snap, krew, go, rust, mise's shims directory and the user's bin directories. Each file is sourced after
# the helper, under env -i with a scratch home; sourcing it twice must change nothing (a nested shell sources it again).

load ../helpers/bats/load

RC_D=dot_config/shell/rc.d

setup() {
  setup_scratch
  HELPER=$(dt_source_file "$RC_D/035-env_path_helper.sh")
  BASE=/usr/bin:/bin
}

# run_files SHELL PATH SNIPPET [VAR=value ...] FILE...: source the helper and the files under env -i, run the snippet.
# The files are names under rc.d.
run_files() {
  local sh=$1 path=$2 snippet=$3 vars=() files=() src a
  shift 3
  for a in "$@"; do
    case $a in
      *=*) vars+=("$a") ;;
      *) files+=("$a") ;;
    esac
  done
  src=". '$HELPER';"
  for a in "${files[@]}"; do
    src+=" . '$(dt_source_file "$RC_D/$a")';"
  done
  env -i HOME="$DT_HOME" LANG=C.UTF-8 PATH="$path" "${vars[@]}" "$sh" -c "$src $snippet" < /dev/null 2>&1
}

# each_shell_expect PATH SNIPPET EXPECTED [VAR=value ...] FILE...
each_shell_expect() {
  local sh want got path=$1 snippet=$2
  want=$3
  shift 3
  for sh in zsh bash; do
    got=$(run_files "$(dt_shell_path "$sh")" "$path" "$snippet" "$@")
    [ "$got" = "$want" ] || fail "$sh: expected [$want] got [$got]"
  done
}

SHOW_PATH='printf "%s\n" "$PATH"'

@test "040 keeps the inherited PATH, appends the system directories that are missing, and drops what is not a directory" {
  local d present=0 listed=0 mine=$DT_HOME/mine gone=$DT_HOME/gone sh got
  mkdir -p "$mine"
  for sh in zsh bash; do
    got=$(run_files "$(dt_shell_path "$sh")" "$mine:$gone:/usr/bin:$mine" "$SHOW_PATH" 040-env_path_base.sh)
    case $got in
      "$mine:/usr/bin:"*) ;;
      *) fail "$sh: the inherited entries did not stay first, in order, once: [$got]" ;;
    esac
    case $got in
      *"$gone"*) fail "$sh: a missing directory stayed" ;;
    esac
    [ "$(printf '%s\n' "$got" | tr ':' '\n' | sort | uniq -d | wc -l)" -eq 0 ] || fail "$sh: a duplicate in [$got]"
    for d in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/local/games /usr/games; do
      [ -d "$d" ] || continue
      listed=$((listed + 1))
      case ":$got:" in *":$d:"*) present=$((present + 1)) ;; esac
    done
    [ "$present" -eq "$listed" ] || fail "$sh: a system directory is missing from [$got]"
    present=0
    listed=0
  done
}

@test "040 sourced twice, and in a nested shell, gives the same PATH" {
  local sh once twice
  for sh in zsh bash; do
    once=$(run_files "$(dt_shell_path "$sh")" "$BASE" "$SHOW_PATH" 040-env_path_base.sh)
    twice=$(run_files "$(dt_shell_path "$sh")" "$BASE" "$SHOW_PATH" 040-env_path_base.sh 040-env_path_base.sh)
    [ "$once" = "$twice" ] || fail "$sh: [$once] then [$twice]"
  done
}

@test "042 with aqua installed keeps an inherited AQUA_BIN_DIR as it is and puts it first, at every level" {
  local bin=$DT_HOME/stubs custom=$DT_HOME/aqua-bin sh got
  mkdir -p "$bin" "$custom"
  printf '#!/bin/sh\nexit 0\n' > "$bin/aqua"
  chmod 0755 "$bin/aqua"
  for sh in zsh bash; do
    got=$(run_files "$(dt_shell_path "$sh")" "$bin:$BASE" 'printf "%s %s\n" "$AQUA_BIN_DIR" "${PATH%%:*}"' AQUA_BIN_DIR="$custom" 042-env_pkg_aqua.sh 042-env_pkg_aqua.sh 042-env_pkg_aqua.sh)
    [ "$got" = "$custom $custom" ] || fail "$sh: [$got]"
  done
}

@test "042 without an inherited AQUA_BIN_DIR sets it under AQUA_ROOT_DIR once, and puts it on PATH when it exists" {
  local bin=$DT_HOME/stubs root=$DT_HOME/aqua-root sh got
  mkdir -p "$bin" "$root/bin"
  printf '#!/bin/sh\nexit 0\n' > "$bin/aqua"
  chmod 0755 "$bin/aqua"
  for sh in zsh bash; do
    got=$(run_files "$(dt_shell_path "$sh")" "$bin:$BASE" 'printf "%s %s\n" "$AQUA_BIN_DIR" "${PATH%%:*}"' AQUA_ROOT_DIR="$root" 042-env_pkg_aqua.sh 042-env_pkg_aqua.sh)
    [ "$got" = "$root/bin $root/bin" ] || fail "$sh: [$got]"
  done
}

@test "042 without aqua sets nothing" {
  each_shell_expect "$BASE" 'printf "%s|%s|%s\n" "${AQUA_ROOT_DIR-unset}" "${AQUA_BIN_DIR-unset}" "$PATH"' "unset|unset|$BASE" 042-env_pkg_aqua.sh
}

@test "043 puts /snap/bin first when it is a directory, and changes nothing otherwise" {
  local want=$BASE
  [ -d /snap/bin ] && want=/snap/bin:$BASE
  each_shell_expect "$BASE" "$SHOW_PATH" "$want" 043-env_pkg_snap.sh 043-env_pkg_snap.sh
}

@test "044 sets KREW_ROOT and KREW_PLUGINS_DIR and puts the plugins directory first when it exists" {
  mkdir -p "$DT_HOME/.krew/bin"
  each_shell_expect "$BASE" 'printf "%s %s %s\n" "$KREW_ROOT" "$KREW_PLUGINS_DIR" "$PATH"' "$DT_HOME/.krew $DT_HOME/.krew/bin $DT_HOME/.krew/bin:$BASE" 044-env_pkg_krew.sh 044-env_pkg_krew.sh
}

@test "044 leaves PATH alone when the plugins directory does not exist" {
  each_shell_expect "$BASE" "$SHOW_PATH" "$BASE" 044-env_pkg_krew.sh
}

@test "045 sets GOPATH and GOBIN and puts GOBIN first when it exists" {
  mkdir -p "$DT_HOME/.local/go/bin"
  each_shell_expect "$BASE" 'printf "%s %s %s\n" "$GOPATH" "$GOBIN" "$PATH"' "$DT_HOME/.local/go $DT_HOME/.local/go/bin $DT_HOME/.local/go/bin:$BASE" 045-env_lang_go.sh 045-env_lang_go.sh
}

@test "046 puts the rustup directory of brew first when HOMEBREW_PREFIX names one that exists" {
  local prefix=$DT_HOME/brew
  mkdir -p "$prefix/opt/rustup/bin"
  each_shell_expect "$BASE" "$SHOW_PATH" "$prefix/opt/rustup/bin:$BASE" HOMEBREW_PREFIX="$prefix" 046-env_lang_rust.sh 046-env_lang_rust.sh
}

@test "046 does nothing without HOMEBREW_PREFIX" {
  each_shell_expect "$BASE" "$SHOW_PATH" "$BASE" 046-env_lang_rust.sh
}

@test "047 puts the shims directory of mise first when it exists, without MISE_DATA_DIR" {
  mkdir -p "$DT_HOME/.local/share/mise/shims"
  each_shell_expect "$BASE" "$SHOW_PATH" "$DT_HOME/.local/share/mise/shims:$BASE" 047-env_tools_mise.sh 047-env_tools_mise.sh
}

@test "047 follows XDG_DATA_HOME, and MISE_DATA_DIR when that is set" {
  mkdir -p "$DT_HOME/xdg/mise/shims" "$DT_HOME/data/shims"
  each_shell_expect "$BASE" "$SHOW_PATH" "$DT_HOME/xdg/mise/shims:$BASE" XDG_DATA_HOME="$DT_HOME/xdg" 047-env_tools_mise.sh
  each_shell_expect "$BASE" "$SHOW_PATH" "$DT_HOME/data/shims:$BASE" XDG_DATA_HOME="$DT_HOME/xdg" MISE_DATA_DIR="$DT_HOME/data" 047-env_tools_mise.sh
}

@test "047 leaves PATH alone when there is no shims directory" {
  each_shell_expect "$BASE" "$SHOW_PATH" "$BASE" 047-env_tools_mise.sh
}

@test "050 puts the user's bin directories first, .local/sbin before .local/bin before sbin before bin, and skips the missing ones" {
  mkdir -p "$DT_HOME/bin" "$DT_HOME/.local/bin" "$DT_HOME/.local/sbin"
  each_shell_expect "$BASE" "$SHOW_PATH" "$DT_HOME/.local/sbin:$DT_HOME/.local/bin:$DT_HOME/bin:$BASE" 050-env_path_user.sh 050-env_path_user.sh
}

@test "050 sourced after a PATH that already holds the directories moves them to the front without duplicates" {
  mkdir -p "$DT_HOME/.local/bin"
  each_shell_expect "/usr/bin:$DT_HOME/.local/bin:/bin" "$SHOW_PATH" "$DT_HOME/.local/bin:/usr/bin:/bin" 050-env_path_user.sh
}

@test "041 sets the brew variables once and puts the brew directories first, at every level" {
  [ -x /home/linuxbrew/.linuxbrew/bin/brew ] || skip "brew is not installed"
  local sh once twice prefix=/home/linuxbrew/.linuxbrew
  for sh in zsh bash; do
    once=$(run_files "$(dt_shell_path "$sh")" "$BASE" 'printf "%s %s\n" "$HOMEBREW_PREFIX" "$PATH"' CURRENT_SHELL="$sh" 041-env_pkg_brew.sh)
    twice=$(run_files "$(dt_shell_path "$sh")" "$BASE" 'printf "%s %s\n" "$HOMEBREW_PREFIX" "$PATH"' CURRENT_SHELL="$sh" 041-env_pkg_brew.sh 041-env_pkg_brew.sh)
    [ "$once" = "$twice" ] || fail "$sh: [$once] then [$twice]"
    case $once in
      "$prefix $prefix/bin:$prefix/sbin:"*) ;;
      *) fail "$sh: the brew directories are not first, bin then sbin: [$once]" ;;
    esac
  done
}

@test "041 sets the brew-file variables when brew-file is installed" {
  [ -x /home/linuxbrew/.linuxbrew/bin/brew-file ] || skip "brew-file is not installed"
  each_shell_expect "$BASE" 'printf "%s %s\n" "${HOMEBREW_BREWFILE_FULL_NAME-unset}" "${HOMEBREW_BREWFILE_ON_REQUEST-unset}"' "1 1" CURRENT_SHELL=bash 041-env_pkg_brew.sh
}

@test "110 keeps the interactive part of brew: no shellenv and no exported HOMEBREW variable" {
  local f
  f=$(dt_source_file "$RC_D/110-pkg_brew.sh")
  assert_equal "$(grep -c 'shellenv' "$f" || true)" 0
  assert_equal "$(grep -c 'export HOMEBREW' "$f" || true)" 0
  assert_equal "$(grep -c '_post_brewfile_update ()' "$f")" 1
}

@test "every file of this group is POSIX: shellcheck -s sh accepts it, and zsh -n and bash -n parse it" {
  require_tool shellcheck
  local f
  for f in 035-env_path_helper.sh 040-env_path_base.sh 042-env_pkg_aqua.sh 043-env_pkg_snap.sh 044-env_pkg_krew.sh 045-env_lang_go.sh 046-env_lang_rust.sh 047-env_tools_mise.sh 050-env_path_user.sh; do
    f=$(dt_source_file "$RC_D/$f")
    run "$DT_TOOL_SHELLCHECK" -s sh "$f"
    [ "$status" -eq 0 ] || fail "shellcheck -s sh refuses a file of the group: $output"
    zsh -n "$f"
    bash -n "$f"
  done
}
