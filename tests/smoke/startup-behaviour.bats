#!/usr/bin/env bats
# Proves the spec shell-startup, requirement "Behaviour that a startup change must keep", as absolute invariants
# (the old before-and-after comparison is the opt-in startup-compare.bats): real shells start on a scratch render,
# with a synthetic private environment file, a stub opencode binary and stub completion tools.
# Every assertion holds whatever tools this machine has, because the PATH of the shells is the scratch bin directory
# and the system directories, and nothing here names a variable of the real environment.

load ../helpers/bats/load

setup_file() {
  require_tool chezmoi
  RENDER_DEST=$(dt_render "$BATS_FILE_TMPDIR/render") || return 1
  export RENDER_DEST
}

setup() {
  dt_prepare_home "$BATS_TEST_TMPDIR/home" "$RENDER_DEST"
  dt_write_private_env "$DT_HOME/.config/env"
  dt_make_opencode_stub "$DT_HOME"
  dt_make_startup_tools "$DT_HOME"
  STUBLOG=$DT_HOME/stub.log
  : > "$STUBLOG"
}

last_line() {
  printf '%s\n' "$1" | tr -d '\r' | tail -n 1
}

# counts that a shell prints for the private environment: how many of the two synthetic names are exported (none: the
# private file is loaded on demand by `secrets load`, not by the startup files), and how many times the name that
# rc.d/010-env_user.sh unsets is exported
private_snippet() {
  printf 'printf "%%s %%s\\n" "$(env | cut -d= -f1 | grep -cx -e %s -e %s)" "$(env | cut -d= -f1 | grep -cx -e %s)"' \
    "$(dt_alpha_name)" "$(dt_beta_name)" "$(dt_unset_name)"
}

@test "private environment: zsh -i exports none of the synthetic names and not the unset one" {
  require_shell zsh
  run dt_start_pty "$(dt_unset_name)=$(dt_canary 4)" -- zsh -i -c "$(private_snippet)"
  assert_equal "$(last_line "$output")" "0 0"
}

@test "private environment: bash -i exports none of the synthetic names and not the unset one" {
  require_shell bash
  run dt_start_pty "$(dt_unset_name)=$(dt_canary 4)" -- bash -i -c "$(private_snippet)"
  assert_equal "$(last_line "$output")" "0 0"
}

@test "private environment: zsh -l -i exports none of the synthetic names and not the unset one" {
  require_shell zsh
  run dt_start_pty "$(dt_unset_name)=$(dt_canary 4)" -- zsh -l -i -c "$(private_snippet)"
  assert_equal "$(last_line "$output")" "0 0"
}

# the stub counts the secret-named names it receives; three synthetic ones are exported, and a plain one;
# the bypass sees the three: startup exports nothing from the private environment file of the scratch home
opencode_check() {
  local names n exports=() script
  mapfile -t names < <(dt_syn_names)
  for n in 0 1 2; do
    exports+=("${names[$n]}=$(dt_canary $((n + 1)))")
  done
  exports+=(DEMO_PLAIN=d)
  script='opencode "two words" x; echo "status=$?"; STUB_STATUS=7 opencode fail; echo "status=$?"; command opencode x'
  run dt_start_pty "${exports[@]}" STUB_PRESENT=DEMO_PLAIN -- "$1" -i -c "$script"
  assert_success
  assert_equal "$(printf '%s\n' "$output" | tr -d '\r')" "$(
    printf '%s\n' 0 --args-- 'two words' x --present-- DEMO_PLAIN=present status=0
    printf '%s\n' 0 --args-- fail --present-- DEMO_PLAIN=present status=7
    printf '%s\n' 3 --args-- x --present-- DEMO_PLAIN=present
  )"
}

@test "the opencode function in zsh -i removes the secret-named names, passes arguments and status, and can be bypassed" {
  require_shell zsh
  opencode_check zsh
}

@test "the opencode function in bash -i removes the secret-named names, passes arguments and status, and can be bypassed" {
  require_shell bash
  opencode_check bash
}

# the display manager's call: a non-interactive zsh that sources the profile files, stdout only
desktop_env() {
  dt_start "$(dt_unset_name)=$(dt_canary 4)" -- zsh -c 'emulate -R zsh; [ -f /etc/zsh/zprofile ] && . /etc/zsh/zprofile; [ -f $HOME/.zprofile ] && . $HOME/.zprofile; env' 2> /dev/null
}

@test "the desktop session replay exports none of the synthetic names" {
  require_shell zsh
  run desktop_env
  assert_success
  assert_equal "$(printf '%s\n' "$output" | cut -d= -f1 | grep -cx -e "$(dt_alpha_name)" -e "$(dt_beta_name)" || true)" 0
}

@test "the desktop session replay does not export the name that 010-env_user.sh unsets" {
  require_shell zsh
  run desktop_env
  assert_success
  assert_equal "$(printf '%s\n' "$output" | cut -d= -f1 | grep -cx -e "$(dt_unset_name)" || true)" 0
}

# the PATH of a login shell is the PATH of the same shell started without -l (audit F18 was a second pass that changed it).
# /etc/profile gives a login shell its own PATH, so both start from that one, read at run time: the startup files keep
# the PATH they inherit, and a second pass that added or nested an entry would make the two differ.
path_of() {
  DT_START_PATH=$(dt_login_path) dt_start_pty -- "$@" | tr -d '\r' | grep '^PATH=' | head -n 1
}

@test "zsh -l -i has the PATH of zsh -i" {
  require_shell zsh
  local login plain
  login=$(path_of zsh -l -i -c env)
  plain=$(path_of zsh -i -c env)
  [ -n "$login" ] || fail "no PATH line from zsh -l -i"
  assert_equal "$login" "$plain"
}

@test "bash -l -i has the PATH of bash -i" {
  require_shell bash
  local login plain
  login=$(path_of bash -l -i -c env)
  plain=$(path_of bash -i -c env)
  [ -n "$login" ] || fail "no PATH line from bash -l -i"
  assert_equal "$login" "$plain"
}

@test "fpath holds no duplicate in zsh -i" {
  require_shell zsh
  run dt_start_pty -- zsh -i -c 'print -rl -- $fpath | sort | uniq -d | wc -l'
  assert_equal "$(last_line "$output")" 0
}

# the registrations with a filled cache: two starts, the second one reads the cache files
registrations() {
  dt_start_pty -- "$@" > /dev/null 2>&1
  dt_start_pty -- "$@" 2> /dev/null | tr -d '\r' | tail -n 1
}

@test "zsh -i registers a completion for every cached tool and its alias, with the cache filled" {
  require_shell zsh
  run registrations zsh -i -c 'for t in kubectl minikube kind gh glab localstack infracost docker k mk kd d; do printf "%s=%s " $t ${+_comps[$t]}; done; echo'
  assert_output "kubectl=1 minikube=1 kind=1 gh=1 glab=1 localstack=1 infracost=1 docker=1 k=1 mk=1 kd=1 d=1 "
}

@test "bash -i registers a completion for every cached tool and its alias, with the cache filled" {
  require_shell bash
  run registrations bash -i -c 'for t in kubectl minikube kind gh glab localstack infracost docker k mk kd d; do printf "%s=%s " $t $(complete -p $t 2>/dev/null | wc -l | tr -d " "); done; echo'
  assert_output "kubectl=1 minikube=1 kind=1 gh=1 glab=1 localstack=1 infracost=1 docker=1 k=1 mk=1 kd=1 d=1 "
}

# env -i with HOME and TERM only: the shared configuration is loaded, so the cm alias exists
@test "a bash login shell on a bare terminal loads the shared configuration" {
  require_shell bash
  require_tool script
  run bash -c "cd '$DT_HOME' && '$DT_TOOL_SCRIPT' -qec \"env -i HOME='$DT_HOME' TERM=xterm $(dt_mise_vars | tr '\n' ' ') bash -l -i -c 'alias cm'\" /dev/null < /dev/null"
  assert_equal "$(printf '%s\n' "$output" | tr -d '\r' | grep -c '^alias cm=')" 1
}

# every alias and function that the repository defines unconditionally (at column 0) is defined in the shell
defined_names() {
  local file
  file=$(dt_source_file dot_config/shell/aliases)
  sed -n 's/^alias \([A-Za-z0-9_.@+-]\{1,\}\)=.*/alias \1/p' "$file"
  sed -n 's/^\([A-Za-z_][A-Za-z0-9_-]*\) *() *{.*/func \1/p' "$file"
}

check_defined_names() {
  local snippet
  defined_names > "$DT_HOME/names.txt"
  [ "$(wc -l < "$DT_HOME/names.txt")" -ge 50 ] || fail "fewer than 50 names were read from the aliases file"
  snippet='miss=0; total=0
while read -r kind n; do
  total=$((total + 1))
  case $kind in
    alias) alias "$n" > /dev/null 2>&1 || miss=$((miss + 1)) ;;
    func) if [ -n "$ZSH_VERSION" ]; then k=$(whence -w "$n" 2>/dev/null); [ "$k" = "$n: function" ] || miss=$((miss + 1)); else [ "$(type -t "$n")" = function ] || miss=$((miss + 1)); fi ;;
  esac
done < "$HOME/names.txt"
echo "missing=$miss"'
  run dt_start_pty -- "$1" -i -c "$snippet"
  assert_equal "$(last_line "$output")" "missing=0"
}

@test "zsh -i defines every alias and function that the aliases file defines unconditionally" {
  require_shell zsh
  check_defined_names zsh
}

@test "bash -i defines every alias and function that the aliases file defines unconditionally" {
  require_shell bash
  check_defined_names bash
}
