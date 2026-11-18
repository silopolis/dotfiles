#!/usr/bin/env bats
# Proves the spec install-scripts in isolated mode of the harness: each rendered chezmoi script runs under `env -i` with a
# scratch HOME, a PATH of logging stubs and of a curated directory of base utilities, and standard input from /dev/null,
# so it can call nothing but stubs. A case names a fixture (the answers of the stubs and the files of the scratch home),
# flags (a variable, a tool left out, a dry run), the exit status, the number of sudo calls, and what out.log and calls.log
# must show. The expected figures that depend on the repository data (the number of apt packages, the limits, the krew and
# pipx lists, the extension ids) come from that data, through the synthetic configuration.
#
# The case names are the ones of the old harness (`pre-ok`, `lim-match`, ...): each test name starts with one.

load ../helpers/bats/load
load ../helpers/bats/scripts

setup_file() {
  scripts_setup_file real iso ycm darwin extra lower
}

setup() {
  scripts_setup
  S00=$RI/run_onchange_before_00-prerequisites.sh
  S01=$RI/run_onchange_before_01-decrypt-private-key.sh
  S02=$RI/run_onchange_before_02-system-limits.sh
  S10=$RI/run_onchange_after_10-brew.sh
  S11=$RI/run_onchange_after_11-mise.sh
  S12=$RI/run_onchange_after_12-pipx.sh
  S13=$RI/run_onchange_after_13-krew.sh
  S20=$RI/run_onchange_after_20-vscodium-extensions.sh
  S21=$RI/run_onchange_after_21-vim-plugins.sh
  S90=$RI/run_onchange_after_90-bat-cache.sh
  DRY='-e CHEZMOI_SCRIPTS_DRY_RUN=1'
  APT_N=$(wc -l < "$DT_DATA_DIR/apt.txt" | tr -d ' ')
  APT_FIRST=$(head -n 1 "$DT_DATA_DIR/apt.txt")
  APT_LAST=$(tail -n 1 "$DT_DATA_DIR/apt.txt")
  read -r SOFT HARD < "$DT_DATA_DIR/limits"
  VENVS_MISSING=$(head -n 3 "$DT_DATA_DIR/venvs.txt" | tr '\n' ' ' | sed 's/ $//')
  KREW_N=$(wc -l < "$DT_DATA_DIR/krews-linux.txt" | tr -d ' ')
  KREW_N4=$(wc -l < "$DT_DATA_DIR/krews-darwin.txt" | tr -d ' ')
  KREW_FIRST=$(head -n 1 "$DT_DATA_DIR/krews-linux.txt")
  KREW_LAST=$(tail -n 1 "$DT_DATA_DIR/krews-linux.txt")
  E1=$(sed -n 2p "$DT_DATA_DIR/vscodium.txt")
  E2=$(sed -n 6p "$DT_DATA_DIR/vscodium.txt")
  VSIX=$DT_VSIX_ID
}

# lim NAME: the flags that aim the limits script at a file of the scratch home of that run, and let sudo run as the plain user
lim() {
  printf -- '-E -s /etc/security/limits.d/ulimit.conf=%s/userhome/ulimit.conf' "$(dt_harness_logdir "$1")"
}

# --- prerequisites (apt)

@test "pre-ok: every declared apt package is installed, no sudo" {
  case_run pre-ok isolated prereq-ok "$S00" '' 0 0 "all $APT_N apt packages" ''
}

@test "pre-missing: two packages are missing, two sudo calls, one install of exactly those" {
  case_run pre-missing isolated prereq-missing "$S00" '' 0 2 "missing apt packages: $APT_FIRST $APT_LAST" "apt-get install -qy $APT_FIRST $APT_LAST"
}

@test "pre-dry: a dry run names the apt update and makes no sudo call" {
  case_run pre-dry isolated prereq-missing "$S00" "$DRY" 0 0 'would run: sudo apt-get update' ''
}

# --- system limits

@test "lim-match: the file already holds the declared limits, no sudo" {
  case_run lim-match isolated limits-match "$S02" "$(lim lim-match)" 0 0 "already holds soft $SOFT" ''
}

# limits_file NAME: what the scratch file of that run holds (the sudo of the run installed into it as the plain user)
limits_file() {
  cat "$(dt_harness_logdir "$1")/userhome/ulimit.conf"
}

@test "lim-absent: no file, one sudo call that installs the declared content" {
  case_run lim-absent isolated limits-absent "$S02" "$(lim lim-absent)" 0 1 'needs root: write' 'sudo install -m 0644'
  assert_equal "$(limits_file lim-absent)" "$(printf '* soft nofile %s\n* hard nofile %s' "$SOFT" "$HARD")"
}

@test "lim-old: lower values in the file, one sudo call that installs the declared content" {
  case_run lim-old isolated limits-old "$S02" "$(lim lim-old)" 0 1 'needs root: write' 'sudo install -m 0644'
  assert_equal "$(limits_file lim-old)" "$(printf '* soft nofile %s\n* hard nofile %s' "$SOFT" "$HARD")"
}

@test "lim-inf: an unlimited soft value is never lowered, no sudo" {
  case_run lim-inf isolated limits-inf "$S02" "$(lim lim-inf)" 0 0 'left unchanged' ''
}

@test "lim-dry: a dry run names the install and makes no sudo call" {
  case_run lim-dry isolated limits-old "$S02" "$(lim lim-dry) $DRY" 0 0 'would run: sudo install' ''
  assert_equal "$(limits_file lim-dry)" "$(printf '* soft nofile %s\n* hard nofile %s' "$((SOFT / 2))" "$((HARD / 2))")"
}

@test "lim-lower: a declared limit below the live one is a warning, the file stays, no sudo" {
  case_run lim-lower isolated limits-match "$LIM_LOWER/run_onchange_before_02-system-limits.sh" "$(lim lim-lower)" 0 0 'left unchanged' ''
}

# --- decrypt

@test "dec-present: the age identity is there, nothing is decrypted" {
  case_run dec-present isolated decrypt-present "$S01" '' 0 0 'identity present' ''
}

@test "dec-absent: the identity is decrypted through chezmoi" {
  case_run dec-absent isolated decrypt-absent "$S01" '' 0 0 '' 'chezmoi age decrypt --output'
}

# --- brew

@test "br-ok: the Brewfile is installed with brew file" {
  case_run br-ok isolated brew-ok "$S10" '' 0 0 'brew file install from' 'brew file install'
}

@test "br-drift: undeclared packages are reported" {
  case_run br-drift isolated brew-drift "$S10" '' 0 0 'whosthere' ''
}

@test "br-dry: a dry run names the brew file install" {
  case_run br-dry isolated brew-drift "$S10" "$DRY" 0 0 'would run: brew file install' ''
}

@test "br-norust: no default Rust toolchain, stable is set" {
  case_run br-norust isolated brew-norust "$S10" '' 0 0 'setting stable' 'rustup default stable'
}

@test "br-nofile: a missing Brewfile is a failure" {
  case_run br-nofile isolated brew-nofile "$S10" '' 1 0 'is missing' ''
}

@test "br-nobrew: no brew after the installer is a failure, with one sudo call" {
  case_run br-nobrew isolated brew-ok "$S10" '-a brew' 1 1 'still missing after the installer' 'curl -fsSL'
}

@test "br-nobrew-dry: no brew in a dry run stops cleanly" {
  case_run br-nobrew-dry isolated brew-ok "$S10" "-a brew $DRY" 0 0 'stopping after the dry run' ''
}

@test "br-darwin: the macOS render installs through brew bundle" {
  case_run br-darwin isolated brew-ok "$K_DARWIN/run_onchange_after_10-brew.sh" '' 0 0 '' 'brew bundle --file=/dev/stdin'
}

# the completions block, which the old harness never ran: the link is a state that brew reports
@test "br-completions-linked: linked completions make no link call" {
  dt_script_fixture brew-ok "$BATS_TEST_TMPDIR/fix/brew-ok"
  : > "$BATS_TEST_TMPDIR/fix/brew-ok/linked"
  run_case br-completions-linked isolated brew-ok "$S10" ''
  check_case br-completions-linked isolated 0 0 'brew file install from' ''
  count_calls br-completions-linked 'completions link' 0
}

@test "br-completions-unlinked: unlinked completions are linked, once" {
  case_run br-completions-unlinked isolated brew-ok "$S10" '' 0 0 'completions are not linked: linking them' 'stub brew completions link'
  count_calls br-completions-unlinked 'completions link' 1
}

@test "br-completions-dry: a dry run names the link and makes no call" {
  case_run br-completions-dry isolated brew-ok "$S10" "$DRY" 0 0 'would run: brew completions link' ''
  count_calls br-completions-dry 'completions link' 0
}

# --- mise

@test "mi-ok: missing tools are installed with mise install" {
  case_run mi-ok isolated pipx-ok "$S11" '' 0 0 'mise install' 'mise install --yes'
}

@test "mi-reshim: the shims are refreshed with mise reshim" {
  case_run mi-reshim isolated pipx-ok "$S11" '' 0 0 'mise reshim' 'stub mise reshim'
}

@test "mi-dry: a dry run names the reshim" {
  case_run mi-dry isolated pipx-ok "$S11" "$DRY" 0 0 'would run: mise reshim' ''
}

@test "mi-none: no mise is a skip" {
  case_run mi-none isolated pipx-ok "$S11" '-a mise' 0 0 'mise not found' ''
}

@test "mi-none-msg: the skip says that the script runs again once mise is installed" {
  case_run mi-none-msg isolated pipx-ok "$S11" '-a mise' 0 0 'runs again once it is installed' ''
}

@test "dry-chezmoi: the dry-run variable under chezmoi is a warning that chezmoi records the script as run" {
  case_run dry-chezmoi isolated pipx-ok "$S11" '-e CHEZMOI_SCRIPTS_DRY_RUN=1 -e CHEZMOI=1' 0 0 'chezmoi records this script as run' ''
}

# --- pipx

@test "px-ok: every declared venv is installed" {
  case_run px-ok isolated pipx-ok "$S12" '' 0 0 'all declared venvs are installed' ''
}

@test "px-miss: missing venvs are installed with one pipx install-all" {
  case_run px-miss isolated pipx-missing "$S12" '' 0 0 "missing venvs: $VENVS_MISSING" 'pipx install-all'
}

@test "px-dry: a dry run names the pipx install-all" {
  case_run px-dry isolated pipx-missing "$S12" "$DRY" 0 0 'would run: pipx install-all' ''
}

@test "px-nospec: a missing spec file is a failure" {
  case_run px-nospec isolated pipx-nospec "$S12" '' 1 0 'is missing' ''
}

@test "px-nopipx: no pipx is a skip" {
  case_run px-nopipx isolated pipx-ok "$S12" '-a pipx' 0 0 'pipx not found, skipping' ''
}

@test "px-nojq: no jq is a skip" {
  case_run px-nojq isolated pipx-ok "$S12" '-a jq' 0 0 'jq not found, skipping' ''
}

@test "px-shim: a jq that exists only as a mise shim of the scratch home is found" {
  case_run px-shim isolated pipx-shim "$S12" '-a jq' 0 0 "missing venvs: $VENVS_MISSING" 'pipx install-all'
}

@test "px-extra-dir: a jq in a directory added to tools.search is found" {
  case_run px-extra-dir isolated pipx-missing "$PIPX_EXTRA/run_onchange_after_12-pipx.sh" '-a jq' 0 0 "missing venvs: $VENVS_MISSING" 'pipx install-all'
}

# --- krew

@test "kr-ok: every declared plugin is installed" {
  case_run kr-ok isolated krew-ok "$S13" '' 0 0 "all $KREW_N declared plugins" ''
}

@test "kr-miss: missing plugins are installed in one call, an undeclared one is reported" {
  case_run kr-miss isolated krew-miss "$S13" '' 0 0 'extraplugin' "krew install $KREW_FIRST $KREW_LAST"
}

@test "kr-nokrew: kubectl without the krew plugin is a skip" {
  case_run kr-nokrew isolated krew-nokrew "$S13" '' 0 0 'does not find the krew plugin' ''
}

@test "kr-darwin: the macOS render declares the shorter list" {
  case_run kr-darwin isolated krew-ok4 "$K_DARWIN/run_onchange_after_13-krew.sh" '' 0 0 "all $KREW_N4 declared plugins" ''
}

@test "kr-nokubectl: no kubectl is a skip" {
  case_run kr-nokubectl isolated krew-ok "$S13" '-a kubectl' 0 0 'kubectl not found, skipping' ''
}

@test "kr-nokrewbin: no kubectl-krew is a skip" {
  case_run kr-nokrewbin isolated krew-ok "$S13" '-a kubectl-krew' 0 0 'kubectl-krew not found, skipping' ''
}

# --- vim

@test "vm-ok: the plugins are installed in Ex mode" {
  case_run vm-ok isolated vim-ok "$S21" '' 0 0 'vim PluginInstall' 'vim -N -Es -n -u .*\+PluginInstall \+qall'
}

@test "vm-ycm: the YouCompleteMe core library is built when it is declared and missing" {
  case_run vm-ycm isolated vim-ycm-missing "$V_YCM/run_onchange_after_21-vim-plugins.sh" '' 0 0 'building the YouCompleteMe' 'python3 .*install.py --all'
}

@test "vm-built: an existing core library is not built again" {
  case_run vm-built isolated vim-ycm-built "$V_YCM/run_onchange_after_21-vim-plugins.sh" '' 0 0 'already built' ''
}

@test "vm-novundle: a missing Vundle directory is a failure" {
  case_run vm-novundle isolated vim-novundle "$S21" '' 1 0 'is missing' ''
}

@test "vm-fails: a vim that fails is a warning" {
  case_run vm-fails isolated vim-fails "$S21" '' 0 0 'may be incomplete' ''
}

@test "vm-novim: no vim is a skip" {
  case_run vm-novim isolated vim-ok "$S21" '-a vim' 0 0 'vim not found, skipping' ''
}

# --- bat

@test "bat-ok: the bat cache is built" {
  case_run bat-ok isolated brew-ok "$S90" '' 0 0 'bat cache --build' 'stub bat cache --build'
}

@test "bat-ok: exactly one cache build call" {
  run_case bat-ok isolated brew-ok "$S90" ''
  count_calls bat-ok 'bat cache --build' 1
}

@test "bat-dry: a dry run names the cache build" {
  case_run bat-dry isolated brew-ok "$S90" "$DRY" 0 0 'would run: bat cache --build' ''
}

@test "bat-dry: a dry run makes no bat call" {
  run_case bat-dry isolated brew-ok "$S90" "$DRY"
  count_calls bat-dry 'bat cache' 0
}

@test "bat-none: no bat is a skip" {
  case_run bat-none isolated brew-ok "$S90" '-a bat' 0 0 'bat not found, skipping' ''
}

@test "bat-none: no bat call is made" {
  run_case bat-none isolated brew-ok "$S90" '-a bat'
  count_calls bat-none 'bat cache' 0
}

# --- VSCodium

@test "vs-ok: an installed local extension is skipped" {
  require_tool python3 unzip
  case_run vs-ok isolated vs-base "$S20" '' 0 0 "$VSIX is installed, skipped" ''
}

@test "vs-ok: nothing is installed" {
  require_tool python3 unzip
  run_case vs-ok isolated vs-base "$S20" ''
  count_calls vs-ok 'install-extension' 0
}

@test "vs-missing: two missing extensions are installed" {
  require_tool python3 unzip
  case_run vs-missing isolated vs-missing "$S20" '' 0 0 "installing $E1" "install-extension $E1"
}

@test "vs-missing: exactly two install calls" {
  require_tool python3 unzip
  run_case vs-missing isolated vs-missing "$S20" ''
  count_calls vs-missing 'install-extension' 2
}

@test "vs-newvsix: a local archive whose extension is not installed is installed" {
  require_tool python3 unzip
  case_run vs-newvsix isolated vs-newvsix "$S20" '' 0 0 "installing $VSIX from" "install-extension .*$VSIX-0.1.2.vsix"
}

@test "vs-newvsix: exactly one install call" {
  require_tool python3 unzip
  run_case vs-newvsix isolated vs-newvsix "$S20" ''
  count_calls vs-newvsix 'install-extension' 1
}

@test "vs-case: extension ids are compared in lower case" {
  require_tool python3 unzip
  case_run vs-case isolated vs-case "$S20" '' 0 0 'is installed, skipped' ''
}

@test "vs-case: nothing is installed" {
  require_tool python3 unzip
  run_case vs-case isolated vs-case "$S20" ''
  count_calls vs-case 'install-extension' 0
}

# the id comes from package.json when unzip and jq exist (file name other.name-1.0.vsix, installed: skipped) ...
@test "vs-fb-json: the id of an archive comes from its package.json" {
  require_tool python3 unzip
  case_run vs-fb-json isolated vs-fbname "$S20" '' 0 0 "$VSIX is installed, skipped" ''
}

@test "vs-fb-json: nothing is installed" {
  require_tool python3 unzip
  run_case vs-fb-json isolated vs-fbname "$S20" ''
  count_calls vs-fb-json 'install-extension' 0
}

# ... and from the file name otherwise (jq absent: id other.name, not installed: installed)
@test "vs-fb-name: without jq the id comes from the file name" {
  require_tool python3 unzip
  case_run vs-fb-name isolated vs-fbname "$S20" '-a jq' 0 0 'installing other.name from' 'install-extension .*other.name-1.0.vsix'
}

@test "vs-fb-name: exactly one install call" {
  require_tool python3 unzip
  run_case vs-fb-name isolated vs-fbname "$S20" '-a jq'
  count_calls vs-fb-name 'install-extension' 1
}

@test "vs-badzip: a file that is not an archive is named by its file name" {
  require_tool python3 unzip
  case_run vs-badzip isolated vs-badzip "$S20" '' 0 0 "$DT_VSIX_BAD is installed, skipped" ''
}

@test "vs-badzip: nothing is installed" {
  require_tool python3 unzip
  run_case vs-badzip isolated vs-badzip "$S20" ''
  count_calls vs-badzip 'install-extension' 0
}

@test "vs-dry: a dry run names the install and runs none" {
  require_tool python3 unzip
  case_run vs-dry isolated vs-both "$S20" "$DRY" 0 0 'would run: codium --install-extension' ''
}

@test "vs-dry: a dry run makes no install call" {
  require_tool python3 unzip
  run_case vs-dry isolated vs-both "$S20" "$DRY"
  count_calls vs-dry 'install-extension' 0
}

@test "vs-nocodium: no codium is a skip" {
  require_tool python3 unzip
  case_run vs-nocodium isolated vs-base "$S20" '-a codium' 0 0 'codium not found, skipping' ''
}

@test "vs-listfail: a failing listing stops everything" {
  require_tool python3 unzip
  case_run vs-listfail isolated vs-listfail "$S20" '' 1 0 'nothing is installed' ''
}

@test "vs-listfail: no install call is made" {
  require_tool python3 unzip
  run_case vs-listfail isolated vs-listfail "$S20" ''
  count_calls vs-listfail 'install-extension' 0
}

@test "vs-fail: a failed install is a warning and the next extension is tried" {
  require_tool python3 unzip
  case_run vs-fail isolated vs-fail "$S20" '' 0 0 "failed: $E1" "install-extension $E2"
}

@test "vs-fail: both installs were tried" {
  require_tool python3 unzip
  run_case vs-fail isolated vs-fail "$S20" ''
  count_calls vs-fail 'install-extension' 2
}

@test "vs-novsix: no archive directory is not an error" {
  require_tool python3 unzip
  case_run vs-novsix isolated vs-novsix "$S20" '' 0 0 '' ''
}

@test "vs-novsix: no install call is made" {
  require_tool python3 unzip
  run_case vs-novsix isolated vs-novsix "$S20" ''
  count_calls vs-novsix 'install-extension' 0
}

# --- never uninstall: the drift fixtures list undeclared packages, and no removal call is made

@test "br-drift: no removal call is made" {
  run_case br-drift isolated brew-drift "$S10" ''
  count_calls br-drift 'uninstall|untap|brew remove' 0
}

@test "px-miss: no uninstall call is made, and the undeclared venv is named" {
  run_case px-miss isolated pipx-missing "$S12" ''
  count_calls px-miss 'uninstall' 0
  grep -q -F -- 'unlistedtool' "$(dt_harness_logdir px-miss)/out.log" || fail "the output does not name the undeclared venv"
}

@test "kr-miss: no removal call is made" {
  run_case kr-miss isolated krew-miss "$S13" ''
  count_calls kr-miss 'uninstall|remove' 0
}

# --- second run in a row: the stub tools keep their state in the scratch home, which the second run reuses

@test "again-apt: the first run installs, the second installs nothing" {
  twice_case again-apt st-apt "$S00" '-E' 'apt-get install'
}

@test "again-pipx: the first run installs, the second installs nothing" {
  twice_case again-pipx st-pipx "$S12" '' 'pipx install-all'
}

@test "again-krew: the first run installs, the second installs nothing" {
  twice_case again-krew st-krew "$S13" '' 'krew install'
}

@test "again-codium: the first run installs, the second installs nothing" {
  require_tool python3 unzip
  twice_case again-codium st-codium "$S20" '' 'install-extension'
}

# --- the guard: an isolated script that lists a real directory is refused before it runs

@test "guard-real: isolated mode refuses a script that lists a real directory" {
  case_run guard-real isolated pipx-ok "$R/run_onchange_after_12-pipx.sh" '' 3 0 '' ''
}
