#!/usr/bin/env bats
# Proves the spec shell-startup, requirement "Cached completions", on real shells started on a scratch render with
# stub completion tools: a cold cache is generated, the next start is a hit that runs no generator, a refresh
# regenerates every file, and the start after it is a hit again. Run in zsh and in bash (named `zsh ...`, `bash ...`).
# The debug line "completion cache: regenerated <tool>" is printed on standard error for each regeneration.

load ../helpers/bats/load

setup_file() {
  require_tool chezmoi
  RENDER_DEST=$(dt_render "$BATS_FILE_TMPDIR/render") || return 1
  export RENDER_DEST
}

setup() {
  dt_prepare_home "$BATS_TEST_TMPDIR/home" "$RENDER_DEST"
  dt_make_startup_tools "$DT_HOME"
  STUBLOG=$DT_HOME/stub.log
  : > "$STUBLOG"
}

# start [VAR=value ...]: one start of the shell under test (zsh -i, or bash -i), with the debug line on, under a terminal
start() {
  local cmd=(zsh -i -c exit)
  [ "$CACHE_TAG" = bash ] && cmd=(bash -i -c true)
  dt_start_pty SHELL_RC_DEBUG=1 STUBLOG="$STUBLOG" "$@" -- "${cmd[@]}" 2> /dev/null
}

regenerated() {
  grep -c 'completion cache: regenerated' || true
}

generator_calls() {
  grep -c ' completion ' "$STUBLOG" || true
}

cache_cold() {
  assert_equal "$(start | regenerated)" 8
}

cache_hit() {
  start > /dev/null
  : > "$STUBLOG"
  assert_equal "$(start | regenerated)" 0
  assert_equal "$(generator_calls)" 0
}

cache_refresh() {
  start > /dev/null
  assert_equal "$(start SHELL_COMPLETION_REFRESH=1 | regenerated)" 8
}

cache_hit_again() {
  start > /dev/null
  start SHELL_COMPLETION_REFRESH=1 > /dev/null
  assert_equal "$(start | regenerated)" 0
}

# cache ID TAG: one check in one shell; a shell that is absent skips with its name
cache() {
  require_shell "$2"
  CACHE_TAG=$2
  "cache_$1"
}

ids=(cold hit refresh hit_again)
descs=(
  "cold cache: the eight cached tools are generated"
  "second start: nothing is regenerated and no generator runs"
  "SHELL_COMPLETION_REFRESH=1 regenerates all eight"
  "the start after a refresh is a hit again"
)
for tag in zsh bash; do
  for i in "${!ids[@]}"; do
    bats_test_function --description "$tag ${descs[$i]}" -- cache "${ids[$i]}" "$tag"
  done
done
