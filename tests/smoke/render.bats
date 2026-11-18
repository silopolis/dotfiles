#!/usr/bin/env bats
# Proves the spec shell-test-harness, requirement "A scratch render uses a synthetic configuration" and the scenario
# "The scratch destination starts empty" of "Tests are isolated from the machine": the render that the startup tests
# start from is made of synthetic data only, leaves out what an external, a script or a secret would add, needs
# neither hostnamectl nor lscpu, and starts from a new destination below the scratch directory. Counts and modes
# only: no test prints the content of a file.

load ../helpers/bats/load

setup_file() {
  require_tool chezmoi
  RENDER_DIR=$BATS_FILE_TMPDIR/render
  RENDER_DEST=$(dt_render "$RENDER_DIR") || return 1
  export RENDER_DIR RENDER_DEST
}

# real_listing: one hash of what the isolation scenario lists in the real home (the listing is never printed)
real_listing() {
  local home
  home=$(dt_real_home)
  {
    ls -lR --time-style=full-iso "$home/.config/shell" "$home/.config/chezmoi" 2> /dev/null || true
    [ -e "$home/.parallel" ] && echo parallel-present || echo parallel-absent
  } | sha256sum
}

@test "the generated configuration holds four demo- identity values and no encryption or age key" {
  local conf=$RENDER_DIR/chezmoi.toml
  assert_equal "$(grep -c -E '^[[:space:]]*(email|gitemail|name|firstname) = ' "$conf")" 4
  assert_equal "$(grep -c -E '^[[:space:]]*(email|gitemail|name|firstname) = "demo-' "$conf")" 4
  assert_equal "$(grep -c -E '^[[:space:]]*\[?(data\.)?(encryption|age)[]=[:space:]]' "$conf" || true)" 0
}

@test "the render holds no external, no file written by a script and no encrypted file" {
  [ ! -e "$RENDER_DEST/.config/nvim" ]
  [ ! -e "$RENDER_DEST/.local/share/vsix" ]
  assert_equal "$(find "$RENDER_DEST" -name '*.age' | wc -l | tr -d ' ')" 0
}

@test "the render needs neither hostnamectl nor lscpu" {
  local bin=$BATS_TEST_TMPDIR/bin t p dest status=0
  mkdir -p "$bin"
  for t in mkdir chmod sed head cat env uname; do
    p=$(type -P "$t") || skip "$t is not installed"
    ln -s "$p" "$bin/$t"
  done
  dest=$(PATH=$bin dt_render "$BATS_TEST_TMPDIR/r") || status=$?
  assert_equal "$status" 0
  [ -d "$dest/.config/shell" ]
}

@test "the destination is a new directory of mode 0750 below the scratch directory and the real home is left alone" {
  local before after dest
  before=$(real_listing)
  dest=$(dt_render "$BATS_TEST_TMPDIR/r")
  after=$(real_listing)
  assert_equal "$before" "$after"
  case $dest in
    "$BATS_TEST_TMPDIR"/*) ;;
    *) fail "the destination is not below the scratch directory of the test" ;;
  esac
  assert_equal "$(stat -c %a "$dest")" 750
}

@test "a destination that exists makes the render fail, so it never starts from a used one" {
  mkdir -p "$BATS_TEST_TMPDIR/r/destination"
  run dt_render "$BATS_TEST_TMPDIR/r"
  assert_failure 2
}
