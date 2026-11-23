#!/usr/bin/env bats
# bats file_tags=live
# The checks of the spec shell-environment that read this machine: opt-in (`DOTFILES_TEST_LIVE=1`, or
# `mise run test:live`) and read-only. They print counts and statuses, never the name or the value of a variable of
# the real environment: the names of the user's private file stay in memory and in a pipe.

load ../helpers/bats/load

@test "no name of the user's private file is written in the shell source" {
  require_live
  local env_file=${DOTFILES_TEST_REAL_CONFIG:-$DOTFILES_TEST_REAL_HOME/.config}/env names count
  [ -f "$env_file" ] || skip "the user environment file does not exist on this machine"
  names=$(sed -n 's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}\([A-Za-z_][A-Za-z0-9_]*\)=.*/\2/p' "$env_file")
  if [ -z "$names" ]; then
    skip "the user environment file sets no variable"
  fi
  # the number of files of the shell source that hold one of the names as a word
  count=$(printf '%s\n' "$names" | grep -r -l -w -F -f /dev/stdin "$(dt_source_file dot_config/shell)" | wc -l)
  assert_equal "$count" 0
}
