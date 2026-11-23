#!/usr/bin/env bats
# The runner of the shell kinds (helpers/kinds.sh), proved on the scratch render before the environment tests rely on
# it: each kind starts the way the real one does (the environment it is handed, whether it is interactive and
# whether it is a login shell), the output is clean, and the counting helpers print numbers and no name.
# The environment a shell was started with is read from /proc/$$/environ, which startup files cannot change.

load ../helpers/bats/load

setup_file() {
  require_tool chezmoi
  RENDER_DEST=$(dt_render "$BATS_FILE_TMPDIR/render") || return 1
  export RENDER_DEST
}

setup() {
  dt_prepare_home "$BATS_TEST_TMPDIR/home" "$RENDER_DEST"
  require_shell zsh
  require_shell bash
}

# initial_env KIND: the names and values the shell of that kind was started with, one NAME=value per line,
# values of the public variables that the runner sets only
initial_env() {
  dt_kind_run "$1" 'tr "\0" "\n" < /proc/$$/environ | grep -E "^(PATH|LANG|SHELL|USER|LOGNAME|SSH_CLIENT|SHLVL|TERM)=" | sed "s/^/@@E /"' | sed -n 's/^@@E //p'
}

# value NAME: the value of NAME in the output of initial_env, read from the variable $started
value() {
  printf '%s\n' "$started" | sed -n "s/^$1=//p" | head -n 1
}

@test "the kinds: thirteen names, ten of them load the environment" {
  assert_equal "$(dt_kinds | wc -l)" 13
  assert_equal "$(dt_kinds_env | wc -l)" 10
  assert_equal "$(comm -13 <(dt_kinds | sort) <(dt_kinds_env | sort) | wc -l)" 0
  assert_equal "$(dt_kinds | grep -c -e '^desktop$' -e '^bash-ssh$')" 2
}

@test "the login PATH is what /etc/profile gives a login shell: directories only, no duplicate" {
  local p d
  p=$(dt_login_path)
  [ -n "$p" ] || fail "no login PATH"
  assert_equal "$(printf '%s\n' "$p" | tr ':' '\n' | sort | uniq -d | wc -l)" 0
  while IFS= read -r d; do
    [ -d "$d" ] || fail "an entry of the login PATH is not a directory"
  done < <(printf '%s\n' "$p" | tr ':' '\n')
}

@test "every kind is handed the login PATH, the session SHELL, USER and LOGNAME" {
  local kind user started
  user=$(id -un)
  for kind in $(dt_kinds); do
    started=$(initial_env "$kind")
    assert_equal "$(value PATH)" "$(dt_login_path)"
    assert_equal "$(value SHELL)" /usr/bin/zsh
    assert_equal "$(value USER)" "$user"
    assert_equal "$(value LOGNAME)" "$user"
  done
}

@test "the kinds started without LANG hold none, and every other kind holds the session LANG" {
  local kind started
  for kind in $(dt_kinds); do
    started=$(initial_env "$kind")
    case $kind in
      *-nolang) assert_equal "$(printf '%s\n' "$started" | grep -c '^LANG=')" 0 ;;
      *) assert_equal "$(value LANG)" "$(dt_kind_lang)" ;;
    esac
  done
}

@test "bash-ssh is started as sshd starts it: SSH_CLIENT set and a shell level of 0" {
  local started
  started=$(initial_env bash-ssh)
  assert_equal "$(printf '%s\n' "$started" | grep -c '^SSH_CLIENT=.')" 1
  assert_equal "$(value SHLVL)" 0
  assert_equal "$(initial_env zsh-i | grep -c '^SSH_CLIENT=')" 0
}

# flags KIND: "interactive login" as two 0 or 1
flags() {
  dt_kind_run "$1" 'case $- in *i*) i=1 ;; *) i=0 ;; esac; if [ -n "${ZSH_VERSION-}" ]; then if [[ -o login ]]; then l=1; else l=0; fi; else if shopt -q login_shell; then l=1; else l=0; fi; fi; echo "@@F=$i$l"' | sed -n 's/^@@F=//p' | tail -n 1
}

@test "each kind is interactive or not, and a login shell or not, as its name says" {
  assert_equal "$(flags desktop)" 00
  assert_equal "$(flags zsh-i)" 10
  assert_equal "$(flags zsh-li)" 11
  assert_equal "$(flags bash-i)" 10
  assert_equal "$(flags bash-li)" 11
  assert_equal "$(flags zsh-lc)" 01
  assert_equal "$(flags zsh-c)" 00
  assert_equal "$(flags bash-lc)" 01
  assert_equal "$(flags bash-c)" 00
  assert_equal "$(flags bash-ssh)" 00
  assert_equal "$(flags zsh-i-nolang)" 10
  assert_equal "$(flags bash-i-nolang)" 10
  assert_equal "$(flags bash-li-nolang)" 11
}

@test "the output of a kind under a pseudo-terminal holds no carriage return" {
  local out
  out=$(dt_kind_run zsh-i 'echo @@X=1')
  assert_equal "$(printf '%s' "$out" | tr -cd '\r' | wc -c)" 0
  assert_equal "$(printf '%s\n' "$out" | grep -c '^@@X=1$')" 1
}

@test "dt_kind_value prints the value of a variable, and <unset> for one that is not set" {
  assert_equal "$(dt_kind_value zsh-i HOME)" "$DT_HOME"
  assert_equal "$(dt_kind_value bash-c DT_NO_SUCH_VARIABLE)" '<unset>'
  assert_equal "$(dt_kind_value desktop DT_NO_SUCH_VARIABLE DT_NO_SUCH_VARIABLE=set)" set
}

@test "dt_kind_exported counts the names that a kind exports, and nothing else" {
  assert_equal "$(dt_kind_exported zsh-i HOME DT_NO_SUCH_VARIABLE)" 1
  assert_equal "$(dt_kind_exported bash-c DT_NO_SUCH_VARIABLE DT_NO_OTHER_VARIABLE)" 0
  assert_equal "$(dt_kind_exported desktop HOME DT_NO_SUCH_VARIABLE DT_NO_SUCH_VARIABLE=set)" 2
}

@test "dt_kind_debug_count counts the lines of the start that match a pattern" {
  assert_equal "$(dt_kind_debug_count bash-li '^profile:')" 1
  assert_equal "$(dt_kind_debug_count zsh-c '.')" 0
}

@test "dt_kind_locale_warnings counts the locale warnings of a child program, and a missing locale gives some" {
  local missing
  missing=$(dt_missing_locale)
  assert_equal "$(dt_kind_locale_warnings bash-c)" 0
  [ "$(dt_kind_locale_warnings bash-c LC_ALL="$missing")" -ge 1 ]
}
