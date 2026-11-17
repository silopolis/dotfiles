#!/usr/bin/env bash
# Render the chezmoi install scripts, and read the repository data they use: plain bash, no bats.
# Source it (`. tests/helpers/scripts.sh`; it loads render.sh), or call one function:
#   tests/helpers/scripts.sh <function> [args...]
#
# Provides:
#   DT_OS_FACTS                       the data that makes a render the same on every machine: linux, a Debian-family
#                                     os-release (the chezmoi builtins come from the machine otherwise)
#   dt_json_merge A B                 the two JSON objects merged, B over A, lists replaced
#   dt_script_config DIR              write the synthetic configuration to DIR/chezmoi.toml and set DT_SCRIPT_CONFIG
#   dt_chezmoi_render [--data JSON] [ARGS...]   run `chezmoi execute-template` under the synthetic configuration (DT_SCRIPT_CONFIG),
#                                     the source tree DOTFILES_TEST_SOURCE and a scratch home, with the OS facts and the
#                                     JSON merged into the data; the template is read from standard input unless an
#                                     argument gives it; chezmoi's PATH is DT_RENDER_PATH when that is set (a render must
#                                     not depend on the PATH of the process that renders)
#   dt_render_scripts OUT [JSON [NAME...]]
#                                     render the scripts of the source state into OUT (a directory made empty first), one
#                                     file per script, named without `.tmpl`; JSON is merged into the data; NAME... limits
#                                     it to the scripts whose file name contains one of the words
#   dt_script_data EXPRESSION [JSON]  the value of a template expression as JSON, for example '.packages.linux.apt'
#
# Nothing is executed and nothing is written outside OUT and the scratch directory of the configuration. The render
# reads neither the real configuration nor the real data: the configuration is generated, with synthetic values.

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/render.sh"

DT_OS_FACTS='{"chezmoi":{"os":"linux","osRelease":{"id":"debian","idLike":"debian"}}}'

dt_json_merge() {
  local jq_bin
  jq_bin=${DT_TOOL_JQ:-$(dt_find_tool jq)} || return 2
  # shellcheck disable=SC2016  # the jq program is single-quoted on purpose
  "$jq_bin" -cn --argjson a "${1:-"{}"}" --argjson b "${2:-"{}"}" '$a * $b'
}

dt_script_config() {
  local dir=${1:?dt_script_config DIR}
  mkdir -p -- "$dir"
  dt_render_config "$dir/chezmoi.toml"
  DT_SCRIPT_CONFIG=$dir/chezmoi.toml
  export DT_SCRIPT_CONFIG
}

dt_chezmoi_render() {
  local data='{}' chezmoi_bin
  if [ "${1:-}" = --data ]; then
    data=$2
    shift 2
  fi
  [ -n "${DT_SCRIPT_CONFIG:-}" ] || {
    printf 'dt_chezmoi_render: DT_SCRIPT_CONFIG is not set (call dt_script_config first)\n' >&2
    return 2
  }
  chezmoi_bin=${DT_TOOL_CHEZMOI:-$(dt_find_tool chezmoi)} || return 2
  data=$(dt_json_merge "$DT_OS_FACTS" "$data") || return 2
  env -i PATH="${DT_RENDER_PATH:-$PATH}" HOME="${DT_SCRIPT_HOME:-${TMPDIR:-/tmp}}" LANG=C.UTF-8 "$chezmoi_bin" \
    --config "$DT_SCRIPT_CONFIG" -S "$DOTFILES_TEST_SOURCE" execute-template --override-data "$data" "$@"
}

dt_render_scripts() {
  local out=${1:?dt_render_scripts OUT} data=${2:-"{}"} f name word want rc=0
  shift $(($# < 2 ? $# : 2))
  local words=("$@") scripts_dir
  scripts_dir=$(dt_source_file .chezmoiscripts)
  rm -rf -- "$out"
  mkdir -p -- "$out"
  for f in "$scripts_dir"/*; do
    [ -f "$f" ] || continue
    name=${f##*/}
    if [ "${#words[@]}" -gt 0 ]; then
      want=0
      for word in "${words[@]}"; do
        case $name in *"$word"*) want=1 ;; esac
      done
      [ "$want" -eq 1 ] || continue
    fi
    case $name in
      *.tmpl)
        name=${name%.tmpl}
        if ! dt_chezmoi_render --data "$data" < "$f" > "$out/$name" 2> "$out/$name.err"; then
          printf 'dt_render_scripts: %s failed: %s\n' "$name" "$(head -c 200 "$out/$name.err")" >&2
          rc=1
          continue
        fi
        [ -s "$out/$name.err" ] || rm -f -- "$out/$name.err"
        ;;
      *) cp -- "$f" "$out/$name" ;;
    esac
  done
  return "$rc"
}

dt_script_data() {
  local expr=${1:?dt_script_data EXPRESSION} data=${2:-"{}"}
  printf '{{ %s | toJson }}' "$expr" | dt_chezmoi_render --data "$data"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn=${1:?usage: scripts.sh <function> [args...]}
  shift
  "$fn" "$@"
fi
