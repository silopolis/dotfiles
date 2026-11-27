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
  scripts_setup_file real iso ycm darwin extra lower strict
}

setup() {
  scripts_setup
  S00=$RI/run_onchange_before_00-prerequisites.sh
  S01=$RI/run_onchange_before_01-decrypt-private-key.sh
  S02=$RI/run_onchange_before_02-system-limits.sh
  S03=$RI/run_onchange_before_03-session-defaults.sh
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
  IFS=$'\t' read -r S_UMASK S_SUDO S_HOME _ < "$DT_DATA_DIR/session"
  SUDO_WANT=$(printf 'Defaults umask=0%s\nDefaults umask_override' "$S_SUDO")
  ME=$(id -un)
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

# --- session defaults: the comment field, the sudoers file, the home mode and the locales
# The sudoers directory, /etc/locale.gen and the sbin directories are aimed at the scratch home of the run, sudo only logs
# (-E makes it run the command as the plain user, against those scratch paths), chmod is a stub that answers like the real one.

# ses NAME: the flags of a session defaults run
ses() {
  local h
  h=$(dt_harness_logdir "$1")/userhome
  printf -- '-s /etc/sudoers.d=%s/sudoers.d -s /etc/locale.gen=%s/locale.gen -s /usr/local/sbin:/usr/sbin:/sbin=%s/none -e TMPDIR=%s/tmp -t chmod' "$h" "$h" "$h" "$h"
}
sh_file() { printf '%s/userhome/%s' "$(dt_harness_logdir "$1")" "$2"; } # NAME FILE: a file of the scratch home of a run
sh_mode() { stat -c %a "$(dt_harness_logdir "$1")/userhome"; }
sesfix() { dt_script_fixture "$1" "$BATS_TEST_TMPDIR/fix/$2"; } # FIXTURE NAME: build FIXTURE as NAME, to change before the run
sesput() { printf '%s\n' "${@:3}" > "$BATS_TEST_TMPDIR/fix/$1/userhome/$2"; } # NAME FILE LINES...
out_has() { # NAME TEXT...
  local n=$1 t
  shift
  for t in "$@"; do
    grep -q -F -- "$t" "$(dt_harness_logdir "$n")/out.log" || fail "out.log lacks: $t [$(head -n 6 "$(dt_harness_logdir "$n")/out.log" | tr '\n' '|')]"
  done
}
sudo_line() { sed -n "${2}p" "$(dt_harness_logdir "$1")/sudo.log"; } # NAME N
# nothing_changed NAME HOMEMODE: no sudo call, no call that writes, the home mode as it was, nothing left in TMPDIR
nothing_changed() {
  [ ! -s "$(dt_harness_logdir "$1")/sudo.log" ] || fail "sudo was called"
  count_calls "$1" '^stub (chfn|locale-gen|chmod) ' 0
  assert_equal "$(sh_mode "$1")" "$2"
  assert_equal "$(ls -A "$(sh_file "$1" tmp)" | wc -l | tr -d ' ')" 0
}
# gecos_case NAME LIVE WANT [OUTRE]: a comment field LIVE on the session-set fixture makes one chfn call with WANT, or none for "-"
gecos_case() {
  sesfix session-set "$1"
  sesput "$1" gecos "$2"
  if [ "$3" = - ]; then
    case_run "$1" isolated "$1" "$S03" "$(ses "$1")" 0 0 "${4:-}" ''
  else
    case_run "$1" isolated "$1" "$S03" "$(ses "$1")" 0 1 '' ''
    assert_equal "$(sudo_line "$1" 1)" "sudo chfn -o $(printf '%q' "$3") $ME"
  fi
  nothing_changed_but_sudo "$1"
}
nothing_changed_but_sudo() { count_calls "$1" '^stub (locale-gen|chmod) ' 0; }

@test "ses-set: everything is already set, no sudo, no chmod, nothing installed" {
  case_run ses-set isolated session-set "$S03" "$(ses ses-set)" 0 0 'login umask: already set' ''
  out_has ses-set 'sudo umask: already set' 'home mode: already set' 'locales: already generated'
  nothing_changed ses-set 700
}

@test "ses-nothing: the recorded sudo calls are chfn, the checked sudoers file, the locale.gen file and locale-gen, then the home" {
  local vpath
  case_run ses-nothing isolated session-none "$S03" "$(ses ses-nothing) -M 0755" 0 4 '' 'stub chmod 0700'
  read -r vpath < "$(sh_file ses-nothing visudo.path)"
  assert_equal "$(sudo_line ses-nothing 1)" "sudo chfn -o umask=$S_UMASK $ME"
  assert_equal "$(sudo_line ses-nothing 2)" "sudo install -m 0440 $vpath $(sh_file ses-nothing sudoers.d/50-umask)"
  [[ $(sudo_line ses-nothing 3) == "sudo install -m 0644 "*"/locale.gen $(sh_file ses-nothing locale.gen)" ]] || fail "line 3: $(sudo_line ses-nothing 3)"
  assert_equal "$(sudo_line ses-nothing 4)" "sudo locale-gen --keep-existing"
  assert_equal "$(cat "$(sh_file ses-nothing visudo.seen)")" "$SUDO_WANT"
  assert_equal "$(sh_mode ses-nothing)" 700
  count_calls ses-nothing '^sudo sudo chmod' 0
}

@test "ses-effects: run as the plain user, the comment field, the sudoers file, locale.gen and the home hold the declared values" {
  local h orig
  case_run ses-effects isolated session-none "$S03" "$(ses ses-effects) -M 0755 -E" 0 4 '' ''
  h=$(dt_harness_logdir ses-effects)/userhome
  orig=$BATS_TEST_TMPDIR/fix/session-none/userhome/locale.gen
  assert_equal "$(cat "$h/gecos")" "Demo User,,,,umask=$S_UMASK"
  assert_equal "$(cat "$h/sudoers.d/50-umask")" "$SUDO_WANT"
  assert_equal "$(stat -c %a "$h/sudoers.d/50-umask")" 440
  assert_equal "$(stat -c %a "$h")" 700
  # in locale.gen the one commented line became active and no other line moved
  assert_equal "$(wc -l < "$h/locale.gen")" "$(wc -l < "$orig")"
  assert_equal "$(diff "$orig" "$h/locale.gen" | grep -c '^[<>]' || true)" 2
  grep -qxF 'en_US.UTF-8 UTF-8' "$h/locale.gen"
  grep -qxF 'en_US.utf8' "$h/generated"
  grep -qxF 'fr_FR.utf8' "$h/generated"
  assert_equal "$(ls -A "$h/tmp" | wc -l | tr -d ' ')" 0
}

@test "ses-locale-append: a locale that locale.gen does not name is appended and no line is removed" {
  local h orig
  sesfix session-none la
  sesput la locale.gen '# header' '# de_DE.UTF-8 UTF-8' 'fr_FR.UTF-8 UTF-8'
  case_run ses-locale-append isolated la "$S03" "$(ses ses-locale-append) -E" 0 4 '' ''
  h=$(dt_harness_logdir ses-locale-append)/userhome
  orig=$BATS_TEST_TMPDIR/fix/la/userhome/locale.gen
  assert_equal "$(tail -n 1 "$h/locale.gen")" 'en_US.UTF-8 UTF-8'
  assert_equal "$(head -n -1 "$h/locale.gen")" "$(cat "$orig")"
}

@test "ses-locale-active: an entry that is active but not generated needs locale-gen and no edit" {
  sesfix session-none lv
  sesput lv gecos "Demo User,,,,umask=$S_UMASK"
  sesput lv locale.gen 'en_US.UTF-8 UTF-8' 'fr_FR.UTF-8 UTF-8'
  rm -f "$BATS_TEST_TMPDIR/fix/lv/userhome/sudoers.d/50-umask"
  printf 'Defaults umask=0%s\nDefaults umask_override\n' "$S_SUDO" > "$BATS_TEST_TMPDIR/fix/lv/userhome/sudoers.d/50-umask"
  case_run ses-locale-active isolated lv "$S03" "$(ses ses-locale-active)" 0 1 '' ''
  assert_equal "$(sudo_line ses-locale-active 1)" 'sudo locale-gen --keep-existing'
}

@test "ses-other-kept: the entries of the other sub-field stay, in order, and the umask entry is added or replaced in place" {
  gecos_case ses-kept-1 'Demo User,,,,pri=5' "pri=5,umask=$S_UMASK"
  gecos_case ses-kept-2 'Demo User,,,,ulimit=9,pri=5' "ulimit=9,pri=5,umask=$S_UMASK"
  gecos_case ses-kept-3 'Demo User,,,,pri=5,umask=022,ulimit=9' "pri=5,umask=$S_UMASK,ulimit=9"
  gecos_case ses-kept-4 'Demo User,,,,umask=007' "umask=$S_UMASK"
}

@test "ses-other-same: the same umask in another spelling is already set" {
  gecos_case ses-same 'Demo User,,,,pri=5,umask=0027,ulimit=9' - 'login umask: already set'
}

@test "ses-other-left: a stricter, unreadable or ambiguous umask in the comment field is left with a warning" {
  gecos_case ses-left-1 'Demo User,,,,umask=077' - 'stricter'
  gecos_case ses-left-2 'Demo User,,,,pri=5,umask=abc' - 'not an octal'
  gecos_case ses-left-3 'Demo User,,,,umask=027,umask=077' - 'more than one'
}

@test "ses-stricter: a stricter comment-field umask and a stricter home mode are left with a warning each" {
  sesfix session-set ses-stricter
  sesput ses-stricter gecos 'Demo User,,,,umask=077'
  case_run ses-stricter isolated ses-stricter "$SES_STRICT/run_onchange_before_03-session-defaults.sh" "$(ses ses-stricter)" 0 0 'login umask: .*stricter' ''
  out_has ses-stricter 'home mode: '
  assert_equal "$(grep -c 'warning:.*left unchanged' "$(sh_file ses-stricter ../out.log)")" 2
  nothing_changed ses-stricter 700
}

@test "ses-sudo-stricter: a sudo umask that the live file makes stricter is left, a more permissive one is replaced" {
  sesfix session-set ss
  rm -f "$BATS_TEST_TMPDIR/fix/ss/userhome/sudoers.d/50-umask"
  printf 'Defaults umask=0077\nDefaults umask_override\n' > "$BATS_TEST_TMPDIR/fix/ss/userhome/sudoers.d/50-umask"
  case_run ses-sudo-stricter isolated ss "$S03" "$(ses ses-sudo-stricter)" 0 0 'sudo umask: .*stricter' ''
  sesfix session-set sw
  rm -f "$BATS_TEST_TMPDIR/fix/sw/userhome/sudoers.d/50-umask"
  printf 'Defaults umask=0002\nDefaults umask_override\n' > "$BATS_TEST_TMPDIR/fix/sw/userhome/sudoers.d/50-umask"
  case_run ses-sudo-weaker isolated sw "$S03" "$(ses ses-sudo-weaker)" 0 1 '' ''
  [[ $(sudo_line ses-sudo-weaker 1) == "sudo install -m 0440 "*"/50-umask $(sh_file ses-sudo-weaker sudoers.d/50-umask)" ]]
}

@test "ses-invalid-sudoers: a file that visudo rejects is never installed, the reason is printed, nothing is changed" {
  local m
  for m in reject partial; do
    sesfix session-none "iv-$m"
    sesput "iv-$m" visudo.mode "$m"
    case_run "ses-invalid-$m" isolated "iv-$m" "$S03" "$(ses "ses-invalid-$m") -M 0755" 1 0 'visudo rejects' ''
    nothing_changed "ses-invalid-$m" 755
  done
  out_has ses-invalid-reject 'syntax error'
}

@test "ses-no-chfn: without chfn the comment field is skipped and the other parts are done" {
  case_run ses-no-chfn isolated session-none "$S03" "$(ses ses-no-chfn) -M 0755 -a chfn" 0 3 'skipping the login umask' 'stub chmod 0700'
  count_calls ses-no-chfn 'chfn -o' 0
}

@test "ses-no-getent: without getent the comment field is skipped and the other parts are done" {
  case_run ses-no-getent isolated session-none "$S03" "$(ses ses-no-getent) -M 0755 -a getent" 0 3 'skipping the login umask' 'stub chmod 0700'
}

@test "ses-no-sudoers-dir: without /etc/sudoers.d the sudo umask is skipped and the other parts are done" {
  sesfix session-none nd
  rmdir "$BATS_TEST_TMPDIR/fix/nd/userhome/sudoers.d"
  case_run ses-no-sudoers-dir isolated nd "$S03" "$(ses ses-no-sudoers-dir) -M 0755" 0 3 'skipping the sudo umask' 'stub chmod 0700'
  count_calls ses-no-sudoers-dir 'visudo' 0
}

@test "ses-no-visudo: without visudo nothing is installed into sudoers.d" {
  case_run ses-no-visudo isolated session-none "$S03" "$(ses ses-no-visudo) -M 0755 -a visudo" 0 3 'skipping the sudo umask' 'stub chmod 0700'
  count_calls ses-no-visudo '0440' 0
}

@test "ses-no-locale-gen: without locale-gen the locales are skipped and the other parts are done" {
  case_run ses-no-locale-gen isolated session-none "$S03" "$(ses ses-no-locale-gen) -M 0755 -a locale-gen" 0 2 'skipping the locales' 'stub chmod 0700'
}

@test "ses-no-locale: without locale the locales are skipped" {
  case_run ses-no-locale isolated session-none "$S03" "$(ses ses-no-locale) -M 0755 -a locale" 0 2 'skipping the locales' 'stub chmod 0700'
}

@test "ses-dry: a dry run prints the five changes it would make and records no sudo call and no chmod" {
  case_run ses-dry isolated session-none "$S03" "$(ses ses-dry) -M 0755 $DRY" 0 0 'would run: sudo chfn' ''
  out_has ses-dry "would run: sudo chfn -o umask=$S_UMASK $ME" 'would run: sudo install -m 0440' 'would run: sudo install -m 0644' \
    'would run: sudo locale-gen --keep-existing' "would run: chmod $S_HOME"
  assert_equal "$(grep -c 'would run:' "$(sh_file ses-dry ../out.log)")" 5
  nothing_changed ses-dry 755
}

# --- a sudoers file that only root can read (the mode 0440 of the real one): compared through one sudo call

# rv NAME [SUDOERS-LINES...]: a session-set fixture whose sudoers file cannot be read, and what root would read from it
rv() {
  sesfix session-set "$1"
  sesput "$1" sudoers.root "${@:2}"
}
RV_FLAGS='-M 000:sudoers.d/50-umask'

@test "ses-root-same: the file is read through sudo, equal to the declared one: nothing is installed" {
  [ "$(id -u)" -ne 0 ] || skip "root reads every file"
  rv rs "Defaults umask=0$S_SUDO" 'Defaults umask_override'
  case_run ses-root-same isolated rs "$S03" "$(ses ses-root-same) $RV_FLAGS" 0 1 'sudo umask: already set' ''
  assert_equal "$(sudo_line ses-root-same 1)" "sudo cat $(sh_file ses-root-same sudoers.d/50-umask)"
}

@test "ses-root-differs: a file that differs is read through sudo, then replaced" {
  [ "$(id -u)" -ne 0 ] || skip "root reads every file"
  rv rd 'Defaults umask=0002' 'Defaults umask_override'
  case_run ses-root-differs isolated rd "$S03" "$(ses ses-root-differs) $RV_FLAGS" 0 2 '' ''
  assert_equal "$(sudo_line ses-root-differs 1)" "sudo cat $(sh_file ses-root-differs sudoers.d/50-umask)"
  [[ $(sudo_line ses-root-differs 2) == "sudo install -m 0440 "*"/50-umask $(sh_file ses-root-differs sudoers.d/50-umask)" ]]
}

@test "ses-root-stricter: a stricter umask in a file read through sudo is left" {
  [ "$(id -u)" -ne 0 ] || skip "root reads every file"
  rv rt 'Defaults umask=0077' 'Defaults umask_override'
  case_run ses-root-stricter isolated rt "$S03" "$(ses ses-root-stricter) $RV_FLAGS" 0 1 'sudo umask: .*stricter' ''
}

@test "ses-root-fails: a read through sudo that fails stops the script, names the force variable and changes nothing" {
  [ "$(id -u)" -ne 0 ] || skip "root reads every file"
  rv rf 'Defaults umask=0002'
  sesput rf sudo-cat.mode fail
  case_run ses-root-fails isolated rf "$S03" "$(ses ses-root-fails) $RV_FLAGS -M 0755" 1 1 'CHEZMOI_SCRIPTS_FORCE=1' ''
  assert_equal "$(sh_mode ses-root-fails)" 755
  count_calls ses-root-fails '^stub (chfn|locale-gen|chmod) ' 0
}

@test "ses-root-force: with CHEZMOI_SCRIPTS_FORCE=1 the file is installed without a read through sudo" {
  [ "$(id -u)" -ne 0 ] || skip "root reads every file"
  rv rg 'Defaults umask=0002'
  sesput rg sudo-cat.mode fail
  case_run ses-root-force isolated rg "$S03" "$(ses ses-root-force) $RV_FLAGS -e CHEZMOI_SCRIPTS_FORCE=1" 0 1 '' ''
  [[ $(sudo_line ses-root-force 1) == "sudo install -m 0440 "*"/50-umask "* ]]
  count_calls ses-root-force 'sudo cat' 0
}

@test "ses-root-dry: a dry run makes no read through sudo and says it would compare" {
  [ "$(id -u)" -ne 0 ] || skip "root reads every file"
  rv rr 'Defaults umask=0002'
  case_run ses-root-dry isolated rr "$S03" "$(ses ses-root-dry) $RV_FLAGS $DRY" 0 0 'would read' ''
}

# --- a tool that fails or prints part of its answer, a write that fails: nothing is changed, the steps after it do not run

@test "ses-getent: a getent that fails, prints part of a line or answers for another name changes nothing" {
  local m
  for m in fail partial partial-fail other; do
    sesfix session-none "g-$m"
    sesput "g-$m" getent.mode "$m"
    case_run "ses-getent-$m" isolated "g-$m" "$S03" "$(ses "ses-getent-$m") -M 0755" 1 0 'getent' ''
    nothing_changed "ses-getent-$m" 755
  done
}

@test "ses-locale-query: a locale -a that fails or prints part of its answer changes nothing" {
  local m
  for m in fail partial; do
    sesfix session-none "l-$m"
    sesput "l-$m" locale.mode "$m"
    case_run "ses-locale-$m" isolated "l-$m" "$S03" "$(ses "ses-locale-$m") -M 0755" 1 0 'locale -a' ''
    nothing_changed "ses-locale-$m" 755
  done
}

@test "ses-tmp: a temporary directory that cannot be made changes nothing" {
  case_run ses-tmp isolated session-none "$S03" "$(ses ses-tmp) -M 0755 -e TMPDIR=/nonexistent/scratch" 1 0 'temporary' ''
  nothing_changed ses-tmp 755
}

@test "ses-locale-gen-file: a locale.gen that cannot be read changes nothing" {
  [ "$(id -u)" -ne 0 ] || skip "root reads every file"
  case_run ses-gen-file isolated session-none "$S03" "$(ses ses-gen-file) -M 0755 -M 000:locale.gen" 1 0 'locale.gen' ''
  nothing_changed ses-gen-file 755
}

@test "ses-no-sudo: without sudo no change is made" {
  case_run ses-no-sudo isolated session-none "$S03" "$(ses ses-no-sudo) -M 0755 -a sudo" 1 0 'sudo' ''
  nothing_changed ses-no-sudo 755
}

@test "ses-chfn-fails: a chfn that fails stops the script before the sudoers file, the locales and the home" {
  sesfix session-none cf
  sesput cf chfn.mode fail
  case_run ses-chfn-fails isolated cf "$S03" "$(ses ses-chfn-fails) -M 0755 -E" 1 1 'chfn' ''
  assert_equal "$(cat "$(sh_file ses-chfn-fails gecos)")" 'Demo User,,,'
  [ ! -e "$(sh_file ses-chfn-fails sudoers.d/50-umask)" ] || fail "the sudoers file was written"
  count_calls ses-chfn-fails '^stub (locale-gen|chmod) ' 0
  assert_equal "$(sh_mode ses-chfn-fails)" 755
}

@test "ses-sudo-fails: a sudo that fails on the sudoers install stops the script before the locales and the home" {
  sesfix session-none sf
  sesput sf gecos "Demo User,,,,umask=$S_UMASK"
  case_run ses-sudo-fails isolated sf "$S03" "$(ses ses-sudo-fails) -M 0755 -u 1" 1 1 '' ''
  [[ $(sudo_line ses-sudo-fails 1) == "sudo install -m 0440 "* ]]
  count_calls ses-sudo-fails '^stub (locale-gen|chmod) ' 0
  assert_equal "$(sh_mode ses-sudo-fails)" 755
}

@test "ses-locale-install-fails: a failed locale.gen install is not followed by locale-gen" {
  sesfix session-set lf
  sesput lf generated C C.utf8 fr_FR.utf8 POSIX
  sesput lf locale.gen '# en_US.UTF-8 UTF-8' 'fr_FR.UTF-8 UTF-8'
  case_run ses-locale-install-fails isolated lf "$S03" "$(ses ses-locale-install-fails) -u 1" 1 1 '' ''
  [[ $(sudo_line ses-locale-install-fails 1) == "sudo install -m 0644 "* ]]
  count_calls ses-locale-install-fails 'locale-gen --keep-existing' 0
}

@test "ses-locale-gen-fails: a locale-gen that fails stops the script before the home" {
  sesfix session-set gf
  sesput gf generated C C.utf8 fr_FR.utf8 POSIX
  sesput gf locale-gen.mode fail
  case_run ses-locale-gen-fails isolated gf "$S03" "$(ses ses-locale-gen-fails) -E -M 0755" 1 1 'locale-gen' ''
  count_calls ses-locale-gen-fails '^stub chmod ' 0
  assert_equal "$(sh_mode ses-locale-gen-fails)" 755
}

@test "ses-chmod-fails: a chmod of the home that fails is an error" {
  sesfix session-set mf
  sesput mf chmod.mode fail
  case_run ses-chmod-fails isolated mf "$S03" "$(ses ses-chmod-fails) -M 0755" 1 0 'chmod' ''
  assert_equal "$(sh_mode ses-chmod-fails)" 755
}

@test "again-session: the first run makes the changes, the second run makes none" {
  twice_case again-session session-none "$S03" "$(ses again-session) -E -M 0755" '^sudo |^stub chmod '
}

# --- the guard: an isolated script that lists a real directory is refused before it runs

@test "guard-real: isolated mode refuses a script that lists a real directory" {
  case_run guard-real isolated pipx-ok "$R/run_onchange_after_12-pipx.sh" '' 3 0 '' ''
}
