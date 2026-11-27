# shellcheck shell=bash
# Bats glue of the install-script test files: `load ../helpers/bats/load` first, then `load ../helpers/bats/scripts`.
# It renders the scripts once per file and turns a run of the harness into assertions.
#
# Provides:
#   scripts_setup_file [VARIANT...]   call from setup_file. Skips the file when chezmoi or jq is absent. Makes the
#                                     synthetic configuration, the data files and the renders, and exports their places:
#                                       real    R           the scripts as rendered with the real directories of tools.search
#                                       iso     RI          tools.search overridden with scratch directories, a scratch brew prefix
#                                       ycm     V_YCM       the vim script with vim.ycm_build true
#                                       darwin  K_DARWIN    the brew and krew scripts for macOS
#                                       extra   PIPX_EXTRA  the pipx script with one more directory in tools.search
#                                       lower   LIM_LOWER   the limits script with a declared value below the live one
#                                       strict  SES_STRICT  the session defaults script with a declared home mode of 0750
#   scripts_setup                     call from setup: a scratch root for the runs (DT_HARNESS_ROOT) and for the fixtures
#   run_case NAME MODE FIXTURE SCRIPT FLAGS
#                                     build the fixture and run the script under the harness (no assertion)
#   check_case NAME MODE EXIT SUDO OUTRE CALLSRE
#                                     assert the exit status, the number of sudo calls, an empty refused log in live
#                                     mode, and that out.log and calls.log match the regexes (empty: not checked)
#   case_run ...                      run_case then check_case, with the arguments of both
#   count_calls NAME REGEX WANT       assert the number of calls.log lines that match
#   twice_case NAME FIXTURE SCRIPT FLAGS REGEX
#                                     run twice in the same scratch home: the first run makes calls that match the regex,
#                                     the second makes none
#
# A failure prints the regex and the numbers, and the head of out.log in isolated mode (synthetic data); never in live
# mode, whose logs hold what the real tools said.

scripts_setup_file() {
  local variant iso extra_json
  require_tool chezmoi jq
  SCRIPTS_ROOT=$BATS_FILE_TMPDIR/scripts
  mkdir -p "$SCRIPTS_ROOT/home"
  DT_SCRIPT_HOME=$SCRIPTS_ROOT/home
  export DT_SCRIPT_HOME SCRIPTS_ROOT
  dt_script_config "$SCRIPTS_ROOT/cfg"
  DT_DATA_DIR=$SCRIPTS_ROOT/data
  dt_script_data_files "$DT_DATA_DIR"
  DT_ISO_ROOT=$SCRIPTS_ROOT/iso
  mkdir -p "$DT_ISO_ROOT"
  export DT_DATA_DIR DT_ISO_ROOT
  # shellcheck disable=SC2089  # a JSON text, used as one word
  ISO_BASE='{"brew":{"prefix":"'"$DT_ISO_ROOT"'/brew"},"tools":{"search":{"override":["~/.local/share/mise/shims","<brew>/bin","~/.local/bin"]}}}'
  # shellcheck disable=SC2090
  export ISO_BASE
  for variant in "$@"; do
    case $variant in
      real)
        R=$SCRIPTS_ROOT/R
        dt_render_scripts "$R" || return 1
        export R
        ;;
      iso)
        RI=$SCRIPTS_ROOT/RI
        dt_render_scripts "$RI" "$ISO_BASE" || return 1
        export RI
        ;;
      ycm)
        V_YCM=$SCRIPTS_ROOT/v-ycm
        dt_render_scripts "$V_YCM" "$(dt_json_merge "$ISO_BASE" '{"vim":{"ycm_build":true}}')" vim-plugins || return 1
        export V_YCM
        ;;
      darwin)
        K_DARWIN=$SCRIPTS_ROOT/k-darwin
        dt_render_scripts "$K_DARWIN" "$(dt_json_merge "$ISO_BASE" '{"chezmoi":{"os":"darwin"}}')" brew krew || return 1
        export K_DARWIN
        ;;
      extra)
        PIPX_EXTRA=$SCRIPTS_ROOT/pipx-extra
        mkdir -p "$DT_ISO_ROOT/extra-bin"
        ln -sf "$(dt_find_tool jq)" "$DT_ISO_ROOT/extra-bin/jq"
        iso=$(dt_json_merge "$ISO_BASE" "{\"tools\":{\"search\":{\"override\":[\"~/.local/share/mise/shims\",\"<brew>/bin\",\"~/.local/bin\",\"$DT_ISO_ROOT/extra-bin\"]}}}")
        dt_render_scripts "$PIPX_EXTRA" "$iso" pipx || return 1
        export PIPX_EXTRA
        ;;
      lower)
        LIM_LOWER=$SCRIPTS_ROOT/lim-lower
        extra_json=$(awk '{ printf "{\"system\":{\"limits\":{\"nofile\":{\"soft\":%d,\"hard\":%d}}}}", $1 / 2, $2 }' "$DT_DATA_DIR/limits")
        dt_render_scripts "$LIM_LOWER" "$(dt_json_merge "$ISO_BASE" "$extra_json")" system-limits || return 1
        export LIM_LOWER
        ;;
      strict)
        SES_STRICT=$SCRIPTS_ROOT/ses-strict
        dt_render_scripts "$SES_STRICT" "$(dt_json_merge "$ISO_BASE" '{"system":{"session":{"home_mode":"0750"}}}')" session-defaults || return 1
        export SES_STRICT
        ;;
    esac
  done
}

scripts_setup() {
  DT_HARNESS_ROOT=$BATS_TEST_TMPDIR/h
  export DT_HARNESS_ROOT
  mkdir -p "$DT_HARNESS_ROOT" "$BATS_TEST_TMPDIR/fix"
}

run_case() {
  local name=$1 mode=$2 fix=$3 script=$4 flags=$5 fixarg=()
  if [ -n "$fix" ]; then
    [ -d "$BATS_TEST_TMPDIR/fix/$fix" ] || dt_script_fixture "$fix" "$BATS_TEST_TMPDIR/fix/$fix"
    fixarg=(-f "$BATS_TEST_TMPDIR/fix/$fix")
  fi
  # shellcheck disable=SC2086  # the flags are a string of words, as in the old harness
  dt_harness_run -m "$mode" -n "$name" "${fixarg[@]}" $flags "$script" > /dev/null 2>&1 || true
}

# _case_fail MODE LOGDIR MESSAGE: fail with the message, and the head of out.log when the data is synthetic
_case_fail() {
  local mode=$1 d=$2 shown=''
  if [ "$mode" = isolated ]; then
    shown=$(head -n 5 "$d/out.log" 2> /dev/null | tr '\n' '|')
  fi
  fail "$3${shown:+ [out.log: $shown]}"
}

check_case() {
  local name=$1 mode=$2 want_exit=$3 want_sudo=$4 outre=$5 callsre=$6 d status sudo refused
  d=$(dt_harness_logdir "$name")
  status=$(cat "$d/status" 2> /dev/null || echo '?')
  sudo=$(wc -l < "$d/sudo.log")
  refused=$(wc -l < "$d/refused.log")
  [ "$status" = "$want_exit" ] || _case_fail "$mode" "$d" "exit status $status, expected $want_exit"
  [ "$sudo" = "$want_sudo" ] || _case_fail "$mode" "$d" "$sudo sudo calls, expected $want_sudo"
  if [ "$mode" = live ] && [ "$refused" != 0 ]; then
    _case_fail "$mode" "$d" "$refused refused calls, expected 0"
  fi
  if [ -n "$outre" ] && ! grep -q -E -- "$outre" "$d/out.log"; then
    _case_fail "$mode" "$d" "out.log does not match /$outre/"
  fi
  if [ -n "$callsre" ] && ! grep -q -E -- "$callsre" "$d/calls.log"; then
    _case_fail "$mode" "$d" "calls.log does not match /$callsre/"
  fi
}

case_run() {
  run_case "$1" "$2" "$3" "$4" "$5"
  check_case "$1" "$2" "$6" "$7" "$8" "$9"
}

count_calls() {
  local d got
  d=$(dt_harness_logdir "$1")
  got=$(grep -c -E -- "$2" "$d/calls.log" || true)
  [ "$got" = "$3" ] || fail "calls matching /$2/: $got, expected $3"
}

twice_case() {
  local name=$1 fix=$2 script=$3 flags=$4 re=$5 st1 st2 n1 n2 d
  d=$(dt_harness_logdir "$name")
  dt_script_fixture "$fix" "$BATS_TEST_TMPDIR/fix/$fix"
  # shellcheck disable=SC2086
  dt_harness_run -m isolated -n "$name" -f "$BATS_TEST_TMPDIR/fix/$fix" $flags "$script" > /dev/null 2>&1 || true
  st1=$(cat "$d/status")
  n1=$(grep -c -E -- "$re" "$d/calls.log" || true)
  # shellcheck disable=SC2086
  dt_harness_run -m isolated -n "$name" -K -f "$BATS_TEST_TMPDIR/fix/$fix" $flags "$script" > /dev/null 2>&1 || true
  st2=$(cat "$d/status")
  n2=$(grep -c -E -- "$re" "$d/calls.log" || true)
  [ "$st1" = 0 ] && [ "$st2" = 0 ] || fail "exit statuses $st1 and $st2, expected 0 and 0"
  [ "$n1" -ge 1 ] || fail "the first run made $n1 calls matching /$re/, expected at least 1"
  [ "$n2" = 0 ] || fail "the second run made $n2 calls matching /$re/, expected 0"
}
