#!/usr/bin/env bats
# bats file_tags=live
# The checks of the spec shell-environment that read this machine: opt-in (`DOTFILES_TEST_LIVE=1`, or
# `mise run test:live`) and read-only. They print counts and statuses, never the name or the value of a variable of
# the real environment: the names of the user's private file stay in memory and in a pipe.
# The two scenarios that only a new login can satisfy ("After the next login", "The live session holds no key") need a
# second opt-in, `DOTFILES_TEST_AFTER_LOGIN=1`: the deployment is done and the machine was rebooted (tests/README.md).
# They have no mutant: they prove the state of the session, not a file of the source.

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

# the probe of manual-steps.md is the one copy of the lines that read the umasks and the user manager (helpers/live.sh)
@test "after the next login the umask of the user manager, of plasmashell and of a new shell is 0027" {
  require_after_login
  local user out a7 a8 a9
  user=$(id -un)
  pgrep -u "$user" -x plasmashell > /dev/null || skip "plasmashell is not running in this session"
  out=$(USER=$user "$(type -P bash)" -c "$(dt_probe_lines 'A[789]')")
  a7=$(printf '%s\n' "$out" | sed -n 's/^A7 user manager umask: //p')
  a8=$(printf '%s\n' "$out" | sed -n 's/^A8 plasmashell umask: //p')
  a9=$(printf '%s\n' "$out" | sed -n 's/^A9 this shell umask: //p')
  echo "# umask: user manager $a7, plasmashell $a8, a new shell $a9" >&3
  assert_equal "$a7" 0027
  assert_equal "$a8" 0027
  assert_equal "$a9" 0027
}

@test "the live session holds no key: the user manager and the ancestors of the test hold none of the names of the private file" {
  require_after_login
  local config=${DOTFILES_TEST_REAL_CONFIG:-$DOTFILES_TEST_REAL_HOME/.config} a1 manager pid n checked=0 held=0
  [ -f "$config/env" ] || skip "the user environment file does not exist on this machine"
  export XDG_CONFIG_HOME=$config USER
  USER=$(id -un)
  # line A1 of the probe, and the definitions of names and um that it uses (the count goes to a file, never a name)
  eval "$(dt_probe_lines A1)" > "$BATS_TEST_TMPDIR/a1"
  [ "$(names | wc -l)" -gt 0 ] || skip "the user environment file sets no variable"
  [ "$(um | wc -l)" -gt 0 ] || skip "no systemd user manager answers in this session"
  a1=$(sed -n 's/^A1 private-file names in the user manager: //p' "$BATS_TEST_TMPDIR/a1")
  manager=$(dt_user_manager_pid)
  # the terminal and the multiplexer are ancestors of the test: the chain up to the user manager, not every process
  # (run it from a terminal where `secrets load` was not typed, as tests/README.md says: that terminal holds the keys on
  # purpose, and it is an ancestor of the run)
  while read -r pid; do
    n=$(dt_environ_name_count "$pid" <(names)) || continue
    checked=$((checked + 1))
    [ "$n" -eq 0 ] || held=$((held + 1))
  done < <(dt_process_ancestors "$$" "$manager")
  echo "# user manager: $a1 names; ancestors read: $checked, holding at least one name of the private file: $held" >&3
  [ "$checked" -ge 2 ] || fail "fewer than two ancestors could be read: the walk proves nothing"
  assert_equal "$a1" 0
  assert_equal "$held" 0
}
