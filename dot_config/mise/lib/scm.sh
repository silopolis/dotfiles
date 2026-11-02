# shellcheck shell=bash
# Shared helpers of the global scm:worktree:* and agent:dispatch mise tasks.
# Sourced, never executed. Generic: nothing here is specific to one repository.

scm_die() { echo "error: $*" >&2; exit 1; }
scm_warn() { echo "warning: $*" >&2; }
scm_info() { echo "$*" >&2; }

# Directory the task was started from (mise sets MISE_ORIGINAL_CWD).
scm_origin_dir() { printf '%s' "${MISE_ORIGINAL_CWD:-$PWD}"; }

# Common git dir of the repository containing $1.
scm_common_dir() {
  git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null
}

# Main checkout of the repository containing $1 (even when $1 is a worktree).
scm_main_checkout() {
  local common
  common=$(scm_common_dir "$1") || return 1
  dirname "$common"
}

# True when the project at $1 defines the mise task $2.
scm_has_task() {
  mise -C "$1" tasks ls --json 2>/dev/null | jq -e --arg t "$2" 'any(.[]; .name == $t)' >/dev/null 2>&1
}

# True when the mise config of the directory $1 is trusted.
scm_trusted() {
  mise -C "$1" trust --show 2>&1 | grep -q ': trusted$'
}

# Dies when the mise config of $1 exists but is untrusted: `mise tasks ls` and
# `mise vars` fail on it, so project hooks and settings would be skipped silently.
# (`mise run` itself trusts the config of the directory it runs in.)
scm_require_trusted() { # dir reason
  if mise -C "$1" trust --show 2>&1 | grep -q ': untrusted$'; then
    scm_die "the mise config of $1 is not trusted, $2. Review it, then run: mise trust '$1'"
  fi
}

# Value of the mise var $2 for the project at $1 (empty when unset).
scm_var() {
  mise -C "$1" vars --json 2>/dev/null | jq -r --arg k "$2" '.[$k] // empty' 2>/dev/null || true
}

# Repository name from the origin URL of $1 (empty without origin).
scm_repo_name() {
  local url name
  url=$(git -C "$1" remote get-url origin 2>/dev/null) || return 0
  name=${url%/}
  name=${name##*[/:]}
  printf '%s' "${name%.git}"
}

# Worktree name prefix. Chain: flag ($2), WORKTREES_PREFIX, project/global var
# scm_worktrees_prefix, then "{repo}". {repo} is the origin repository name
# (else the checkout directory), {dir} the checkout directory name.
scm_prefix() {
  local main=$1 flag=${2:-} pattern repo dir
  pattern=${flag:-${WORKTREES_PREFIX:-}}
  [[ -n $pattern ]] || pattern=$(scm_var "$main" scm_worktrees_prefix)
  [[ -n $pattern ]] || pattern='{repo}'
  dir=$(basename "$main")
  repo=$(scm_repo_name "$main")
  pattern=${pattern//\{repo\}/${repo:-$dir}}
  printf '%s' "${pattern//\{dir\}/$dir}"
}

scm_worktrees_root() {
  local root=${WORKTREES_ROOT:-$HOME/Work/trees}
  printf '%s' "${root/#\~/$HOME}"
}

# File where scm:worktree:new stores the herdr tab id (inside the worktree's git admin dir).
scm_tab_file() {
  local gitdir
  gitdir=$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null) || return 1
  printf '%s/herdr-tab' "$gitdir"
}

# Run the project hook task $2 (if the project at $1 defines it) with the
# remaining arguments as VAR=value environment entries. Returns the task's status.
scm_run_hook() {
  local dir=$1 task=$2
  shift 2
  scm_has_task "$dir" "$task" || return 0
  env "$@" mise -C "$dir" run "$task" >&2
}

# Report the core.worktree incident on the checkout $1 (value $2) and exit with status 3.
# Never unsets the value: the cause is not established, so it is evidence (see the git
# hygiene incident noted in the roadmap).
scm_report_incident() { # main value
  local main=$1 value=$2
  {
    echo "INCIDENT: core.worktree is set on the source checkout $main"
    echo "  value: $value"
    echo "  It was NOT unset: inspect it with"
    echo "    git config --show-origin --file '$main/.git/config' --get core.worktree"
  } >&2
  scm_run_hook "$main" scm:worktree:hook:incident \
    "WT_INCIDENT=core.worktree" "WT_INCIDENT_VALUE=$value" "WT_SOURCE=$main" || true
  if [[ ${HERDR_ENV:-} == 1 ]]; then
    herdr notification show "INCIDENT: core.worktree" --body "set on $main" --sound request >/dev/null 2>&1 || true
  fi
  exit 3
}

# Fail (status 3) when the source checkout has a core.worktree setting.
scm_check_source() { # main
  local value
  value=$(git config --file "$(scm_common_dir "$1")/config" --get core.worktree 2>/dev/null || true)
  [[ -z $value ]] || scm_report_incident "$1" "$value"
}

# Main checkout of the repository containing $1, after the integrity check. A bad
# core.worktree makes git itself fail in the checkout, so when git cannot run, the
# nearest .git/config is read directly before giving up.
scm_preflight() { # dir
  local dir=$1 main d value
  if main=$(scm_main_checkout "$dir"); then
    scm_check_source "$main"
    printf '%s' "$main"
    return 0
  fi
  d=$(cd "$dir" 2>/dev/null && pwd -P) || scm_die "$dir does not exist"
  while [[ $d != / ]]; do
    if [[ -f $d/.git/config ]]; then
      value=$(git config --file "$d/.git/config" --get core.worktree 2>/dev/null || true)
      [[ -z $value ]] || scm_report_incident "$d" "$value"
      break
    fi
    d=$(dirname "$d")
  done
  scm_die "$dir is not inside a working git repository"
}

# Resolve a worktree from a stem, name, branch or path. Prints "path<TAB>branch".
# Never matches the main checkout.
scm_find_worktree() {
  local main=$1 target=$2 path branch line found=() key
  target=${target%/}
  while IFS= read -r line; do
    case $line in
      "worktree "*) path=${line#worktree }; branch='' ;;
      "branch "*) branch=${line#branch refs/heads/} ;;
      "")
        if [[ -n ${path:-} && $path != "$main" ]]; then
          key=$(basename "$path")
          if [[ $path == "$target" || $key == "$target" || $key == *"-$target" \
                || ${branch:-} == "$target" || ${branch:-} == */"$target" ]]; then
            found+=("$path"$'\t'"${branch:-}")
          fi
        fi
        path=''
        ;;
    esac
  done < <(git -C "$main" worktree list --porcelain; echo)
  if ((${#found[@]} == 0)); then
    return 1
  elif ((${#found[@]} > 1)); then
    scm_warn "'$target' is ambiguous:"
    printf '  %s\n' "${found[@]%%$'\t'*}" >&2
    return 2
  fi
  printf '%s\n' "${found[0]}"
}

# Start a herdr agent in a freshly created pane. A new tab's shell needs a moment before
# herdr accepts the start ("agent_pane_busy: not an available shell"), so retry that
# error for up to about 20 seconds; any other error is final.
scm_start_agent() { # name kind pane [agent args...]
  local name=$1 kind=$2 pane=$3 out i
  shift 3
  local args=()
  (($#)) && args=(-- "$@")
  for ((i = 0; i < 40; i++)); do
    if out=$(herdr agent start "$name" --kind "$kind" --pane "$pane" "${args[@]}" 2>&1); then
      return 0
    fi
    [[ $out == *agent_pane_busy* ]] || break
    sleep 0.5
  done
  printf '%s\n' "$out" >&2
  return 1
}

# Send the first prompt to a freshly started agent and check that it was taken up.
# A prompt sent while the TUI is still starting is lost although herdr reports success, so
# submit with --wait --until working (herdr answers agent_prompt_stalled when the agent
# never starts working) and retry. An agent that answers in under a second without
# being seen working would get the prompt twice; a first prompt is a brief, so it works.
scm_prompt_agent() { # name text
  local name=$1 text=$2 out i
  for ((i = 0; i < 6; i++)); do
    if out=$(herdr agent prompt "$name" "$text" --wait --until working --timeout 20000 2>&1); then
      return 0
    fi
    [[ $out == *agent_prompt_stalled* || $out == *timeout* ]] || break
    sleep 2
  done
  printf '%s\n' "$out" >&2
  return 1
}

# Workspace id for a label or id ($1), via herdr.
scm_workspace_id() {
  local want=$1 ids
  ids=$(herdr workspace list 2>/dev/null | jq -r --arg w "$want" \
    '.result.workspaces[] | select(.workspace_id == $w or .label == $w) | .workspace_id') || return 1
  [[ -n $ids && $(wc -l <<<"$ids") -eq 1 ]] || return 1
  printf '%s' "$ids"
}
