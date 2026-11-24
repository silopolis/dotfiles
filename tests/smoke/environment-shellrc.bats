#!/usr/bin/env bats
# Proves the spec shell-environment, requirement "The shared interactive configuration is interactive-only": shellrc
# returns at once in a shell that is not interactive, and a bash that sshd starts for a command (~/.bashrc is shellrc)
# loads nothing. Real shells on a scratch render under env -i; counts of lines and names only.

load ../helpers/bats/load

setup_file() {
  require_tool chezmoi
  RENDER_DEST=$(dt_render "$BATS_FILE_TMPDIR/render") || return 1
  export RENDER_DEST
}

setup() {
  dt_prepare_home "$BATS_TEST_TMPDIR/home" "$RENDER_DEST"
  dt_write_private_env "$DT_HOME/.config/env"
  NAME_A=$(dt_alpha_name)
  NAME_B=$(dt_beta_name)
  require_shell zsh
  require_shell bash
}

# sourced KIND: what the kind prints when it sources shellrc without being interactive, as a debug run
sourced() {
  dt_kind_run "$1" '. "$HOME/.config/shell/shellrc"; echo done' SHELL_RC_DEBUG=1
}

@test "zsh -c sourcing shellrc prints done and no rc.d line" {
  local out
  out=$(sourced zsh-c)
  assert_equal "$(printf '%s\n' "$out" | grep -c -x done || true)" 1
  assert_equal "$(printf '%s\n' "$out" | grep -c 'rc\.d' || true)" 0
}

@test "bash -c sourcing shellrc prints done and no rc.d line" {
  local out
  out=$(sourced bash-c)
  assert_equal "$(printf '%s\n' "$out" | grep -c -x done || true)" 1
  assert_equal "$(printf '%s\n' "$out" | grep -c 'rc\.d' || true)" 0
}

@test "a non-interactive shell that sources shellrc gets no name of the environment either: shellrc is the interactive part" {
  local kind
  for kind in zsh-c bash-c; do
    assert_equal "$(dt_kind_run "$kind" '. "$HOME/.config/shell/shellrc"; printf "@@N=%s\n" "$(env | cut -d= -f1 | grep -cx -e XDG_STATE_HOME -e XDG_CACHE_HOME -e EDITOR -e LANGUAGE)"' | sed -n 's/^@@N=//p')" 0
  done
}

@test "bash -c as sshd starts it (SSH_CLIENT set, shell level 0) holds no name of the private file and prints no rc.d line" {
  assert_equal "$(dt_kind_exported bash-ssh "$NAME_A" "$NAME_B")" 0
  assert_equal "$(dt_kind_debug_count bash-ssh 'rc\.d')" 0
}
