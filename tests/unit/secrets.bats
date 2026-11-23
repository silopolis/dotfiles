#!/usr/bin/env bats
# Proves the spec shell-environment, requirements "Keys on demand" and "No key in a new shell", on
# rc.d/446-tools_secrets.sh alone, in zsh and in bash: `secrets load` exports the variables of the private file into the
# calling shell and its children and sets the marker, `secrets unload` unsets them, `secrets` alone prints a count,
# a new interactive shell drops the copies it inherited unless the marker says a parent loaded them on purpose.
# The private file is synthetic (two DEMO_ names, built at run time); no output holds a name or a value of it.
# Each shell is started with -i, because the file does nothing in a shell that is not interactive.

load ../helpers/bats/load

setup() {
  setup_scratch
  FILE=$(dt_source_file dot_config/shell/rc.d/446-tools_secrets.sh)
  BIN=$BATS_TEST_TMPDIR/bin
  dt_realbin "$BIN"
  mkdir -p "$DT_HOME/.config"
  dt_write_private_env "$DT_HOME/.config/env"
  chmod 0600 "$DT_HOME/.config/env"
  NAME_A=$(dt_alpha_name)
  NAME_B=$(dt_beta_name)
  # how many of the two names a shell holds in its own environment, and a child shell of it
  COUNT="env | cut -d= -f1 | grep -cx -e $NAME_A -e $NAME_B"
  CHILD="sh -c '$COUNT'"
}

# ish SHELL SCRIPT [VAR=value ...]: an interactive shell under env -i sources the file and runs the script; its
# standard output only (bash says on standard error that it has no terminal)
ish() {
  local sh=$1 script=$2
  shift 2
  env -i HOME="$DT_HOME" PATH="$BIN" LANG=C.UTF-8 TERM=dumb "$@" "$(dt_shell_path "$sh")" -i -c ". '$FILE'; $script" < /dev/null 2> /dev/null || true
}

# the same with standard error merged, minus the lines that bash itself prints for a shell without a terminal
ishe() {
  local sh=$1 script=$2
  shift 2
  env -i HOME="$DT_HOME" PATH="$BIN" LANG=C.UTF-8 TERM=dumb "$@" "$(dt_shell_path "$sh")" -i -c ". '$FILE'; $script" < /dev/null 2>&1 \
    | grep -v -e 'cannot set terminal process group' -e 'no job control' || true
}

every_shell() { # SCRIPT EXPECTED [VAR=value ...]
  local sh got script=$1 want=$2
  shift 2
  for sh in zsh bash; do
    got=$(ish "$sh" "$script" "$@")
    [ "$got" = "$want" ] || fail "$sh: expected [$want] got [$got]"
  done
}

@test "secrets load exports the variables of the private file into the calling shell and its children, and sets the marker" {
  every_shell "secrets load; $COUNT; $CHILD; echo \"\${DOTFILES_SECRETS-unset}\"; sh -c 'echo \"\${DOTFILES_SECRETS-unset}\"'" "2
2
loaded
loaded"
}

@test "a new interactive shell started next to the loading shell, not from it, holds none" {
  every_shell "$COUNT" 0
}

@test "a child shell started from the loading shell keeps what its parent loaded" {
  local sh inner
  for sh in zsh bash; do
    inner="$(dt_shell_path "$sh") -i -c \". '$FILE'; $COUNT\""
    got=$(ish "$sh" "secrets load; $inner 2> /dev/null")
    [ "$got" = 2 ] || fail "$sh: the inner shell counted [$got]"
  done
}

@test "a new interactive shell drops the copies it inherited when the marker is not set" {
  every_shell "$COUNT" 0 "$NAME_A=held" "$NAME_B=held"
}

@test "a new interactive shell keeps the copies it inherited when the marker is set" {
  every_shell "$COUNT" 2 "$NAME_A=held" "$NAME_B=held" DOTFILES_SECRETS=loaded
}

@test "the inherited names are read from the file: a name that the file does not set stays" {
  every_shell "$COUNT; echo \"\${DEMO_OTHER-unset}\"" "0
held" "$NAME_A=held" "$NAME_B=held" DEMO_OTHER=held
}

@test "secrets alone prints how many names of the file are set, and nothing else" {
  every_shell "secrets; secrets load; secrets; secrets unload; secrets" "0
2
0"
}

@test "secrets unload unsets every name of the file and the marker, in the shell and for its children" {
  every_shell "secrets load; $COUNT; secrets unload; $COUNT; $CHILD; echo \"\${DOTFILES_SECRETS-unset}\"" "2
0
0
unset"
}

@test "no output of secrets holds a name of the file or a value" {
  local sh out
  for sh in zsh bash; do
    out=$(ishe "$sh" 'secrets; secrets load; secrets; secrets unload; secrets')
    [ "$(printf '%s\n' "$out" | tr '\n' ' ')" = '0 2 0 ' ] || fail "$sh: the output is not the three counts"
    [ "$(printf '%s\n' "$out" | grep -c -F -e "$NAME_A" -e "$NAME_B" -e demo-one -e demo-two || true)" -eq 0 ] || fail "$sh: a name or a value in the output"
  done
}

@test "without a private file secrets load prints one line, returns 1 and sets nothing" {
  local sh out status
  rm -f "$DT_HOME/.config/env"
  for sh in zsh bash; do
    out=$(ishe "$sh" 'secrets load; echo "status=$?"; echo "marker=${DOTFILES_SECRETS-unset}"')
    [ "$(printf '%s\n' "$out" | wc -l)" -eq 3 ] || fail "$sh: not one line plus the two probes: [$out]"
    [ "$(printf '%s\n' "$out" | sed -n 2p)" = 'status=1' ] || fail "$sh: status [$(printf '%s\n' "$out" | sed -n 2p)]"
    [ "$(printf '%s\n' "$out" | sed -n 3p)" = 'marker=unset' ] || fail "$sh: the marker was set"
    status=$(ish "$sh" 'secrets')
    [ "$status" = 0 ] || fail "$sh: secrets alone printed [$status] without a file"
  done
}

@test "secrets with an unknown word prints a usage line on standard error and returns 2" {
  local sh out
  for sh in zsh bash; do
    out=$(ishe "$sh" 'secrets nonsense; echo "status=$?"')
    [ "$(printf '%s\n' "$out" | sed -n 2p)" = 'status=2' ] || fail "$sh: [$out]"
    [ "$(printf '%s\n' "$out" | sed -n 1p | grep -c secrets)" -eq 1 ] || fail "$sh: no usage line"
  done
}

@test "values with spaces, quotes, a dollar sign and several lines survive a load, and assignments without export are exported" {
  local sh got name_c=DEMO_PLAIN_ONE name_d=DEMO_PLAIN_TWO
  printf '%s\n' "export $NAME_A='two words and \"quotes\" and \$dollar'" \
    "$name_c=bare" \
    "  export $name_d='first line" \
    "second line'" \
    "# a comment" \
    "" > "$DT_HOME/.config/env"
  for sh in zsh bash; do
    got=$(ish "$sh" "secrets load; secrets; sh -c 'printf \"%s|%s|%s\n\" \"\$$NAME_A\" \"\$$name_c\" \"\$$name_d\"' | tr '\n' '~'")
    [ "$got" = "3
two words and \"quotes\" and \$dollar|bare|first line~second line~" ] || fail "$sh: [$got]"
  done
}

@test "a second secrets load changes nothing, and unload then load works again" {
  every_shell "secrets load; secrets load; secrets; secrets unload; secrets; secrets load; secrets" "2
0
2"
}

@test "the file follows XDG_CONFIG_HOME" {
  mkdir -p "$DT_HOME/elsewhere"
  mv "$DT_HOME/.config/env" "$DT_HOME/elsewhere/env"
  every_shell "secrets load; secrets" 2 XDG_CONFIG_HOME="$DT_HOME/elsewhere"
}

@test "in a shell that is not interactive the file defines nothing and drops nothing" {
  local sh got
  for sh in zsh bash; do
    got=$(env -i HOME="$DT_HOME" PATH="$BIN" "$NAME_A=held" "$(dt_shell_path "$sh")" -c ". '$FILE'; $COUNT; type secrets > /dev/null 2>&1 && echo defined || echo undefined" < /dev/null 2>&1)
    [ "$got" = "1
undefined" ] || fail "$sh: [$got]"
  done
}

@test "an interactive shell defines secrets and prints nothing when the file is sourced" {
  local sh
  for sh in zsh bash; do
    [ "$(ishe "$sh" 'type secrets > /dev/null 2>&1 && echo defined')" = defined ] || fail "$sh: secrets is not defined"
    [ -z "$(ishe "$sh" true)" ] || fail "$sh: sourcing the file printed something"
  done
}

@test "without a private file sourcing the file drops nothing and prints nothing" {
  rm -f "$DT_HOME/.config/env"
  every_shell "$COUNT" 1 "$NAME_A=held"
}

@test "the marker has a secret-pattern name, so the opencode function removes it with the keys" {
  [[ DOTFILES_SECRETS =~ $DT_SECRET_PATTERN ]]
}

@test "no name of a variable is written in 446 or in 010: no DEMO_ name and no assignment of a key variable" {
  local f
  for f in 446-tools_secrets.sh 010-env_user.sh; do
    assert_equal "$(grep -c -E 'DEMO_|_KEY=|_TOKEN=' "$(dt_source_file "dot_config/shell/rc.d/$f")" || true)" 0
  done
}

@test "the file is POSIX: shellcheck -s sh accepts it, and zsh -n and bash -n parse it" {
  require_tool shellcheck
  run "$DT_TOOL_SHELLCHECK" -s sh "$FILE"
  assert_success
  zsh -n "$FILE"
  bash -n "$FILE"
}
