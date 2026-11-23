#!/usr/bin/env bats
# The synthetic fixtures of the shell-environment tests, made at run time: shell history files in the formats
# that zsh and bash write, with multi-line entries and a second file of extra entries, and a locale name that no
# machine generates. A fixture is data for the history and locale tests, so it is checked on its own here.

load ../helpers/bats/load

setup() {
  setup_scratch
}

# entries of an extended-format zsh history file: the lines that start an entry
zsh_entries() {
  grep -c '^: [0-9][0-9]*:[0-9][0-9]*;' "$1"
}

@test "the zsh history fixture holds extended entries, two of them on several lines, with mode 0600" {
  local f=$BATS_TEST_TMPDIR/zsh_history
  dt_write_zsh_history "$f"
  assert_equal "$(zsh_entries "$f")" 5
  assert_equal "$(grep -c '\\$' "$f")" 3
  assert_equal "$(stat -c %a "$f")" 600
}

@test "the second zsh history fixture shares one entry with the first, adds four, and interleaves the timestamps" {
  local a=$BATS_TEST_TMPDIR/zsh_a b=$BATS_TEST_TMPDIR/zsh_b
  dt_write_zsh_history "$a"
  dt_write_zsh_history_extra "$b"
  assert_equal "$(zsh_entries "$b")" 5
  # the entry lines that both files hold: exactly one
  assert_equal "$(comm -12 <(grep '^: ' "$a" | sort) <(grep '^: ' "$b" | sort) | wc -l)" 1
  # a timestamp of the second file lies between two timestamps of the first
  assert_equal "$(grep -c '^: 1700000150:' "$b")" 1
  assert_equal "$(stat -c %a "$b")" 600
}

@test "the bash history fixture holds plain lines with one repeated command, with mode 0600" {
  local f=$BATS_TEST_TMPDIR/bash_history
  dt_write_bash_history "$f"
  assert_equal "$(wc -l < "$f")" 4
  assert_equal "$(sort "$f" | uniq -d | wc -l)" 1
  assert_equal "$(grep -c '^#' "$f")" 0
  assert_equal "$(stat -c %a "$f")" 600
}

@test "the second bash history fixture repeats a command more often than the first and adds two lines" {
  local a=$BATS_TEST_TMPDIR/bash_a b=$BATS_TEST_TMPDIR/bash_b
  dt_write_bash_history "$a"
  dt_write_bash_history_extra "$b"
  assert_equal "$(wc -l < "$b")" 5
  assert_equal "$(sort "$b" | uniq -c | sort -rn | head -n 1 | awk '{print $1}')" 3
  assert_equal "$(comm -13 <(sort -u "$a") <(sort -u "$b") | wc -l)" 2
}

@test "the missing locale is one that locale -a does not list" {
  local name
  name=$(dt_missing_locale)
  [[ $name =~ ^[a-z]{2}_[A-Z]{2}\.UTF-8$ ]] || fail "the missing locale has an unexpected form"
  run dt_locale_generated "$name"
  assert_failure
}

@test "dt_locale_generated compares names without case and without the hyphen" {
  local have
  have=$(locale -a 2> /dev/null | grep -i -m 1 '^c\.utf-\?8$') || skip "no C.UTF-8 locale on this machine"
  run dt_locale_generated C.UTF-8
  assert_success
  run dt_locale_generated "${have^^}"
  assert_success
}

# the committed tests hold no secret-looking DEMO_ name: those are built at run time from parts
@test "no file of the suite holds a secret-looking DEMO_ name" {
  local pat='DEMO_[A-Z_]*('"KEY|TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL"')'
  run grep -rEn --exclude-dir=.lib --exclude-dir=.reports -e "$pat" "$DT_TESTS_DIR"
  assert_failure 1
  assert_output ''
}
