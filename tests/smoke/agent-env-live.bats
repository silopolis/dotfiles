#!/usr/bin/env bats
# bats file_tags=live
# The checks of the spec agent-environment that read this machine: opt-in (`DOTFILES_TEST_LIVE=1`, or
# `mise run test:live`) and read-only. They print counts and statuses, never the name or the value of a
# variable of the real environment.

load ../helpers/bats/load

@test "the deployed target equals the source" {
  require_live
  require_tool chezmoi
  local target=$DOTFILES_TEST_REAL_HOME/.config/shell/rc.d/445-tools_opencode.sh
  [ -f "$target" ] || skip "the target is not deployed on this machine"
  run env HOME="$DOTFILES_TEST_REAL_HOME" "$DT_TOOL_CHEZMOI" -S "$DOTFILES_TEST_SOURCE" \
    diff --exclude=externals,scripts --no-pager "$target"
  assert_success
  assert_equal "$output" ""
}

@test "no lowercase or mixed-case secret-like name is set in the user environment" {
  require_live
  [ -n "${DT_REAL_SECRET_ANY:-}" ] || skip "the runner did not count the environment: run it through tests/run.sh"
  assert_equal "$DT_REAL_SECRET_ANY" "$DT_REAL_SECRET_UPPER"
}

@test "no name of the user environment file is written in the source file" {
  require_live
  local env_file=${DOTFILES_TEST_REAL_CONFIG:-$DOTFILES_TEST_REAL_HOME/.config}/env names count source_file
  [ -f "$env_file" ] || skip "the user environment file does not exist on this machine"
  source_file=$(dt_source_file dot_config/shell/rc.d/445-tools_opencode.sh)
  # the names stay in this variable and in a pipe: only the count is compared and printed
  names=$(sed -n 's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}\([A-Za-z_][A-Za-z0-9_]*\)=.*/\2/p' "$env_file")
  if [ -z "$names" ]; then
    skip "the user environment file sets no variable"
  fi
  count=$(printf '%s\n' "$names" | grep -c -F -f /dev/stdin "$source_file" || true)
  assert_equal "$count" 0
}
