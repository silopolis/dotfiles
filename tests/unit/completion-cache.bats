#!/usr/bin/env bats
# Proves the spec shell-startup, requirement "Cached completions", on rc.d/335-shell_completion_cache.sh.
#
# The helper is sourced in a bare zsh (`zsh -f`) and a bare bash (`bash --norc`) under `env -i`, with
# synthetic tools only. The old harness ran 17 checks one after the other on shared state; each check is
# a test of its own here (named `zsh ...` and `bash ...`), so that a parallel run shares nothing.
# A snippet prints its facts and the test compares the whole output, so a line on standard error fails it.

load ../helpers/bats/load

setup() {
  setup_scratch
  U=$(realpath "$BATS_TEST_TMPDIR")/u
  CALLS=$U/calls.log
  mkdir -p "$U"
  dt_make_completion_tools "$U"
  HELPER=$(dt_source_file dot_config/shell/rc.d/335-shell_completion_cache.sh)
  PRELUDE='. "$HELPER"
calls() { wc -l < "$CALLS" | tr -d " "; }
cf() { echo "$XDG_CACHE_HOME/shell/completions/$CURRENT_SHELL/$1"; }
: > "$CALLS"
'
}

# cc_run SNIPPET: the snippet runs in the shell under test (DT_SHELL, tag in CC_TAG), outputs merged.
cc_run() {
  local flags=(-f)
  [ "$CC_TAG" = bash ] && flags=(--norc)
  DT_PATH=$U/bin:/usr/bin:/bin dt_clean HELPER="$HELPER" U="$U" CALLS="$CALLS" CURRENT_SHELL="$CC_TAG" \
    XDG_CACHE_HOME="$U/cache" -- "$DT_SHELL" "${flags[@]}" -c "$PRELUDE$1" 2>&1
}

cache_file() {
  printf '%s\n' "$U/cache/shell/completions/$CC_TAG/$1"
}

cc_first() {
  run cc_run '_cached_completion demo-a demo-a completion "$CURRENT_SHELL"; r=$?
printf "%s\n" "$r $(calls) $([ -f "$(cf demo-a)" ] && echo file)"'
  assert_output "0 1 file"
}

cc_file_var() {
  run cc_run '_cached_completion demo-a demo-a completion "$CURRENT_SHELL"
printf "%s\n" "$_CC_FILE"
. "$_CC_FILE"; printf "sourced=%s\n" $?'
  assert_output "$(printf '%s\n' "$(cache_file demo-a)" "sourced=0")"
}

cc_header() {
  run cc_run '_cached_completion demo-a demo-a completion "$CURRENT_SHELL"; head -1 "$(cf demo-a)"'
  assert_output "#cached-completion: $U/inst/demo-a-1/demo-a"
}

cc_mode() {
  run cc_run '_cached_completion demo-a demo-a completion "$CURRENT_SHELL"; stat -c %a "$(cf demo-a)"'
  assert_output "600"
}

cc_notmp() {
  run cc_run '_cached_completion demo-a demo-a completion "$CURRENT_SHELL"
ls -A "$XDG_CACHE_HOME/shell/completions/$CURRENT_SHELL" | grep -c "^\\."'
  assert_output "0"
}

cc_hit() {
  run cc_run '_cached_completion demo-a demo-a completion "$CURRENT_SHELL"
_cached_completion demo-a demo-a completion "$CURRENT_SHELL"; r=$?
printf "%s\n" "$r $(calls)"'
  assert_output "0 1"
}

# the tool resolves to another file (brew upgrade, mise install): the link moves, only the recorded path tells
cc_moved() {
  run cc_run '_cached_completion demo-a demo-a completion "$CURRENT_SHELL"
ln -sfn "$U/inst/demo-a-2/demo-a" "$U/bin/demo-a"
touch -d 2001-01-01 "$U/inst/demo-a-2/demo-a"
_cached_completion demo-a demo-a completion "$CURRENT_SHELL"; r=$?
printf "%s\n" "$r $(calls) $(sed -n 2p "$(cf demo-a)")"'
  assert_output "0 2 # completion script, version 2"
}

cc_moved_header() {
  run cc_run '_cached_completion demo-a demo-a completion "$CURRENT_SHELL"
ln -sfn "$U/inst/demo-a-2/demo-a" "$U/bin/demo-a"
touch -d 2001-01-01 "$U/inst/demo-a-2/demo-a"
_cached_completion demo-a demo-a completion "$CURRENT_SHELL"; head -1 "$(cf demo-a)"'
  assert_output "#cached-completion: $U/inst/demo-a-2/demo-a"
}

# the tool is made newer than its cache (replaced in place)
cc_newer() {
  run cc_run '_cached_completion demo-a demo-a completion "$CURRENT_SHELL"
touch -d "now + 1 minute" "$U/inst/demo-a-1/demo-a"
_cached_completion demo-a demo-a completion "$CURRENT_SHELL"; r=$?
printf "%s\n" "$r $(calls)"'
  assert_output "0 2"
}

cc_unrelated() {
  run cc_run '_cached_completion demo-b demo-b completion "$CURRENT_SHELL"
touch -d 2001-01-01 "$(cf demo-b)"
m1=$(stat -c %Y "$(cf demo-b)")
_cached_completion demo-a demo-a completion "$CURRENT_SHELL"
touch -d "now + 1 minute" "$U/inst/demo-a-1/demo-a"
_cached_completion demo-a demo-a completion "$CURRENT_SHELL"
_cached_completion demo-b demo-b completion "$CURRENT_SHELL"
printf "%s\n" "$m1 $(stat -c %Y "$(cf demo-b)") $(grep -c "^demo-b" "$CALLS")"'
  local m1 m2 n
  read -r m1 m2 n <<< "$output"
  assert_equal "$m1" "$m2"
  assert_equal "$n" 1
}

cc_refresh() {
  run cc_run '_cached_completion demo-b demo-b completion "$CURRENT_SHELL"
n=$(calls)
SHELL_COMPLETION_REFRESH=1 _cached_completion demo-b demo-b completion "$CURRENT_SHELL"
printf "%s\n" "$n $(calls)"'
  assert_output "1 2"
}

cc_fail() {
  run cc_run 'n=$(calls); _cached_completion demo-fail demo-fail completion "$CURRENT_SHELL"; r=$?
printf "%s\n" "$r $(($(calls)-n)) $([ -e "$(cf demo-fail)" ] && echo file || echo none)"'
  assert_output "1 1 none"
}

cc_empty() {
  run cc_run '_cached_completion demo-empty demo-empty completion "$CURRENT_SHELL"; r=$?
printf "%s\n" "$r $([ -e "$(cf demo-empty)" ] && echo file || echo none)"'
  assert_output "1 none"
}

# a failing generator with an older file: the file is kept and used
cc_fail_keeps() {
  run cc_run '_cached_completion demo-a demo-a completion "$CURRENT_SHELL"
cp "$(cf demo-a)" "$(cf demo-fail)"
before=$(cksum < "$(cf demo-fail)")
touch -d "now + 1 minute" "$U/bin/demo-fail"
_cached_completion demo-fail demo-fail completion "$CURRENT_SHELL"; r=$?
printf "%s\n" "$r $(cksum < "$(cf demo-fail)")" "$before"'
  assert_equal "$(printf '%s\n' "$output" | sed -n 1p)" "0 $(printf '%s\n' "$output" | sed -n 2p)"
}

cc_unknown() {
  run cc_run '_cached_completion demo-missing demo-missing completion "$CURRENT_SHELL"; r=$?
printf "%s\n" "$r $([ -e "$(cf demo-missing)" ] && echo file || echo none)"'
  assert_output "1 none"
}

# a command with a prefix, as infracost uses it: env VAR=value tool ...
cc_prefix() {
  run cc_run '_cached_completion demo-b env DEMO_FLAG=1 demo-b completion "$CURRENT_SHELL"; r=$?
printf "%s\n" "$r $(calls) $([ -f "$(cf demo-b)" ] && echo file)"'
  assert_output "0 1 file"
}

# five shells start at once on the same missing file
cc_concurrent() {
  run cc_run 'for i in 1 2 3 4 5; do ( _cached_completion demo-c demo-c completion "$CURRENT_SHELL" ) & done; wait
printf "%s\n" "$(sed -n 2p "$(cf demo-c)") $(wc -l < "$(cf demo-c)" | tr -d " ") $(ls -A "$XDG_CACHE_HOME/shell/completions/$CURRENT_SHELL" | grep -c "^\\.")"'
  assert_output "# completion script, version 1 3 0"
}

# cc ID TAG: one check in one shell; a shell that is absent skips with its name
cc() {
  require_shell "$2"
  CC_TAG=$2
  "cc_$1"
}

ids=(first file_var header mode notmp hit moved moved_header newer unrelated refresh fail empty fail_keeps unknown prefix concurrent)
descs=(
  "first call generates and succeeds"
  "_CC_FILE points at the cache file and the file sources"
  "first line records the real path of the tool"
  "file mode is 600"
  "no temporary file left"
  "second call is a hit: no generator call"
  "tool resolves to another file: regenerated"
  "header follows the new real path"
  "tool newer than the cache: regenerated"
  "an unrelated cache file is left as it was"
  "SHELL_COMPLETION_REFRESH=1 regenerates"
  "failing generator: rc 1, tried once, no file"
  "empty output: rc 1, no file"
  "failing generator with an older file: kept, rc 0, content unchanged"
  "unknown tool: rc 1, no file"
  "command with an env prefix works"
  "concurrent start: complete file, no temporary file"
)
for tag in zsh bash; do
  for i in "${!ids[@]}"; do
    bats_test_function --description "$tag ${descs[$i]}" -- cc "${ids[$i]}" "$tag"
  done
done
