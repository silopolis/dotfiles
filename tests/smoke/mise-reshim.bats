#!/usr/bin/env bats
# Proves the shim cleanup of the spec install-scripts with the real mise binary, in a sandbox of scratch directories:
# a scratch home, a scratch data directory with a fake installed tool, offline, no configuration. `mise reshim` adds the
# missing shims, removes the mise-owned shims that no installed tool provides any more, and leaves every other file alone.
# Each test builds its own sandbox and runs the reshim once (twice for the last one).

load ../helpers/bats/load

setup() {
  require_tool mise
  MISE=$(readlink -f "$DT_TOOL_MISE")
  S=$BATS_TEST_TMPDIR/sandbox
  mkdir -p "$S/userhome/.config" "$S/userhome/.cache" "$S/userhome/.local/state" "$S/data/installs/node/22.0.0/bin" "$S/data/shims" "$S/work"
  local x
  for x in node npm; do
    printf '#!/bin/sh\necho fake %s\n' "$x" > "$S/data/installs/node/22.0.0/bin/$x"
    chmod 755 "$S/data/installs/node/22.0.0/bin/$x"
  done
  ln -s "$MISE" "$S/data/shims/ghost"
  ln -s "$MISE" "$S/data/shims/npm"
  printf 'not a shim\n' > "$S/data/shims/README.user"
}

# reshim: the real mise reshim, under env -i, offline, with every directory of mise in the sandbox
reshim() {
  (cd "$S/work" && env -i HOME="$S/userhome" PATH=/usr/bin:/bin XDG_CONFIG_HOME="$S/userhome/.config" XDG_CACHE_HOME="$S/userhome/.cache" \
    XDG_STATE_HOME="$S/userhome/.local/state" XDG_DATA_HOME="$S/userhome/.local/share" MISE_DATA_DIR="$S/data" \
    MISE_CACHE_DIR="$S/userhome/.cache/mise" MISE_STATE_DIR="$S/userhome/.local/state/mise" MISE_CONFIG_DIR="$S/userhome/.config/mise" \
    MISE_NO_CONFIG=1 MISE_OFFLINE=1 "$MISE" reshim < /dev/null > "$S/out.txt" 2>&1)
}

listing() {
  find "$S/data/shims" -maxdepth 1 -mindepth 1 -printf '%f %y\n' | sort | tr '\n' ';'
}

@test "reshim exits 0" {
  run reshim
  assert_success
}

@test "a stale mise-owned shim is removed" {
  reshim
  [ ! -e "$S/data/shims/ghost" ] && [ ! -L "$S/data/shims/ghost" ]
}

@test "a missing shim is added" {
  reshim
  [ -L "$S/data/shims/node" ]
}

@test "a current shim is kept" {
  reshim
  [ -L "$S/data/shims/npm" ]
}

@test "a file that is not a shim is left alone" {
  reshim
  [ -f "$S/data/shims/README.user" ] && [ ! -L "$S/data/shims/README.user" ]
}

@test "an installed tool is untouched" {
  reshim
  [ -x "$S/data/installs/node/22.0.0/bin/node" ]
}

@test "a second reshim changes nothing" {
  local before after
  reshim
  before=$(listing)
  reshim
  after=$(listing)
  assert_equal "$after" "$before"
}
