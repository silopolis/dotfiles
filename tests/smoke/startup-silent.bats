#!/usr/bin/env bats
# Proves the spec shell-startup, requirements "Silent startup" (and the debug output scenario): real interactive and
# login shells, started on a scratch render of the shell targets, print nothing unless SHELL_RC_DEBUG is set.
# Counts only: a test compares a number of bytes or lines, never the output itself. The scratch home holds stub
# completion tools, so the first start of a home regenerates their caches: that start is silent too.

load ../helpers/bats/load

setup_file() {
  require_tool chezmoi
  RENDER_DEST=$(dt_render "$BATS_FILE_TMPDIR/render") || return 1
  export RENDER_DEST
}

# the stub tools make a cold start regenerate the eight completion caches, which must be silent too
setup() {
  dt_prepare_home "$BATS_TEST_TMPDIR/home" "$RENDER_DEST"
  dt_make_startup_tools "$DT_HOME"
}

# pty_bytes COMMAND...: the bytes a start prints under a pseudo-terminal, after one start that fills the caches
pty_bytes() {
  dt_start_pty -- "$@" > /dev/null 2>&1 || true
  dt_start_pty -- "$@" 2> /dev/null | wc -c
}

@test "zsh -i -c exit on a cold cache prints nothing under a terminal" {
  require_shell zsh
  assert_equal "$(dt_start_pty -- zsh -i -c exit 2> /dev/null | wc -c)" 0
}

@test "zsh -i -c exit prints nothing under a terminal" {
  require_shell zsh
  assert_equal "$(pty_bytes zsh -i -c exit)" 0
}

@test "zsh -l -i -c exit prints nothing under a terminal" {
  require_shell zsh
  assert_equal "$(pty_bytes zsh -l -i -c exit)" 0
}

@test "bash -i -c true prints nothing under a terminal" {
  require_shell bash
  assert_equal "$(pty_bytes bash -i -c true)" 0
}

@test "bash -l -i -c true prints nothing under a terminal" {
  require_shell bash
  assert_equal "$(pty_bytes bash -l -i -c true)" 0
}

@test "bash -i -c exit prints only the word that bash itself prints" {
  require_shell bash
  dt_start_pty -- bash -i -c exit > /dev/null 2>&1 || true
  run dt_start_pty -- bash -i -c exit
  assert_equal "$(printf '%s' "$output" | tr -d '\r')" exit
}

@test "zsh -i -c exit prints nothing without a terminal" {
  require_shell zsh
  assert_equal "$(dt_start -- zsh -i -c exit 2>&1 | wc -c)" 0
}

@test "zsh -l -i -c exit prints nothing without a terminal" {
  require_shell zsh
  assert_equal "$(dt_start -- zsh -l -i -c exit 2>&1 | wc -c)" 0
}

# a non-interactive login shell loads the environment part only (no completions): what it must keep silent is that part
@test "zsh -l -c true prints nothing without a terminal" {
  require_shell zsh
  assert_equal "$(dt_start -- zsh -l -c true 2>&1 | wc -c)" 0
}

@test "bash -l -c true prints nothing without a terminal" {
  require_shell bash
  assert_equal "$(dt_start -- bash -l -c true 2>&1 | wc -c)" 0
}

# sh -c keeps zsh's own redirection rules (MULTIOS) out of the redirections
@test "debug output is on standard error only" {
  require_shell zsh
  local out err
  out=$(dt_start SHELL_RC_DEBUG=1 -- sh -c 'zsh -l -i -c exit 2>/dev/null </dev/null' | wc -c)
  err=$(dt_start SHELL_RC_DEBUG=1 -- sh -c 'zsh -l -i -c exit 2>&1 >/dev/null </dev/null' | wc -l)
  assert_equal "$out" 0
  [ "$err" -ge 1 ] || fail "no debug line on standard error"
}
