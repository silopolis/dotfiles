#!/usr/bin/env bats
# Proves the spec shell-environment, requirements "No key in a new shell" and "Keys on demand", with real shells: the
# kinds of the study started on a scratch render with a synthetic private file of two DEMO_ names in the scratch home.
# Counts only: how many of the two names a shell exports. No scenario prints a name or a value.

load ../helpers/bats/load

setup_file() {
  require_tool chezmoi
  RENDER_DEST=$(dt_render "$BATS_FILE_TMPDIR/render") || return 1
  export RENDER_DEST
}

setup() {
  dt_prepare_home "$BATS_TEST_TMPDIR/home" "$RENDER_DEST"
  dt_write_private_env "$DT_HOME/.config/env"
  dt_make_opencode_stub "$DT_HOME"
  NAME_A=$(dt_alpha_name)
  NAME_B=$(dt_beta_name)
  require_shell zsh
  require_shell bash
}

@test "every shell kind exports none of the names of the private file" {
  local kind
  for kind in $(dt_kinds); do
    assert_equal "$(dt_kind_exported "$kind" "$NAME_A" "$NAME_B")" 0
  done
}

@test "the desktop replay exports none of them, and no file of the session reads the private file" {
  assert_equal "$(dt_kind_exported desktop "$NAME_A" "$NAME_B")" 0
}

@test "inherited copies are dropped: an interactive zsh and an interactive bash started with both names and no marker hold none" {
  local kind
  for kind in zsh-i bash-i zsh-li bash-li; do
    assert_equal "$(dt_kind_exported "$kind" "$NAME_A" "$NAME_B" "$NAME_A=held" "$NAME_B=held")" 0
  done
}

@test "inherited copies stay in an interactive shell whose parent loaded them: the marker is set" {
  local kind
  for kind in zsh-i bash-i; do
    assert_equal "$(dt_kind_exported "$kind" "$NAME_A" "$NAME_B" "$NAME_A=held" "$NAME_B=held" DOTFILES_SECRETS=loaded)" 2
  done
}

@test "a name that the private file does not set is not dropped" {
  assert_equal "$(dt_kind_exported zsh-i DEMO_OTHER DEMO_OTHER=held)" 1
  assert_equal "$(dt_kind_exported bash-i DEMO_OTHER DEMO_OTHER=held)" 1
}

@test "the revoked variable stays unset: in the desktop replay and in every interactive kind" {
  local kind revoked
  revoked=$(dt_unset_name)
  for kind in desktop zsh-i zsh-li bash-i bash-li zsh-i-nolang bash-i-nolang bash-li-nolang zsh-lc; do
    assert_equal "$(dt_kind_exported "$kind" "$revoked" "$revoked=$(dt_canary 4)")" 0
  done
}

# how many of the two names the shell that runs a snippet exports
count_snippet() {
  printf 'printf "@@%s=%%s\\n" "$(env | cut -d= -f1 | grep -cx -e %s -e %s)"' "$1" "$NAME_A" "$NAME_B"
}

@test "secrets load in an interactive zsh and an interactive bash exports both names to the shell and to a child, and holds none before" {
  local sh
  for sh in zsh bash; do
    assert_equal "$(dt_kind_run "$sh-i" "$(count_snippet B); secrets load; $(count_snippet N); sh -c '$(count_snippet C)'" | sed -n 's/^@@[BNC]=//p' | tr '\n' ' ')" '0 2 2 '
  done
}

@test "after secrets load a child interactive shell holds both names, and the opencode function removes them and the marker" {
  local out
  out=$(dt_kind_run zsh-i "$(count_snippet B); secrets load; zsh -i -c '$(count_snippet I)'; opencode x" | tr -d '\r')
  assert_equal "$(printf '%s\n' "$out" | sed -n 's/^@@B=//p')" 0
  assert_equal "$(printf '%s\n' "$out" | sed -n 's/^@@I=//p')" 2
  # the stub prints how many secret-named names it holds, first of its lines: the keys and the marker are gone
  assert_equal "$(printf '%s\n' "$out" | grep -x -B1 -e '--args--' | head -n 1)" 0
}

@test "secrets unload empties the shell again" {
  assert_equal "$(dt_kind_run bash-i "secrets load; $(count_snippet L); secrets unload; $(count_snippet U)" | sed -n 's/^@@[LU]=//p' | tr '\n' ' ')" '2 0 '
}
