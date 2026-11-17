#!/usr/bin/env bats
# Opt-in comparison of the startup with another ref (the old before-and-after of the startup changes):
#   DOTFILES_TEST_BASE_REF=<ref> mise run test       render that ref and compare
#   DOTFILES_TEST_BASE_ALLOW=<file>                  one name per line: the differences that the change claims
# Both trees are rendered the same way (scratch destination, synthetic configuration); the working tree is the one
# that DOTFILES_TEST_SOURCE names. The comparison covers the alias and function names of interactive zsh and bash, the
# exported names and values of the desktop session replay (values of secret-pattern names left out) and the exported
# names of login shells. A difference that is not allowed fails the test and is printed as names and a count.
# Without the variable every test skips and names it.

load ../helpers/bats/load

setup_file() {
  [ -n "${DOTFILES_TEST_BASE_REF:-}" ] || return 0
  require_tool chezmoi
  CUR_DEST=$(dt_render "$BATS_FILE_TMPDIR/cur") || return 1
  BASE_DEST=$(dt_render_ref "$DOTFILES_TEST_BASE_REF" "$BATS_FILE_TMPDIR/base") || return 1
  export CUR_DEST BASE_DEST
}

setup() {
  require_base_ref
  dt_prepare_home "$BATS_TEST_TMPDIR/cur" "$CUR_DEST"
  dt_write_private_env "$DT_HOME/.config/env"
  CUR_HOME=$DT_HOME
  dt_prepare_home "$BATS_TEST_TMPDIR/base" "$BASE_DEST"
  dt_write_private_env "$DT_HOME/.config/env"
  BASE_HOME=$DT_HOME
}

# against_base FUNCTION [ARGS...]: the same listing in both homes, and the differences that are not allowed
against_base() {
  local a=$BATS_TEST_TMPDIR/cur.txt b=$BATS_TEST_TMPDIR/base.txt
  DT_HOME=$CUR_HOME "$@" > "$a"
  DT_HOME=$BASE_HOME "$@" > "$b"
  [ -s "$a" ] || fail "the listing of the working tree is empty"
  run dt_diff_lists "$a" "$b" "${DOTFILES_TEST_BASE_ALLOW:-}"
  assert_success
}

@test "the alias and function names of an interactive zsh equal those of the base ref" {
  require_shell zsh
  against_base dt_list_names zsh
}

@test "the alias and function names of an interactive bash equal those of the base ref" {
  require_shell bash
  against_base dt_list_names bash
}

@test "the desktop session replay exports the same names and values as the base ref" {
  require_shell zsh
  against_base dt_list_desktop
}

@test "the exported names of zsh -l -i equal those of the base ref" {
  require_shell zsh
  against_base dt_list_login_names zsh
}

@test "the exported names of bash -l -i equal those of the base ref" {
  require_shell bash
  against_base dt_list_login_names bash
}
