#!/usr/bin/env bats
# Proves the fixes made to home/dot_config/shell/aliases at the user's request: mkcd, cmmkdir and cmtouch (functions,
# no longer aliases that cannot take an argument), gbc and gbbc, vagrant-libvirt, and convert_to_png.
#
# The file is sourced in a bare zsh (`zsh -f`) and a bare bash (`bash --norc`) under `env -i`, on a PATH of a curated
# directory of base utilities and a directory of stubs (mogrify; chezmoi and docker are functions of the snippet).
# The nine checks run in both shells (named `zsh ...` and `bash ...`), and shellcheck accepts the file at error level.

load ../helpers/bats/load

setup_file() {
  dt_realbin "$BATS_FILE_TMPDIR/real"
  export REALBIN=$BATS_FILE_TMPDIR/real
}

setup() {
  setup_scratch
  W=$(realpath "$BATS_TEST_TMPDIR")/aw
  mkdir -p "$W/src" "$W/cwd" "$W/stubs" "$W/imgs one"
  printf '#!/bin/sh\necho "mogrify $*" >> "$STUBLOG"\n' > "$W/stubs/mogrify"
  chmod 0755 "$W/stubs/mogrify"
  echo x > "$W/imgs one/a.jpg"
  echo x > "$W/imgs one/b.png"
  ALIASES=$(dt_source_file dot_config/shell/aliases)
  HELPER=$(dt_source_file dot_config/shell/rc.d/335-shell_completion_cache.sh)
  PRELUDE='[ -n "$ZSH_VERSION" ] && { complete() { :; }; compdef() { :; }; }
. "$HELPER"; . "$ALIASES"
chezmoi() { echo "$W/src"; }
docker() { local a; for a in "$@"; do printf "[%s]" "$a"; done; echo; }
: > "$STUBLOG"
cd "$W/cwd"
'
}

# al_run SNIPPET: the snippet runs in the shell under test (DT_SHELL, tag in AL_TAG) from the scratch directory, outputs merged.
al_run() {
  local flags=(-f)
  [ "$AL_TAG" = bash ] && flags=(--norc)
  (cd "$W" && DT_PATH=$W/stubs:$REALBIN dt_clean HELPER="$HELPER" ALIASES="$ALIASES" W="$W" STUBLOG="$W/stub.log" \
    CURRENT_SHELL="$AL_TAG" XDG_CACHE_HOME="$W/cache" -- "$DT_SHELL" "${flags[@]}" -c "$PRELUDE$1" 2>&1)
}

# a repository with one commit on each side: feat has "second on feat", main has "third on main"
REPO_SNIPPET='mkdir -p "$W/repo" && cd "$W/repo" && git init -q -b main . \
&& git -c user.email=demo-email -c user.name=demo commit -q --allow-empty -m "first on main" \
&& git checkout -q -b feat && git -c user.email=demo-email -c user.name=demo commit -q --allow-empty -m "second on feat" \
&& git checkout -q main && git -c user.email=demo-email -c user.name=demo commit -q --allow-empty -m "third on main" \
&& git checkout -q feat
'

al_mkcd() {
  run al_run 'mkcd "new dir/inner"; echo "pwd-ends-with-inner=$([ "${PWD##*/}" = inner ] && echo yes || echo no) parent-has-space=$(case $PWD in *"new dir"*) echo yes;; esac)"'
  assert_output "pwd-ends-with-inner=yes parent-has-space=yes"
}

al_cmmkdir() {
  run al_run 'cmmkdir "dot_config/x y" other; echo "dirs-in-source=$(ls "$W/src" | wc -l | tr -d " ") nested=$([ -d "$W/src/dot_config/x y" ] && echo yes || echo no) cwd-unchanged=$([ "$PWD" = "$W/cwd" ] && echo yes || echo no) cwd-empty=$(ls "$W/cwd" | wc -l | tr -d " ")"'
  assert_output "dirs-in-source=2 nested=yes cwd-unchanged=yes cwd-empty=0"
}

al_cmtouch() {
  run al_run 'mkdir -p "$W/src/dot_config/x y"; cmtouch "dot_config/x y/f one"; echo "file-in-source=$([ -f "$W/src/dot_config/x y/f one" ] && echo yes || echo no) cwd-empty=$(ls "$W/cwd" | wc -l | tr -d " ")"'
  assert_output "file-in-source=yes cwd-empty=0"
}

al_gbc() {
  [ -x "$REALBIN/git" ] || skip "tool git is not installed"
  run al_run "$REPO_SNIPPET"'gbc main | sed "s/\x1b\[[0-9;]*m//g"'
  assert_output --partial "second on feat"
  refute_output --partial "third on main"
  assert_equal "${#lines[@]}" 1
}

al_gbbc() {
  [ -x "$REALBIN/git" ] || skip "tool git is not installed"
  run al_run "$REPO_SNIPPET"'gbbc main | sed "s/\x1b\[[0-9;]*m//g"'
  assert_output --partial "third on main"
  refute_output --partial "second on feat"
  assert_equal "${#lines[@]}" 1
}

al_vagrant() {
  run al_run 'vagrant-libvirt ssh-config "two words" | sed "s/.*\(\[vagrant\].*\)/\1/"'
  assert_output "[vagrant][ssh-config][two words]"
}

al_convert_noarg() {
  run al_run 'convert_to_png >/dev/null 2>"$W/err.txt"; echo "status=$? message=$(wc -c < "$W/err.txt" | tr -d " ") calls=$(wc -l < "$STUBLOG" | tr -d " ")"'
  assert_output --regexp '^status=1 message=[1-9][0-9]* calls=0$'
}

al_convert_dir() {
  run al_run 'convert_to_png "$W/imgs one"; echo "calls=$(wc -l < "$STUBLOG" | tr -d " ") names-a.jpg=$(grep -c "a.jpg" "$STUBLOG") names-b.png=$(grep -c "b.png" "$STUBLOG")"'
  assert_output "calls=1 names-a.jpg=1 names-b.png=0"
}

al_removed() {
  run al_run 'echo "mkcd=$(alias mkcd 2>/dev/null | wc -l | tr -d " ") cmmkdir=$(alias cmmkdir 2>/dev/null | wc -l | tr -d " ") cmtouch=$(alias cmtouch 2>/dev/null | wc -l | tr -d " ")"'
  assert_output "mkcd=0 cmmkdir=0 cmtouch=0"
}

# al ID TAG: one check in one shell; a shell that is absent skips with its name
al() {
  require_shell "$2"
  AL_TAG=$2
  "al_$1"
}

ids=(mkcd cmmkdir cmtouch gbc gbbc vagrant convert_noarg convert_dir removed)
descs=(
  "mkcd creates and enters a directory with a space"
  "cmmkdir makes directories in the source and leaves the current one"
  "cmtouch makes a file in the source and leaves the current directory empty"
  "gbc lists the commits of the current branch only"
  "gbbc lists the commits of the base branch only"
  "vagrant-libvirt passes its arguments through"
  "convert_to_png without an argument prints a usage line and converts nothing"
  "convert_to_png converts a directory with a space, once, and not a png"
  "mkcd, cmmkdir and cmtouch are no longer aliases"
)
for tag in zsh bash; do
  for i in "${!ids[@]}"; do
    bats_test_function --description "$tag ${descs[$i]}" -- al "${ids[$i]}" "$tag"
  done
done

@test "shellcheck: the aliases file has no error" {
  require_tool shellcheck
  run "$DT_TOOL_SHELLCHECK" -S error -s bash "$ALIASES"
  assert_success
  assert_equal "$output" ""
}
