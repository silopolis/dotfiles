#!/usr/bin/env bats
# Proves the requirement "A development command starts the development checkout with its own application name"
# of the spec neovim-config on home/dot_local/bin/executable_nvim-dev (the change manage-nvim-dev-command).
#
# The script runs under `env -i` in a scratch home, with a stub `nvim` first on PATH that records NVIM_APPNAME and
# its arguments, one per line, and exits with the status it is given. No real Neovim starts and nothing outside the
# scratch directory is read or written; the profile is a symlink to a scratch directory, as the real one is a
# symlink to the development checkout. Only synthetic values are used.

load ../helpers/bats/load

bats_require_minimum_version 1.5.0

setup() {
  setup_scratch
  work=$BATS_TEST_TMPDIR/work
  mkdir -p "$work/bin" "$work/checkout" "$work/xdg"
  NVD=$(dt_source_file dot_local/bin/executable_nvim-dev)
  cat > "$work/bin/nvim" << 'EOF'
#!/bin/sh
echo call >> "$STUB_CALLS"
{
  printf 'appname=%s\n' "${NVIM_APPNAME-unset}"
  n=0
  for a in "$@"; do
    n=$((n + 1))
    printf 'arg[%s]=<%s>\n' "$n" "$a"
  done
} > "$STUB_LOG"
exit "${STUB_STATUS:-0}"
EOF
  chmod 0755 "$work/bin/nvim"
  PROFILE=$DT_HOME/.config/nvim-dev
}

# profile_here: the profile of the default place, a symlink to a scratch directory
profile_here() {
  mkdir -p "$DT_HOME/.config"
  ln -s "$work/checkout" "$PROFILE"
}

# nv [VAR=value ...] -- [ARGS...]: the script runs through NV_INTERP (default sh) under env -i, the stub first on PATH
nv() {
  local vars=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do
    vars+=("$1")
    shift
  done
  shift
  DT_PATH=$work/bin:/usr/bin:/bin dt_clean STUB_LOG="$work/stub.log" STUB_CALLS="$work/calls.log" "${vars[@]}" -- \
    "${NV_INTERP:-/bin/sh}" "$NVD" "$@"
}

# started_with ARG...: the stub was called once, with the development application name and exactly these arguments
started_with() {
  local expected n=0 a
  expected=$(printf 'appname=nvim-dev\n')
  for a in "$@"; do
    n=$((n + 1))
    expected+=$(printf '\narg[%s]=<%s>' "$n" "$a")
  done
  assert_equal "$(wc -l < "$work/calls.log")" 1
  assert_equal "$(cat "$work/stub.log")" "$expected"
}

@test "starts nvim with NVIM_APPNAME=nvim-dev and the arguments unchanged" {
  profile_here
  run nv NVIM_APPNAME=other -- a "b c"
  assert_success
  assert_output ""
  started_with a "b c"
}

@test "an empty argument, a glob, quotes, a dollar sign, a dash and a double dash come back as they are" {
  profile_here
  run nv -- '' '*' "it's" '"q"' '$HOME' -u -- 'a b'
  assert_success
  started_with '' '*' "it's" '"q"' '$HOME' -u -- 'a b'
}

@test "no argument starts nvim with none" {
  profile_here
  run nv --
  assert_success
  started_with
}

@test "the exit status of nvim is the exit status of the command" {
  profile_here
  run nv STUB_STATUS=7 -- x
  assert_failure 7
  started_with x
}

@test "the profile is looked up below XDG_CONFIG_HOME when it is set" {
  mkdir -p "$work/xdg"
  ln -s "$work/checkout" "$work/xdg/nvim-dev"
  run nv XDG_CONFIG_HOME="$work/xdg" -- x
  assert_success
  started_with x
}

@test "XDG_CONFIG_HOME set, the profile only in the default place: refused, the path below XDG_CONFIG_HOME named" {
  profile_here
  run --separate-stderr nv XDG_CONFIG_HOME="$work/xdg" -- x
  assert_failure 1
  assert_equal "$output" ""
  case $stderr in
    *"$work/xdg/nvim-dev"*) ;;
    *) fail "standard error does not name the path below XDG_CONFIG_HOME: $stderr" ;;
  esac
  assert_not_exist "$work/calls.log"
}

@test "a missing profile is refused: the path on standard error, status 1, nothing started, nothing created" {
  run --separate-stderr nv -- x
  assert_failure 1
  assert_equal "$output" ""
  case $stderr in
    *"$PROFILE"*) ;;
    *) fail "standard error does not name the profile path: $stderr" ;;
  esac
  assert_not_exist "$work/calls.log"
  assert_equal "$(find "$DT_HOME" -mindepth 1 | wc -l)" 0
}

@test "a profile that is a symlink to nothing is refused like a missing one" {
  mkdir -p "$DT_HOME/.config"
  ln -s "$work/gone" "$PROFILE"
  run --separate-stderr nv -- x
  assert_failure 1
  assert_equal "$output" ""
  case $stderr in
    *"$PROFILE"*) ;;
    *) fail "standard error does not name the profile path: $stderr" ;;
  esac
  assert_not_exist "$work/calls.log"
  assert_equal "$(find "$DT_HOME" -mindepth 1 -not -path "$DT_HOME/.config" -not -path "$PROFILE" | wc -l)" 0
}

@test "runs under sh" {
  profile_here
  NV_INTERP=/bin/sh run nv -- a "b c"
  assert_success
  started_with a "b c"
}

@test "runs under dash" {
  require_tool dash
  profile_here
  NV_INTERP=$DT_TOOL_DASH run nv -- a "b c"
  assert_success
  started_with a "b c"
}

@test "runs under bash" {
  profile_here
  NV_INTERP=$(command -v bash) run nv -- a "b c"
  assert_success
  started_with a "b c"
}

@test "runs as a program found on PATH, with no alias and no shell startup file" {
  profile_here
  install -m 0755 "$NVD" "$work/bin/nvim-dev"
  run env -i PATH="$work/bin:/usr/bin:/bin" HOME="$DT_HOME" STUB_LOG="$work/stub.log" STUB_CALLS="$work/calls.log" nvim-dev a "b c"
  assert_success
  started_with a "b c"
}

@test "the first line is #!/bin/sh and the file passes dash -n and bash -n" {
  assert_equal "$(head -n 1 "$NVD")" '#!/bin/sh'
  run bash -n "$NVD"
  assert_success
  if command -v dash > /dev/null 2>&1; then
    run dash -n "$NVD"
    assert_success
  fi
}

@test "shellcheck -s sh accepts the file" {
  require_tool shellcheck
  run "$DT_TOOL_SHELLCHECK" -s sh "$NVD"
  assert_success
  assert_output ""
}

@test "the file holds no home directory path and no e-mail address" {
  run -1 grep -n -E '/home/|/Users/|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$NVD"
  assert_output ""
}

@test "chezmoi manages it as an executable file at .local/bin/nvim-dev with the content of the source" {
  require_tool chezmoi jq
  dt_render_config "$work/chezmoi.toml"
  mkdir -p "$work/dest" "$work/state" "$work/cache"
  run --separate-stderr env -i PATH="/usr/bin:/bin" HOME="$DT_HOME" "$DT_TOOL_CHEZMOI" -S "$DOTFILES_TEST_SOURCE" \
    --config "$work/chezmoi.toml" --persistent-state "$work/state/chezmoistate.boltdb" --cache "$work/cache" \
    --destination "$work/dest" --no-tty --no-pager dump --format=json --include=files "$work/dest/.local/bin/nvim-dev"
  assert_success
  entry=$(printf '%s' "$output" | "$DT_TOOL_JQ" -c '.[".local/bin/nvim-dev"]')
  assert_equal "$(printf '%s' "$entry" | "$DT_TOOL_JQ" -r '.type')" file
  # the owner's executable bit (0100) of the mode that chezmoi would give the file
  assert_equal "$(printf '%s' "$entry" | "$DT_TOOL_JQ" -r '(.perm / 64 | floor) % 2')" 1
  printf '%s' "$entry" | "$DT_TOOL_JQ" -j '.contents' > "$work/dumped"
  run cmp "$work/dumped" "$NVD"
  assert_success
}
