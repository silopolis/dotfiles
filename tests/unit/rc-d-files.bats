#!/usr/bin/env bats
# Proves the spec shell-environment, requirements "Highlighting loads last" and "Dead startup files are removed", on the
# source state: the last rc.d file in name order is the one that sources zsh-syntax-highlighting, and every target that the
# change removes or renames (the dead stubs, the old names of the env_ files and of the highlighting file, and the two
# rc files that only the old non-interactive branch of profile called) is absent from `chezmoi managed` and listed in
# home/.chezmoiremove.

load ../helpers/bats/load

# the targets that the change removes or renames, relative to the home
REMOVED=(
  .config/shell/rc.d/005-dbg_prof_enable.sh
  .config/shell/rc.d/995-dbg_prof_results.sh
  .config/shell/rc.d/130-pkg-flatpack.sh
  .config/shell/rc.d/200-lang_python.sh
  .config/shell/rc.d/930-highlighting.sh
  .config/shell/rc.d/120-pkg-aqua.sh
  .config/shell/rc.d/140-pkg_snap.sh
  .config/shell/rc.d/150-pkg_krew.sh
  .config/shell/rc.d/200-lang_go.sh
  .config/shell/rc.d/220-lang_rust.sh
  .config/zsh/zshrc
  .config/bash/bashrc
)

setup() {
  RC_D=$(dt_source_file dot_config/shell/rc.d)
}

@test "the last rc.d file in name order is the one that sources zsh-syntax-highlighting, and no other file does" {
  local last
  last=$(ls "$RC_D" | tail -n 1)
  assert_equal "$(grep -c -E '^[[:space:]]*source .*zsh-syntax-highlighting\.zsh' "$RC_D/$last" || true)" 1
  assert_equal "$(grep -l -E '^[[:space:]]*(source|\.) .*zsh-syntax-highlighting\.zsh' "$RC_D"/*.sh | wc -l)" 1
}

@test "no removed or renamed target is managed, and chezmoi managed lists the files that stay" {
  require_tool chezmoi
  local cfg=$BATS_TEST_TMPDIR/chezmoi.toml dest=$BATS_TEST_TMPDIR/dest managed t
  mkdir -p "$dest"
  dt_render_config "$cfg"
  managed=$(env -i PATH="$PATH" HOME="$BATS_TEST_TMPDIR" LANG=C.UTF-8 "$DT_TOOL_CHEZMOI" -S "$DOTFILES_TEST_SOURCE" --config "$cfg" --destination "$dest" --no-tty --no-pager managed --include=files --path-style=absolute < /dev/null)
  # the search is not vacuous: files that stay are listed
  [ "$(printf '%s\n' "$managed" | grep -c -x -F -e "$dest/.config/shell/profile" -e "$dest/.config/shell/rc.d/999-highlighting.sh" -e "$dest/.config/zsh/zsh_prompt")" -eq 3 ] || fail "chezmoi managed does not list the files that stay"
  for t in "${REMOVED[@]}"; do
    [ "$(printf '%s\n' "$managed" | grep -c -x -F "$dest/$t" || true)" -eq 0 ] || fail "a removed target is still managed: $t"
  done
}

@test "every removed or renamed target is listed in home/.chezmoiremove" {
  local list t
  list=$(dt_source_file .chezmoiremove)
  for t in "${REMOVED[@]}"; do
    [ "$(grep -c -x -F -- "$t" "$list" || true)" -eq 1 ] || fail "a removed target is not listed once in .chezmoiremove: $t"
  done
}

@test "the renamed and removed files are absent from the source state" {
  local t
  for t in "${REMOVED[@]}"; do
    [ ! -e "$(dt_source_file "dot_${t#.}")" ] || fail "the source still holds $t"
  done
}
