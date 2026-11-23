#!/usr/bin/env bats
# Proves the spec shell-environment, requirement "Clean PATH": real shells, the thirteen kinds of the study, started on a
# scratch render under env -i with the PATH that /etc/profile gives a login shell. A count of entries or a position is
# compared, never a value of the real environment: every directory is a system one or inside the scratch home.

load ../helpers/bats/load

setup_file() {
  require_tool chezmoi
  RENDER_DEST=$(dt_render "$BATS_FILE_TMPDIR/render") || return 1
  export RENDER_DEST
}

setup() {
  dt_prepare_home "$BATS_TEST_TMPDIR/home" "$RENDER_DEST"
  # the shims directory of mise exists on the machines this is written for: mise's activation puts it first, and a
  # scratch home without it would hold a missing directory that no startup file of ours added
  mkdir -p "$DT_HOME/.local/share/mise/shims"
  require_shell zsh
  require_shell bash
}

entries() { # PATH: one entry per line
  printf '%s\n' "$1" | tr ':' '\n'
}

# entries_without_mise PATH: the entries that are not in mise's data directory. The desktop replay loads no mise
# activation once the login loads the env_ files only (group 6); until then the full pass puts the shims first.
entries_without_mise() {
  entries "$1" | grep -v -F "$DT_HOME/.local/share/mise/" || true
}

# a PATH that is not clean: the login PATH, then a duplicate of a system directory and a directory that does not exist
dirty_path() {
  printf '%s:/usr/bin:%s\n' "$(dt_login_path)" "$DT_HOME/missing-dir"
}

@test "no duplicates and no missing directory in any kind that loads the environment, from an unclean PATH" {
  local kind p d
  for kind in $(dt_kinds_env); do
    p=$(dt_kind_path "$kind" PATH="$(dirty_path)")
    [ -n "$p" ] || fail "$kind: no PATH"
    [ "$(entries "$p" | sort | uniq -d | wc -l)" -eq 0 ] || fail "$kind: a duplicate in the PATH"
    while IFS= read -r d; do
      [ -d "$d" ] || fail "$kind: an entry of the PATH is not a directory"
    done < <(entries "$p")
  done
}

@test "inherited entries are kept: an interactive zsh and an interactive bash hold the inherited directory once" {
  local kind p inherited=$DT_HOME/inherited
  mkdir -p "$inherited"
  for kind in zsh-i bash-i; do
    p=$(dt_kind_path "$kind" PATH="$(dt_login_path):$inherited")
    assert_equal "$(entries "$p" | grep -c -x -F "$inherited")" 1
  done
}

@test "inherited entries are kept: the desktop replay keeps a directory that a file sorted before 040 adds" {
  local p inherited=$DT_HOME/inherited
  mkdir -p "$inherited"
  # a file named like an env_ file, sorted before 040: it adds the directory the way a parent's PATH would carry it
  printf 'PATH="$PATH:%s"\nexport PATH\n' "$inherited" > "$DT_HOME/.config/shell/rc.d/036-env_fixture_inherited.sh"
  p=$(dt_kind_path desktop)
  assert_equal "$(entries "$p" | grep -c -x -F "$inherited")" 1
}

@test "an inherited directory that does not exist is dropped, and one that does is kept, in an interactive zsh" {
  local p inherited=$DT_HOME/inherited
  mkdir -p "$inherited"
  p=$(dt_kind_path zsh-i PATH="$(dt_login_path):$DT_HOME/gone:$inherited")
  assert_equal "$(entries "$p" | grep -c -x -F "$DT_HOME/gone")" 0
  assert_equal "$(entries "$p" | grep -c -x -F "$inherited")" 1
}

@test "user bin directories come first in the desktop replay, before every brew and system directory" {
  local p d i first_user=-1 last_user=-1 first_other=-1 prefix idx=0 others
  mkdir -p "$DT_HOME/.local/bin" "$DT_HOME/.local/sbin"
  p=$(dt_kind_path desktop)
  prefix=$(dt_kind_value desktop HOMEBREW_PREFIX)
  others=(/usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/local/games /usr/games)
  if [ "$prefix" != '<unset>' ]; then
    others+=("$prefix/bin" "$prefix/sbin")
  fi
  while IFS= read -r d; do
    for i in "$DT_HOME/.local/bin" "$DT_HOME/.local/sbin"; do
      if [ "$d" = "$i" ]; then
        [ "$first_user" -ge 0 ] || first_user=$idx
        last_user=$idx
      fi
    done
    for i in "${others[@]}"; do
      if [ "$d" = "$i" ] && [ "$first_other" -lt 0 ]; then
        first_other=$idx
      fi
    done
    idx=$((idx + 1))
  done < <(entries_without_mise "$p")
  assert_equal "$first_user" 0
  [ "$last_user" -ge 1 ] || fail "only one of the two user directories is on PATH"
  [ "$last_user" -lt "$first_other" ] || fail "a user bin directory comes after a brew or system directory"
}

@test "user bin directories come before the system directories in an interactive zsh too, mise's directories aside" {
  local p user system
  mkdir -p "$DT_HOME/.local/bin"
  p=$(dt_kind_path zsh-i)
  user=$(entries "$p" | grep -n -x -F "$DT_HOME/.local/bin" | cut -d: -f1)
  system=$(entries "$p" | grep -n -x -F /usr/bin | cut -d: -f1)
  [ -n "$user" ] && [ -n "$system" ] || fail "a directory is not on PATH"
  [ "$user" -lt "$system" ]
}

# three shells inside each other: each prints its PATH and its AQUA_BIN_DIR, then starts the next
chain() { # FIRST-KIND NEXT-SHELL-PATH
  local snip
  snip='n=${DT_LEVEL:-1}; printf "@@P%s=%s\n@@Q%s=%s\n" "$n" "$PATH" "$n" "${AQUA_BIN_DIR-<unset>}"; if [ "$n" -lt 3 ]; then DT_LEVEL=$((n + 1)) '"$2"' -i -c "$DT_SNIP"; fi'
  dt_kind_run "$1" "$snip" DT_SNIP="$snip"
}

check_chain() { # OUTPUT: the three PATH values and the three AQUA_BIN_DIR values are the same
  local out=$1 i
  for i in 1 2 3; do
    [ "$(printf '%s\n' "$out" | grep -c "^@@P$i=")" -eq 1 ] || fail "level $i printed no PATH"
  done
  assert_equal "$(printf '%s\n' "$out" | sed -n 's/^@@P[123]=//p' | sort -u | wc -l)" 1
  assert_equal "$(printf '%s\n' "$out" | sed -n 's/^@@Q[123]=//p' | sort -u | wc -l)" 1
}

@test "nested shells do not grow PATH or AQUA_BIN_DIR: zsh in zsh in zsh" {
  check_chain "$(chain zsh-i "$(dt_shell_path zsh)")"
}

@test "nested shells do not grow PATH or AQUA_BIN_DIR: bash in bash in bash" {
  check_chain "$(chain bash-i "$(dt_shell_path bash)")"
}

@test "nested shells do not grow PATH or AQUA_BIN_DIR: interactive zsh in interactive zsh, started from the desktop replay" {
  check_chain "$(chain desktop "$(dt_shell_path zsh)")"
}

@test "a nested shell of the same kind has the PATH of the first, entry by entry" {
  local out
  out=$(chain zsh-i "$(dt_shell_path zsh)")
  assert_equal "$(printf '%s\n' "$out" | sed -n 's/^@@P1=//p' | tr ':' '\n' | wc -l)" "$(printf '%s\n' "$out" | sed -n 's/^@@P3=//p' | tr ':' '\n' | wc -l)"
}

@test "the brew hook of 110 is still defined in an interactive zsh" {
  [ -f /home/linuxbrew/.linuxbrew/etc/brew-wrap ] || skip "brew-file is not installed"
  [ -x /home/linuxbrew/.linuxbrew/bin/brew-file ] || skip "brew-file is not installed"
  assert_equal "$(dt_kind_run zsh-i 'whence -w _post_brewfile_update' | tail -n 1)" '_post_brewfile_update: function'
}
