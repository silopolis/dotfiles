#!/usr/bin/env bats
# Proves the spec shell-environment, requirement "Clean PATH", scenario "The helper": _path_prepend and _path_clean of
# rc.d/035-env_path_helper.sh, in zsh and in bash, and in a POSIX sh where one is installed (the file is sourced by both
# shells, so it is written for both). Every shell starts under env -i with a scratch home and the PATH of the test.

load ../helpers/bats/load

setup() {
  setup_scratch
  HELPER=$(dt_source_file dot_config/shell/rc.d/035-env_path_helper.sh)
  DA=$DT_HOME/a
  DB=$DT_HOME/b
  DC=$DT_HOME/c
  DD=$DT_HOME/d
  SPACED="$DT_HOME/with space"
  STAR="$DT_HOME/star*"
  GONE=$DT_HOME/missing
  mkdir -p "$DA" "$DB" "$DC" "$DD" "$SPACED" "$STAR"
}

# shells_to_try: zsh and bash (system builds), and dash as a POSIX sh when it is installed
shells_to_try() {
  local s
  for s in zsh bash; do
    dt_shell_path "$s" 2> /dev/null
  done
  type -P dash || true
}

# in_shell SHELL-PATH PATH SNIPPET: source the helper under env -i with that PATH, run the snippet, print its output
in_shell() {
  env -i HOME="$DT_HOME" LANG=C.UTF-8 PATH="$2" "$1" -c ". '$HELPER'; $3" < /dev/null 2>&1
}

# every_shell PATH SNIPPET EXPECTED: the snippet prints EXPECTED in each shell
every_shell() {
  local sh got n=0
  while IFS= read -r sh; do
    got=$(in_shell "$sh" "$1" "$2")
    [ "$got" = "$3" ] || fail "$(basename "$sh"): expected [$3] got [$got]"
    n=$((n + 1))
  done < <(shells_to_try)
  [ "$n" -ge 2 ] || fail "fewer than two shells were tried"
}

@test "sourcing the helper prints nothing and defines the two functions" {
  every_shell /usr/bin:/bin 'type _path_prepend > /dev/null && type _path_clean > /dev/null && echo defined' defined
}

@test "_path_prepend moves a directory that is on PATH to the front, skips a missing one, adds a new one at the front" {
  every_shell "$DA:$DB:$DC:/usr/bin" "_path_prepend '$DB'; _path_prepend '$GONE'; _path_prepend '$DD'; printf '%s\n' \"\$PATH\"" "$DD:$DB:$DA:$DC:/usr/bin"
}

@test "_path_prepend with several directories treats them as one call each, in order" {
  every_shell "$DA:/usr/bin" "_path_prepend '$DB' '$GONE' '$DC'; printf '%s\n' \"\$PATH\"" "$DC:$DB:$DA:/usr/bin"
}

@test "_path_prepend keeps a directory that is already first where it is, and does not duplicate it" {
  every_shell "$DA:$DB:/usr/bin" "_path_prepend '$DA'; _path_prepend '$DA'; printf '%s\n' \"\$PATH\"" "$DA:$DB:/usr/bin"
}

@test "_path_prepend removes every other occurrence of the directory and changes nothing else" {
  every_shell "$DA:$DB:$DA:$DC:$DA" "_path_prepend '$DA'; printf '%s\n' \"\$PATH\"" "$DA:$DB:$DC"
}

@test "_path_prepend handles a directory with a space and one with a glob character" {
  every_shell "$DA:/usr/bin" "_path_prepend '$SPACED'; _path_prepend '$STAR'; _path_prepend '$SPACED'; printf '%s\n' \"\$PATH\"" "$SPACED:$STAR:$DA:/usr/bin"
}

@test "_path_prepend exports PATH to child processes" {
  local sh got
  while IFS= read -r sh; do
    got=$(env -i HOME="$DT_HOME" PATH=/usr/bin:/bin "$sh" -c ". '$HELPER'; _path_prepend '$DA'; /usr/bin/env | grep '^PATH='" < /dev/null 2>&1)
    [ "$got" = "PATH=$DA:/usr/bin:/bin" ] || fail "$(basename "$sh"): the child sees [$got]"
  done < <(shells_to_try)
}

@test "_path_clean drops duplicates, missing directories and empty entries, and keeps the first occurrence in order" {
  every_shell "$DA:$DA:$GONE::$DB:$DA:/usr/bin:/usr/bin:" "_path_clean; printf '%s\n' \"\$PATH\"" "$DA:$DB:/usr/bin"
}

@test "_path_clean keeps the entries of a PATH that is already clean as they are, and is idempotent" {
  every_shell "$DA:$DB:$DC:/usr/bin:/bin" "_path_clean; _path_clean; printf '%s\n' \"\$PATH\"" "$DA:$DB:$DC:/usr/bin:/bin"
}

@test "_path_clean handles a directory with a space and one with a glob character, and a missing one that looks like a glob" {
  every_shell "$SPACED:$STAR:$SPACED:$DT_HOME/sta*:$STAR" "_path_clean; printf '%s\n' \"\$PATH\"" "$SPACED:$STAR"
}

@test "_path_clean exports PATH to child processes" {
  local sh got
  while IFS= read -r sh; do
    got=$(env -i HOME="$DT_HOME" PATH="$DA:$DA:/usr/bin:/bin" "$sh" -c ". '$HELPER'; _path_clean; /usr/bin/env | grep '^PATH='" < /dev/null 2>&1)
    [ "$got" = "PATH=$DA:/usr/bin:/bin" ] || fail "$(basename "$sh"): the child sees [$got]"
  done < <(shells_to_try)
}

@test "the functions leave no variable behind and work under set -u" {
  every_shell "$DA:/usr/bin" "set -u; _path_prepend '$DB'; _path_clean; set | grep -c '^_p[pc]_' ; printf '%s\n' \"\$PATH\"" "0
$DB:$DA:/usr/bin"
}

@test "sourcing the helper twice changes nothing" {
  every_shell "$DA:/usr/bin" ". '$HELPER'; _path_prepend '$DB'; . '$HELPER'; printf '%s\n' \"\$PATH\"" "$DB:$DA:/usr/bin"
}

@test "the helper file is POSIX: shellcheck -s sh accepts it" {
  require_tool shellcheck
  run "$DT_TOOL_SHELLCHECK" -s sh "$HELPER"
  assert_success
}
