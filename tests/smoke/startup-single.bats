#!/usr/bin/env bats
# Proves the spec shell-startup, requirement "Single load of the interactive configuration": each shell sources rc.d
# once, and the completion dump header is stable over alternating starts of a login zsh and a normal zsh.
# The debug line "shellrc: sourcing rc.d" is printed once per pass of rc.d, so its count is the number of passes.

load ../helpers/bats/load

setup_file() {
  require_tool chezmoi
  RENDER_DEST=$(dt_render "$BATS_FILE_TMPDIR/render") || return 1
  export RENDER_DEST
}

setup() {
  dt_prepare_home "$BATS_TEST_TMPDIR/home" "$RENDER_DEST"
}

# passes COMMAND...: the passes of rc.d that a start makes, under a pseudo-terminal
passes() {
  dt_start_pty SHELL_RC_DEBUG=1 -- "$@" 2> /dev/null | grep -c 'rc\.d' || true
}

@test "zsh -i -c exit sources rc.d once" {
  require_shell zsh
  assert_equal "$(passes zsh -i -c exit)" 1
}

@test "zsh -l -i -c exit sources rc.d once" {
  require_shell zsh
  assert_equal "$(passes zsh -l -i -c exit)" 1
}

@test "zsh -l -c true (non-interactive login) sources rc.d once" {
  require_shell zsh
  assert_equal "$(passes zsh -l -c true)" 1
}

@test "bash -i -c true sources rc.d once" {
  require_shell bash
  assert_equal "$(passes bash -i -c true)" 1
}

@test "bash -l -i -c true sources rc.d once" {
  require_shell bash
  assert_equal "$(passes bash -l -i -c true)" 1
}

# ~/.bashrc returns at once in a shell that is not interactive: profile runs, rc.d does not
@test "bash -l -c true (non-interactive login) loads profile and no rc.d" {
  require_shell bash
  assert_equal "$(passes bash -l -c true)" 0
}

@test "the completion dump header is the same after five alternating starts" {
  require_shell zsh
  local dump=$DT_HOME/.cache/zcompdump i seen=''
  for i in 1 2 3 4 5; do
    dt_start -- zsh -i -c exit > /dev/null 2>&1
    seen+=$(head -n 1 "$dump" | cut -f1)$'\n'
    dt_start -- zsh -l -i -c exit > /dev/null 2>&1
    seen+=$(head -n 1 "$dump" | cut -f1)$'\n'
  done
  assert_equal "$(printf '%s' "$seen" | grep -c '^#files:')" 10
  assert_equal "$(printf '%s' "$seen" | sort -u | wc -l)" 1
}
