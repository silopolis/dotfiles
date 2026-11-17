#!/usr/bin/env bats
# bats file_tags=live
# The checks of the spec shell-startup that read this machine: opt-in (`DOTFILES_TEST_LIVE=1`, or `mise run test:live`).
# The shells start on a scratch render with a scratch home, but with the PATH of the user, so the tools that are
# installed here are the ones that are timed and whose completion scripts are cached. Nothing is written outside the
# scratch directory and nothing prints a name or a value of the real environment.
#
#   - "Fast startup": medians of 7 alternating rounds of the four shell kinds under a pseudo-terminal (one warm-up
#     start each), timed with GNU time when it is found at run time and with `date` otherwise;
#   - "Cached completions" with the real tools: a cold cache, a hit, a refresh and a hit again, in zsh and in bash.

load ../helpers/bats/load

ROUNDS=7

setup_file() {
  [ "${DOTFILES_TEST_LIVE:-}" = 1 ] || return 0
  require_tool chezmoi
  RENDER_DEST=$(dt_render "$BATS_FILE_TMPDIR/render") || return 1
  export RENDER_DEST
  dt_prepare_home "$BATS_FILE_TMPDIR/timing" "$RENDER_DEST"
  export DT_START_PATH=$DT_HOME/bin:$PATH
  local kinds=("zsh -i -c exit" "zsh -l -i -c exit" "bash -i -c true" "bash -l -i -c true") kind k n
  local -A seen
  for kind in "${kinds[@]}"; do
    # shellcheck disable=SC2086  # the kind is a command line of three or four words
    dt_start_pty -- $kind > /dev/null 2>&1 || true
  done
  for _ in $(seq "$ROUNDS"); do
    for kind in "${kinds[@]}"; do
      # shellcheck disable=SC2086
      dt_start_pty_argv -- $kind
      k=${kind// /_}
      seen[$k]+="$(cd "$DT_HOME" && dt_elapsed "${_dt_pty_argv[@]}") "
    done
  done
  for kind in "${kinds[@]}"; do
    k=${kind// /_}
    # shellcheck disable=SC2086
    dt_median ${seen[$k]} > "$BATS_FILE_TMPDIR/median-$k"
  done
  n=$(dt_timing_tool)
  printf '%s\n' "$n" > "$BATS_FILE_TMPDIR/timing-tool"
}

median() {
  cat "$BATS_FILE_TMPDIR/median-${1// /_}"
}

@test "an interactive zsh starts in at most 1.0 s (median of 7 alternating rounds under a terminal)" {
  require_live
  local m
  m=$(median "zsh -i -c exit")
  echo "median ${m} s, timed with $(cat "$BATS_FILE_TMPDIR/timing-tool")" >&3
  awk -v m="$m" 'BEGIN { exit !(m <= 1.0) }' || fail "the median of zsh -i -c exit is ${m} s, above 1.0 s"
}

@test "a login interactive zsh starts in at most 150 ms more than an interactive one" {
  require_live
  local plain login
  plain=$(median "zsh -i -c exit")
  login=$(median "zsh -l -i -c exit")
  echo "medians: interactive ${plain} s, login ${login} s" >&3
  awk -v a="$plain" -v b="$login" 'BEGIN { exit !(b <= a + 0.150) }' || fail "login ${login} s is more than 150 ms above ${plain} s"
}

# cache_with_real_tools COMMAND...: cold, hit, refresh, hit again; the counts are the regenerations printed on the debug line
cache_with_real_tools() {
  local cold hit refresh again
  dt_prepare_home "$BATS_TEST_TMPDIR/home" "$RENDER_DEST"
  export DT_START_PATH=$DT_HOME/bin:$PATH
  count() { dt_start_pty SHELL_RC_DEBUG=1 "$@" 2> /dev/null | grep -c 'completion cache: regenerated' || true; }
  cold=$(count -- "${@}")
  hit=$(count -- "${@}")
  refresh=$(count SHELL_COMPLETION_REFRESH=1 -- "${@}")
  again=$(count -- "${@}")
  echo "regenerated: cold ${cold}, second start ${hit}, refresh ${refresh}, after the refresh ${again}" >&3
  [ "$cold" -ge 1 ] || skip "none of the tools whose completion is cached is installed on this machine"
  assert_equal "$hit" 0
  assert_equal "$refresh" "$cold"
  assert_equal "$again" 0
}

@test "zsh: the completion cache is filled, hit, refreshed and hit again, with the real tools" {
  require_live
  require_shell zsh
  cache_with_real_tools zsh -i -c exit
}

@test "bash: the completion cache is filled, hit, refreshed and hit again, with the real tools" {
  require_live
  require_shell bash
  cache_with_real_tools bash -i -c true
}
