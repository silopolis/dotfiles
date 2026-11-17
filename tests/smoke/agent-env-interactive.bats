#!/usr/bin/env bats
# Scenario "Interactive shells load it" of the spec agent-environment: a real interactive zsh, started on a
# scratch render of the shell targets, ends up with the opencode function defined.

load ../helpers/bats/load

setup_file() {
  require_tool chezmoi
  RENDER_DEST=$(dt_render "$BATS_FILE_TMPDIR/render") || return 1
  export RENDER_DEST
}

setup() {
  dt_prepare_home "$BATS_TEST_TMPDIR/home" "$RENDER_DEST"
}

@test "an interactive zsh on the scratch render defines the function" {
  require_shell zsh
  run dt_start_pty -- zsh -i -c 'whence -w opencode'
  assert_success
  assert_equal "$(printf '%s\n' "$output" | tr -d '\r' | tail -n 1)" 'opencode: function'
}
