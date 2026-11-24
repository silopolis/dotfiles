#!/usr/bin/env bats
# Proves the spec shell-environment, requirement "History under XDG state": real interactive zsh and bash on a scratch
# render and a scratch home that holds synthetic history files (multi-line zsh entries, plain bash lines). Counts, modes
# and link targets only: a history line is data of the fixture, never printed.

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
  STATE=$DT_HOME/.local/state
}

# the legacy file and the new file of a kind: the first words of the two paths, per shell
legacy() { printf '%s\n' "$DT_HOME/.${1%%-*}_history"; }
new_file() { printf '%s\n' "$STATE/${1%%-*}/history"; }

# start KIND: one start of an interactive shell of that kind; what it prints
start() { dt_kind_run "$1" true; }

# zsh_entries FILE: the entries (the lines that start one); zsh_stamps FILE: their timestamps, in file order
zsh_entries() { grep -c '^: [0-9][0-9]*:[0-9][0-9]*;' "$1" || true; }
zsh_stamps() { sed -n 's/^: \([0-9][0-9]*\):[0-9][0-9]*;.*/\1/p' "$1"; }

# is_link_to LINK TARGET
is_link_to() { [ -L "$1" ] && [ "$(readlink -f "$1")" = "$(readlink -f "$2")" ]; }

@test "paths: HISTFILE of an interactive zsh and of an interactive bash is under XDG_STATE_HOME" {
  assert_equal "$(dt_kind_value zsh-i HISTFILE)" "$STATE/zsh/history"
  assert_equal "$(dt_kind_value bash-i HISTFILE)" "$STATE/bash/history"
}

@test "first start moves the legacy file: zsh keeps every entry, mode 0600, directory 0700, a link at the old path" {
  local legacy new
  legacy=$(legacy zsh-i)
  new=$(new_file zsh-i)
  dt_write_zsh_history "$legacy"
  cp -p "$legacy" "$BATS_TEST_TMPDIR/original"
  assert_equal "$(start zsh-i)" ''
  assert_equal "$(zsh_entries "$new")" 5
  assert_equal "$(comm -23 <(sort "$BATS_TEST_TMPDIR/original") <(sort "$new") | wc -l)" 0
  assert_equal "$(stat -c %a "$new")" 600
  assert_equal "$(stat -c %a "$(dirname "$new")")" 700
  is_link_to "$legacy" "$new" || fail "the old path is not a link to the new file"
}

@test "first start moves the legacy file: bash keeps every line, mode 0600, directory 0700, a link at the old path" {
  local legacy new
  legacy=$(legacy bash-i)
  new=$(new_file bash-i)
  dt_write_bash_history "$legacy"
  cp -p "$legacy" "$BATS_TEST_TMPDIR/original"
  assert_equal "$(start bash-i)" ''
  assert_equal "$(cmp "$BATS_TEST_TMPDIR/original" "$new" && echo same)" same
  assert_equal "$(stat -c %a "$new")" 600
  assert_equal "$(stat -c %a "$(dirname "$new")")" 700
  is_link_to "$legacy" "$new" || fail "the old path is not a link to the new file"
}

# two shells of the same kind that start at the same moment, three times on a fresh legacy file each time
two_at_once() { # KIND WRITER
  local kind=$1 legacy new i out_a out_b
  legacy=$(legacy "$kind")
  new=$(new_file "$kind")
  for i in 1 2 3; do
    rm -rf -- "$STATE/${kind%%-*}" "$legacy"
    "$2" "$legacy"
    start "$kind" > "$BATS_TEST_TMPDIR/out-a" &
    start "$kind" > "$BATS_TEST_TMPDIR/out-b" &
    wait
    [ ! -s "$BATS_TEST_TMPDIR/out-a" ] && [ ! -s "$BATS_TEST_TMPDIR/out-b" ] || fail "a shell printed something (round $i)"
    [ -f "$new" ] && [ ! -L "$new" ] || fail "the new file is not a regular file (round $i)"
    is_link_to "$legacy" "$new" || fail "the old path is not a link (round $i)"
  done
}

@test "two shells at once: zsh prints nothing and the new file holds every entry once" {
  two_at_once zsh-i dt_write_zsh_history
  assert_equal "$(zsh_entries "$(new_file zsh-i)")" 5
  assert_equal "$(grep '^: ' "$(new_file zsh-i)" | sort | uniq -d | wc -l)" 0
}

@test "two shells at once: bash prints nothing and the new file holds every line once" {
  two_at_once bash-i dt_write_bash_history
  assert_equal "$(wc -l < "$(new_file bash-i)")" 4
}

@test "merge after a trim: zsh holds every entry of both files once, in timestamp order, mode 0600, and the link is back" {
  local legacy new
  legacy=$(legacy zsh-i)
  new=$(new_file zsh-i)
  dt_write_zsh_history "$legacy"
  start zsh-i > /dev/null
  # a running shell trimmed its history: the old path is a regular file again, with entries the new file lacks
  rm -f -- "$legacy"
  dt_write_zsh_history_extra "$legacy"
  assert_equal "$(start zsh-i)" ''
  assert_equal "$(zsh_entries "$new")" 9
  assert_equal "$(grep '^: ' "$new" | sort | uniq -d | wc -l)" 0
  zsh_stamps "$new" | sort -n -c || fail "the entries are not in timestamp order"
  assert_equal "$(stat -c %a "$new")" 600
  is_link_to "$legacy" "$new" || fail "the old path is not a link to the new file again"
}

@test "merge after a trim: bash keeps the new file's lines, then the legacy lines it lacks, a repeated command as often as typed" {
  local legacy new
  legacy=$(legacy bash-i)
  new=$(new_file bash-i)
  dt_write_bash_history "$legacy"
  start bash-i > /dev/null
  cp -p "$new" "$BATS_TEST_TMPDIR/first"
  rm -f -- "$legacy"
  dt_write_bash_history_extra "$legacy"
  cp -p "$legacy" "$BATS_TEST_TMPDIR/second"
  assert_equal "$(start bash-i)" ''
  assert_equal "$(wc -l < "$new")" 7
  assert_equal "$(head -n 4 "$new" | cmp - "$BATS_TEST_TMPDIR/first" && echo same)" same
  assert_equal "$(sort "$new" | uniq -c | sort -rn | head -n 1 | awk '{print $1}')" 3
  assert_equal "$(comm -23 <(sort "$BATS_TEST_TMPDIR/second") <(sort "$new") | wc -l)" 0
  assert_equal "$(stat -c %a "$new")" 600
  is_link_to "$legacy" "$new" || fail "the old path is not a link to the new file again"
}

@test "a shell that finds no legacy file and no new file creates the directory 0700 and fails on nothing" {
  assert_equal "$(start zsh-i)" ''
  assert_equal "$(start bash-i)" ''
  assert_equal "$(stat -c %a "$STATE/zsh")" 700
  assert_equal "$(stat -c %a "$STATE/bash")" 700
}
