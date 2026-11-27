#!/usr/bin/env bats
# Proves the spec shell-environment, requirement "The session's umask comes from the login": the startup files set no
# umask, so a shell started with a umask ends its startup with that umask. The desktop replay, zsh -i and bash -l -i start
# on a scratch render under env -i, once with 0027 and once with 0002 (the umask of the caller is the one they inherit).

load ../helpers/bats/load

setup_file() {
  require_tool chezmoi
  RENDER_DEST=$(dt_render "$BATS_FILE_TMPDIR/render") || return 1
  export RENDER_DEST
}

setup() {
  dt_prepare_home "$BATS_TEST_TMPDIR/home" "$RENDER_DEST"
  dt_write_private_env "$DT_HOME/.config/env"
  require_shell zsh
  require_shell bash
}

# started_with KIND UMASK: the umask that the kind reports after its startup when it was started with UMASK, on four digits
# (bash prints 0027 and zsh 027)
started_with() {
  local out value
  out=$(umask "$2" && dt_kind_run "$1" 'echo "@@UMASK=$(umask)"')
  value=$(printf '%s\n' "$out" | sed -n 's/^@@UMASK=//p' | tail -n 1)
  printf '%04d\n' "$((10#$value))"
}

@test "the desktop replay ends its startup with the umask it started with" {
  assert_equal "$(started_with desktop 0027)" 0027
  assert_equal "$(started_with desktop 0002)" 0002
}

@test "zsh -i ends its startup with the umask it started with" {
  assert_equal "$(started_with zsh-i 0027)" 0027
  assert_equal "$(started_with zsh-i 0002)" 0002
}

@test "bash -l -i ends its startup with the umask it started with" {
  assert_equal "$(started_with bash-li 0027)" 0027
  assert_equal "$(started_with bash-li 0002)" 0002
}
