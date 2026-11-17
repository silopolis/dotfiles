#!/usr/bin/env bats
# Proves the render part of the spec install-scripts: nothing is run, the templates are rendered under a synthetic
# configuration and the text is checked. The tool-presence entries flip when a tool file appears and go back when it is
# removed, the render does not depend on the PATH of the process that renders, the directory list of tools.search follows
# its rules, the hash comments change exactly when a script's inputs do, the Debian guard and the krew lists hold, and
# no home path or escaped action is left in a script.
#
# The presence directory of a test is made in its scratch directory: its home, its Homebrew prefix and its bin
# directories. Its tools.search is overridden with scratch directories, so that a real /usr/bin/codium cannot hide a flip.

load ../helpers/bats/load
load ../helpers/bats/scripts

setup_file() {
  scripts_setup_file real
}

setup() {
  scripts_setup
  P=$BATS_TEST_TMPDIR/presence
  mkdir -p "$P/userhome/.local/share/mise/shims" "$P/userhome/.local/bin" "$P/brew/bin"
  ODD='empty or odd render'
  SCRIPTS_SRC=$(dt_source_file .chezmoiscripts)
}

# ovp: the data of a render in the presence directory (plain), ovi: the same with tools.search overridden by scratch directories
ovp() {
  printf '{"chezmoi":{"homeDir":"%s"},"brew":{"prefix":"%s"}}' "$P/userhome" "$P/brew"
}

ovi() {
  dt_json_merge "$(ovp)" '{"tools":{"search":{"override":["~/.local/share/mise/shims","<brew>/bin","~/.local/bin"]}}}'
}

# rend SCRIPT [DATA]: the text of one script template, under the data of the presence directory
rend() {
  dt_chezmoi_render --data "${2:-$(ovi)}" < "$SCRIPTS_SRC/$1"
}

begins_script() {
  case $1 in '#!/usr/bin/env bash'*) return 0 ;; esac
  return 1
}

# the text differs once the tool file exists and is executable, and flips back when it goes
flip() { # SCRIPT TOOL-FILE [DATA]
  local script=$1 file=$2 data=${3:-$(ovi)} before after back
  rm -f "$file"
  before=$(rend "$script" "$data")
  : > "$file"
  chmod 755 "$file"
  after=$(rend "$script" "$data")
  rm -f "$file"
  back=$(rend "$script" "$data")
  begins_script "$before" || fail "$ODD"
  [ "$before" != "$after" ] || fail "the text did not change when the tool appeared"
  [ "$before" = "$back" ] || fail "the text did not change back when the tool went"
}

@test "flip-mise: the mise entry flips with the file" {
  flip run_onchange_after_11-mise.sh.tmpl "$P/userhome/.local/bin/mise"
}

@test "flip-pipx: the pipx entry flips with the file" {
  flip run_onchange_after_12-pipx.sh.tmpl "$P/brew/bin/pipx"
}

@test "flip-kubectl: the kubectl entry flips with a mise shim" {
  flip run_onchange_after_13-krew.sh.tmpl "$P/userhome/.local/share/mise/shims/kubectl"
}

@test "flip-krewbin: the kubectl-krew entry flips with the file" {
  flip run_onchange_after_13-krew.sh.tmpl "$P/brew/bin/kubectl-krew"
}

@test "noexec-pipx: a file that is not executable is not a tool" {
  local a b file=$P/brew/bin/pipx
  rm -f "$file"
  a=$(rend run_onchange_after_12-pipx.sh.tmpl)
  : > "$file"
  chmod 644 "$file"
  b=$(rend run_onchange_after_12-pipx.sh.tmpl)
  begins_script "$a" || fail "$ODD"
  [ "$a" = "$b" ] || fail "a non-executable file changed the text"
}

@test "flip-codium: the codium entry flips with the file" {
  flip run_onchange_after_20-vscodium-extensions.sh.tmpl "$P/brew/bin/codium" "$(dt_json_merge "$(ovp)" '{"tools":{"search":{"override":["<brew>/bin"]}}}')"
}

@test "flip-bat: the bat entry flips with the file" {
  flip run_onchange_after_90-bat-cache.sh.tmpl "$P/brew/bin/bat"
}

# the same text under three PATHs: one that holds nothing, the PATH of the suite, and one that holds every tool
# in a directory that the template does not search
path_independent() { # SCRIPT
  local script=$1 a b c t empty
  a=$(DT_RENDER_PATH=/nonexistent rend "$script" "$(ovp)" | sha256sum)
  b=$(rend "$script" "$(ovp)" | sha256sum)
  mkdir -p "$P/other/bin"
  for t in mise pipx jq kubectl kubectl-krew vim codium bat; do
    : > "$P/other/bin/$t"
    chmod 755 "$P/other/bin/$t"
  done
  c=$(DT_RENDER_PATH="$P/other/bin:$PATH" rend "$script" "$(ovp)" | sha256sum)
  empty=$(printf '' | sha256sum)
  [ "$a" != "$empty" ] || fail "$ODD"
  [ "$a" = "$b" ] || fail "the text depends on whether PATH holds anything"
  [ "$b" = "$c" ] || fail "the text depends on a directory of PATH that tools.search does not list"
}

@test "path-11-mise.sh.tmpl: the render does not depend on PATH" {
  path_independent run_onchange_after_11-mise.sh.tmpl
}

@test "path-12-pipx.sh.tmpl: the render does not depend on PATH" {
  path_independent run_onchange_after_12-pipx.sh.tmpl
}

@test "path-13-krew.sh.tmpl: the render does not depend on PATH" {
  path_independent run_onchange_after_13-krew.sh.tmpl
}

@test "path-20-vscodium-extensions.sh.tmpl: the render does not depend on PATH" {
  path_independent run_onchange_after_20-vscodium-extensions.sh.tmpl
}

@test "path-21-vim-plugins.sh.tmpl: the render does not depend on PATH" {
  path_independent run_onchange_after_21-vim-plugins.sh.tmpl
}

@test "path-90-bat-cache.sh.tmpl: the render does not depend on PATH" {
  path_independent run_onchange_after_90-bat-cache.sh.tmpl
}

# the bat script re-renders when its declared inputs change, and only then (a scratch copy of the source)
@test "bat-inputs: the bat script changes with its config and its externals, and not with an unrelated file" {
  local copy=$BATS_TEST_TMPDIR/bat-src base edit
  render_bat() {
    DOTFILES_TEST_SOURCE=$copy dt_chezmoi_render --data "$(ovp)" < "$(DOTFILES_TEST_SOURCE=$copy dt_source_file .chezmoiscripts/run_onchange_after_90-bat-cache.sh.tmpl)"
  }
  fresh() {
    rm -rf "$copy"
    mkdir -p "$copy"
    cp -a "$DOTFILES_TEST_SOURCE/.chezmoiroot" "$(dt_source_root)" "$copy/"
  }
  fresh
  base=$(render_bat)
  begins_script "$base" || fail "$ODD"
  fresh
  printf '\n# edit\n' >> "$(DOTFILES_TEST_SOURCE=$copy dt_source_file dot_config/bat/config)"
  edit=$(render_bat)
  [ "$edit" != "$base" ] || fail "a bat config edit did not change the script"
  fresh
  printf '\n# edit\n' >> "$(DOTFILES_TEST_SOURCE=$copy dt_source_file .chezmoiexternals/bat.toml.tmpl)"
  edit=$(render_bat)
  [ "$edit" != "$base" ] || fail "an externals edit did not change the script"
  fresh
  printf '\n# edit\n' >> "$(DOTFILES_TEST_SOURCE=$copy dt_source_file dot_config/tmux/tmux.conf)"
  edit=$(render_bat)
  [ "$edit" = "$base" ] || fail "an unrelated edit changed the script"
  ! grep -q '\\{\\{' "$SCRIPTS_SRC/run_onchange_after_90-bat-cache.sh.tmpl" || fail "an escaped action is left in the bat script"
}

# --- the directory list (tools.search): default, extra, override, bad entries, precedence, init

# mkcfg NAME LINES: a copy of the synthetic configuration whose [data.tools.search] table holds LINES
mkcfg() {
  local file=$BATS_TEST_TMPDIR/$1.toml
  dt_render_config "$file"
  awk '/^\[data.tools.search\]/ { skip = 1; next } skip && /^$/ { skip = 0; next } !skip' "$file" > "$file.new"
  printf '\n[data.tools.search]\n%s\n' "$2" >> "$file.new"
  mv "$file.new" "$file"
  printf '%s\n' "$file"
}

dirs_of() { # CONFIG-FILE
  printf '{{ includeTemplate "tools-dirs" . }}' | DT_SCRIPT_CONFIG=$1 dt_chezmoi_render --data "$(ovp)"
}

@test "dirs-default: the default list, in order" {
  local want
  want=$("$DT_TOOL_JQ" -cn --arg b "$P/brew" '["~/.local/share/mise/shims", $b+"/bin", "~/.local/bin", "/usr/local/bin", "/usr/bin", "/bin"]')
  assert_equal "$(dirs_of "$DT_SCRIPT_CONFIG")" "$want"
}

@test "dirs-extra: extra directories follow the defaults, normalised, without duplicates" {
  local cfg want
  cfg=$(mkcfg extra 'extra = ["/opt/tools/bin", "~/bin", "/usr/bin", "~/x/../y", "/opt/a/./b/"]')
  want=$("$DT_TOOL_JQ" -cn --arg b "$P/brew" '["~/.local/share/mise/shims", $b+"/bin", "~/.local/bin", "/usr/local/bin", "/usr/bin", "/bin", "/opt/tools/bin", "~/bin", "~/y", "/opt/a/b"]')
  assert_equal "$(dirs_of "$cfg")" "$want"
}

@test "dirs-override: override replaces the defaults and extra" {
  local cfg want
  cfg=$(mkcfg over 'extra = ["/ignored"]
override = ["/opt/only/bin", "<brew>/bin", "~/.local/bin"]')
  want=$("$DT_TOOL_JQ" -cn --arg b "$P/brew" '["/opt/only/bin", $b+"/bin", "~/.local/bin"]')
  assert_equal "$(dirs_of "$cfg")" "$want"
}

@test "dirs-bad: a bad entry fails the render with a message that names tools.search" {
  local bad out cfg
  for bad in '"bin"' '"/a:b"' "\"/it's\"" '"~"' '"~/"' '"~/.."' '"~/../x"' '5' '"<brew>"' '"./x"'; do
    cfg=$(mkcfg bad "extra = [$bad]")
    if out=$(dirs_of "$cfg" 2>&1); then
      fail "the entry $bad was accepted"
    fi
    case $out in
      *tools.search*) ;;
      *) fail "no tools.search message for $bad" ;;
    esac
  done
}

# the config beats the data file for the same key, the other keys of the data file stay
search_json() { # CONFIG-FILE
  printf '{{ .tools.search | toJson }}' | DT_SCRIPT_CONFIG=$1 dt_chezmoi_render --data '{}'
}

@test "dirs-config: the local config wins for extra and the default list stays" {
  local cfg
  cfg=$(mkcfg prec 'extra = ["/from/config"]')
  run search_json "$cfg"
  assert_success
  printf '%s\n' "$output" | "$DT_TOOL_JQ" -e '(.extra == ["/from/config"]) and ((.dirs | length) == 6) and (.override == [])' > /dev/null
}

# a tool that exists only in a directory added through tools.search.extra is found, and only then
@test "dirs-flip: a tool in an added directory is found once it exists" {
  local script=run_onchange_after_12-pipx.sh.tmpl file=$P/extra/bin/pipx cfg before after
  mkdir -p "$P/extra/bin"
  cfg=$(mkcfg flip "extra = [\"$P/extra/bin\"]")
  after=$(DT_SCRIPT_CONFIG=$cfg rend "$script" "$(ovp)")
  case $after in *pipx=absent*) ;; *) fail "pipx found before it exists" ;; esac
  : > "$file"
  chmod 755 "$file"
  before=$(rend "$script" "$(ovp)")
  after=$(DT_SCRIPT_CONFIG=$cfg rend "$script" "$(ovp)")
  case $before in *pipx=absent*) ;; *) fail "the default list found it" ;; esac
  case $after in *pipx=present*) ;; *) fail "the extra directory was not searched" ;; esac
}

# the helper: missing existing dirs are prepended in list order, present ones keep their place, absent ones are skipped
@test "usedirs-helper: use_tool_dirs puts the missing directories first, in order" {
  local d=$BATS_TEST_TMPDIR/usedirs out exp
  mkdir -p "$d/userhome/bin1" "$d/userhome/bin2" "$d/abs1" "$d/abs2"
  printf '{{ template "script-lib.sh" "probe" }}' | dt_chezmoi_render --data '{}' > "$d/lib.sh"
  printf '. %q\nHOME=%q\nPATH=%q\nuse_tool_dirs %s\nprintf "%%s\\n" "$PATH"\n' "$d/lib.sh" "$d/userhome" "$d/abs2:/usr/bin:/bin" "'~/bin1' '$d/abs1' '$d/abs2' '$d/missing' '~/bin2'" > "$d/t.sh"
  out=$(env -i bash "$d/t.sh")
  exp="$d/userhome/bin1:$d/abs1:$d/userhome/bin2:$d/abs2:/usr/bin:/bin"
  assert_equal "$out" "$exp"
}

# the config template, rendered as `chezmoi init` does: the prompt values come from the data, so nothing is asked
init_render() { # DATA
  dt_chezmoi_render --data "$1" --init < "$(dt_source_file .chezmoi.toml.tmpl)"
}

@test "init-keeps: the config template keeps the local tools.search values" {
  require_tool hostnamectl lscpu python3
  local base='"email":"x","gitemail":"x","firstname":"x","name":"x","features":{"incus":false},"nvim":{"host":"","owner":"","repo":""}'
  run init_render "{$base,\"tools\":{\"search\":{\"extra\":[\"/opt/x/bin\",\"~/bin\"],\"override\":[\"/only/bin\"]}}}"
  assert_success
  printf '%s\n' "$output" | "$DT_TOOL_PYTHON3" -c 'import sys, tomllib; d = tomllib.loads(sys.stdin.read()); s = d["data"]["tools"]["search"]; assert s == {"extra": ["/opt/x/bin", "~/bin"], "override": ["/only/bin"]}, s; assert d["encryption"] == "age"'
}

@test "init-default: the config template defaults tools.search to empty lists and holds no github key but is_codespaces" {
  require_tool hostnamectl lscpu python3
  run init_render '{"email":"x","gitemail":"x","firstname":"x","name":"x"}'
  assert_success
  printf '%s\n' "$output" | "$DT_TOOL_PYTHON3" -c 'import sys, tomllib; d = tomllib.loads(sys.stdin.read()); assert d["data"]["tools"]["search"] == {"extra": [], "override": []}, d["data"]["tools"]; assert d["data"]["features"]["incus"] is False; assert list(d["data"]["github"]) == ["is_codespaces"], d["data"]["github"]'
}

# --- the triggers, the Debian guard, the krew lists, the literal paths

# changed_scripts A B: the numbers of the scripts whose text differs between two renders, sorted
changed_scripts() {
  local f n out=''
  for f in "$1"/*.sh; do
    n=$(basename "$f" .sh)
    n=${n#run_onchange_}
    n=${n#after_}
    n=${n#before_}
    cmp -s "$f" "$2/$(basename "$f")" || out+="${n%%-*} "
  done
  printf '%s' "$out" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//'
}

@test "trigger-matrix: each edit or data change re-renders exactly the scripts that read it" {
  local copy=$BATS_TEST_TMPDIR/mx-src base=$BATS_TEST_TMPDIR/mx-base var=$BATS_TEST_TMPDIR/mx-var got fails='' source_dir
  fresh() {
    rm -rf "$copy"
    mkdir -p "$copy"
    cp -a "$DOTFILES_TEST_SOURCE/.chezmoiroot" "$(dt_source_root)" "$copy/"
  }
  mx_render() { DOTFILES_TEST_SOURCE=$copy dt_render_scripts "$var" "${1:-{\}}"; }
  mx_file() { # LABEL EXPECTED FILE
    fresh
    printf '\n# edit\n' >> "$(DOTFILES_TEST_SOURCE=$copy dt_source_file "$3")"
    mx_render
    got=$(changed_scripts "$base" "$var")
    [ "$got" = "$2" ] || fails+="$1: changed [$got], expected [$2]; "
  }
  mx_data() { # LABEL EXPECTED JSON
    fresh
    mx_render "$3"
    got=$(changed_scripts "$base" "$var")
    [ "$got" = "$2" ] || fails+="$1: changed [$got], expected [$2]; "
  }
  fresh
  DOTFILES_TEST_SOURCE=$copy dt_render_scripts "$base"
  [ -s "$base/run_onchange_after_11-mise.sh" ] || fail "$ODD"
  mx_file 'Brewfile' '10' dot_config/brewfile/Brewfile
  mx_file 'mise config' '11' dot_config/mise/config.toml
  mx_file 'pipx packages.json' '12' dot_config/pipx/packages.json
  mx_file 'vimrc' '21' dot_config/vim/vimrc
  mx_file 'bat config' '90' dot_config/bat/config
  mx_file 'bat externals' '90' .chezmoiexternals/bat.toml.tmpl
  mx_file 'tmux config (unrelated)' '' dot_config/tmux/tmux.conf
  mx_file 'shared helper' '00 01 02 10 11 12 13 20 21 90' .chezmoitemplates/script-lib.sh
  mx_data 'apt list' '00' '{"packages":{"linux":{"apt":["curl","jq"]}}}'
  mx_data 'limits' '02' '{"system":{"limits":{"nofile":{"soft":30000,"hard":65536}}}}'
  mx_data 'krew shared list' '13' '{"packages":{"common":{"krews":["tail","ctx"]}}}'
  mx_data 'vim.ycm_build' '21' '{"vim":{"ycm_build":true}}'
  mx_data 'vscodium extensions' '20' '{"vscodium":{"extensions":["a.b"]}}'
  mx_data 'brew.prefix' '10 11 12 13 20 21 90' '{"brew":{"prefix":"/opt/homebrew"}}'
  mx_data 'tools.search extra' '11 12 13 20 21 90' '{"tools":{"search":{"extra":["/opt/m/bin"]}}}'
  mx_data 'darwin packages (unrelated on Linux)' '' '{"packages":{"darwin":{"casks":["x"]}}}'
  [ -z "$fails" ] || fail "$fails"
}

@test "apt-guard: the prerequisites script renders for the Debian family only" {
  local out tmpl=$SCRIPTS_SRC/run_onchange_before_00-prerequisites.sh.tmpl
  apt_render() { dt_chezmoi_render --data "$1" < "$tmpl"; }
  out=$(apt_render '{"chezmoi":{"osRelease":{"id":"fedora","idLike":"rhel"}}}')
  [ -z "$(printf '%s' "$out" | tr -d '[:space:]')" ] || fail "fedora is not empty"
  out=$(apt_render '{"chezmoi":{"osRelease":{"id":"kali","idLike":"debian"}}}')
  begins_script "$out" || fail "a Debian derivative renders empty"
  out=$(apt_render '{"chezmoi":{"osRelease":{"id":"ubuntu","idLike":"debian"}}}')
  begins_script "$out" || fail "ubuntu renders empty"
  out=$(apt_render '{"chezmoi":{"os":"darwin"}}')
  [ -z "$(printf '%s' "$out" | tr -d '[:space:]')" ] || fail "darwin is not empty"
}

@test "krew-lists: the shared and system lists are merged, sorted, and a plugin may move between them" {
  local lin dar d=$BATS_TEST_TMPDIR/k-move last common linux json
  krew_plugins() { sed -n "s/^plugins=(\(.*\))/\1/p" "$1" | tr -d "'" | sed 's/ *$//'; }
  lin=$(krew_plugins "$R/run_onchange_after_13-krew.sh")
  assert_equal "$lin" "$(tr '\n' ' ' < "$DT_DATA_DIR/krews-linux.txt" | sed 's/ *$//')"
  # the macOS render carries the shared list and the (here empty) darwin list
  dar=$(DOTFILES_TEST_SOURCE=$DOTFILES_TEST_SOURCE dt_render_scripts "$BATS_TEST_TMPDIR/k-darwin" "$(dt_json_merge "$ISO_BASE" '{"chezmoi":{"os":"darwin"}}')" krew; krew_plugins "$BATS_TEST_TMPDIR/k-darwin/run_onchange_after_13-krew.sh")
  assert_equal "$dar" "$(tr '\n' ' ' < "$DT_DATA_DIR/krews-darwin.txt" | sed 's/ *$//')"
  # moving the last shared plugin to the system list changes no text
  common=$(dt_script_data '.packages.common.krews')
  linux=$(dt_script_data '.packages.linux.krews')
  last=$(printf '%s' "$common" | "$DT_TOOL_JQ" -r '.[-1]')
  json=$("$DT_TOOL_JQ" -cn --argjson c "$common" --argjson l "$linux" --arg last "$last" '{packages: {common: {krews: $c[:-1]}, linux: {krews: ($l + [$last])}}}')
  dt_render_scripts "$d" "$json" krew
  cmp -s "$R/run_onchange_after_13-krew.sh" "$d/run_onchange_after_13-krew.sh" || fail "moving a plugin between the lists changed the text"
}

@test "no-literal-path: no script or template holds a home path or the chezmoi source path" {
  local h=home pat
  pat="/$h/[a-z]+/|\\.local/share/chezmoi"
  run grep -rEn -e "$pat" "$SCRIPTS_SRC" "$(dt_source_file .chezmoitemplates)"
  assert_failure 1
}

@test "no-escaped: no script holds an escaped action" {
  run grep -rn '\\{\\{' "$SCRIPTS_SRC"
  assert_failure 1
}

@test "pipx-no-abs: the pipx spec file holds no absolute path" {
  local spec
  spec=$(dt_source_file dot_config/pipx/packages.json)
  assert_equal "$("$DT_TOOL_JQ" '[.. | strings | select(startswith("/"))] | length' "$spec")" 0
}

# a real render keeps the ~/ entries of use_tool_dirs and holds no home path in that line
@test "dirs-no-home: the use_tool_dirs line keeps its tilde entries" {
  local line
  line=$(grep -E '^use_tool_dirs ' "$R/run_onchange_after_11-mise.sh")
  case $line in *"$DT_SCRIPT_HOME"*) fail "a home path is in the use_tool_dirs line" ;; esac
  case $line in *"'~/.local/bin'"*) ;; *) fail "no ~/ entry in the use_tool_dirs line" ;; esac
}

@test "tools-declared: jq and kubectl are declared in the mise config and vim in the Brewfile" {
  local mise_cfg brewfile
  mise_cfg=$(dt_source_file dot_config/mise/config.toml)
  brewfile=$(dt_source_file dot_config/brewfile/Brewfile)
  grep -q -E '^jq = ' "$mise_cfg"
  grep -q -E '^kubectl = ' "$mise_cfg"
  grep -q -E '^brew vim$' "$brewfile"
}
