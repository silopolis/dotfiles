#!/usr/bin/env bats
# bats file_tags=live
# The checks of the spec install-scripts that read this machine: opt-in (`DOTFILES_TEST_LIVE=1`, or `mise run test:live`)
# and read-only. Each script is rendered with the real directories of tools.search and run in the live mode of the harness:
# the real HOME and PATH, a stub that forwards an allow-list of read-only calls to the real tools and refuses and logs
# everything else, and `sudo` as a logging stub. A script passes when it exits 0 and the sudo log and the refused log are
# empty. A failure prints counts, never the log: the logs hold what the real tools said.

load ../helpers/bats/load
load ../helpers/bats/scripts

setup_file() {
  [ "${DOTFILES_TEST_LIVE:-}" = 1 ] || return 0
  scripts_setup_file real
}

setup() {
  require_live
  scripts_setup
}

live_run() { # NAME SCRIPT-FILE-NAME
  case_run "live-$1" live '' "$R/run_onchange_$2.sh" '' 0 0 '' ''
}

@test "live-00-prerequisites: the apt packages are installed, no sudo" {
  live_run 00-prerequisites before_00-prerequisites
}

@test "live-01-decrypt-private-key: the age identity is present" {
  live_run 01-decrypt-private-key before_01-decrypt-private-key
}

@test "live-02-system-limits: the limits file matches the data, no sudo" {
  live_run 02-system-limits before_02-system-limits
}

@test "live-10-brew: the Brewfile is installed, no sudo" {
  live_run 10-brew after_10-brew
}

@test "live-12-pipx: every declared venv is installed, no sudo" {
  live_run 12-pipx after_12-pipx
}

@test "live-13-krew: every declared plugin is installed, no sudo" {
  live_run 13-krew after_13-krew
}

@test "live-21-vim-plugins: the vim plugins are in place, no sudo" {
  live_run 21-vim-plugins after_21-vim-plugins
}

# bat: the real bat builds a real cache from the real config directory, into a scratch target; the real cache stays as it was
@test "live-90-bat: the bat cache is built" {
  require_tool bat
  case_run live-90-bat live '' "$R/run_onchange_after_90-bat-cache.sh" '' 0 0 'bat cache --build' 'rewrite bat cache --build'
}

@test "live bat-scratch: the cache is written to the scratch target and the real cache directory is untouched" {
  require_tool bat
  local cache before target
  cache=$(dt_real_home)/.cache/bat
  before=$(ls -A "$cache" 2> /dev/null | tr '\n' ' ')
  case_run live-90-bat live '' "$R/run_onchange_after_90-bat-cache.sh" '' 0 0 'bat cache --build' 'rewrite bat cache --build'
  target=$(dt_harness_logdir live-90-bat)/bat-target
  [ -s "$target/themes.bin" ] || fail "no themes.bin in the scratch target"
  [ -s "$target/metadata.yaml" ] || fail "no metadata.yaml in the scratch target"
  [ "$(ls -A "$cache" 2> /dev/null | tr '\n' ' ')" = "$before" ] || fail "the real bat cache directory changed"
}

# VSCodium: the real codium lists its extensions, a real .vsix is identified with the real unzip and jq, nothing is installed
@test "live-20-vscodium: the installed extensions are listed" {
  case_run live-20-vscodium live '' "$R/run_onchange_after_20-vscodium-extensions.sh" '' 0 0 '' ''
}

@test "live vscodium-calls: no extension is installed" {
  run_case live-20-vscodium live '' "$R/run_onchange_after_20-vscodium-extensions.sh" ''
  check_case live-20-vscodium live 0 0 '' ''
  count_calls live-20-vscodium 'install-extension' 0
}

# live mode reads the deployed mise config. `mise reshim` writes the shims directory, so the stub swaps it for
# `mise --version`; the preview below shows what the real command would change.
@test "live-11-mise: every tool of the deployed config is installed" {
  case_run live-11-mise live '' "$R/run_onchange_after_11-mise.sh" '' 0 0 'all tools are installed' 'rewrite mise reshim'
}

@test "live vimrc: the repository vimrc loads Vundle under plain vim -Es, without -N" {
  require_tool vim
  local vimrc home
  vimrc=$(dt_source_file dot_config/vim/vimrc)
  home=$(dt_real_home)
  [ -d "$home/.vim/bundle/Vundle.vim" ] || skip "Vundle is not installed in the real home"
  run env -i HOME="$home" PATH="$PATH" "$DT_TOOL_VIM" -Es -n -u "$vimrc" -i NONE \
    -c 'if execute("command PluginInstall") !~ "vundle#installer#new" | cquit 2 | endif' -c qall < /dev/null
  assert_success
}

# what the next apply would install: mise's own dry run against a scratch copy of the repository config (nothing is written)
@test "live mise-pending: the next apply has no mise tool left to install" {
  require_tool mise
  local d=$BATS_TEST_TMPDIR/mise-pending out rc count
  mkdir -p "$d/work"
  cp "$(dt_source_file dot_config/mise/config.toml)" "$d/config.toml"
  out=$(cd "$d/work" && env HOME="$(dt_real_home)" PATH="$PATH" MISE_GLOBAL_CONFIG_FILE="$d/config.toml" "$DT_TOOL_MISE" install --dry-run-code < /dev/null 2>&1)
  rc=$?
  count=$(printf '%s\n' "$out" | grep -c 'would install' || true)
  [ "$rc" -eq 0 ] || fail "mise install --dry-run-code exited $rc, with $count tools that would be installed"
}

# what a real `mise reshim` would change here: the real mise runs against a symlink farm of the real installs and a COPY of
# the real shims directory, all in scratch space; the real shims and installs are never written
@test "live reshim-noop-here: a real reshim would change nothing on this machine" {
  require_tool mise
  local s=$BATS_TEST_TMPDIR/reshim-real home mise_bin data stale missing real sim
  home=$(dt_real_home)
  data=${MISE_DATA_DIR:-$home/.local/share/mise}
  [ -d "$data/installs" ] || skip "no mise installs directory in the real home"
  mise_bin=$(readlink -f "$DT_TOOL_MISE")
  mkdir -p "$s/userhome/.config" "$s/userhome/.cache" "$s/userhome/.local/state" "$s/data" "$s/work"
  cp -as "$data/installs" "$s/data/installs"
  cp -a "$data/shims" "$s/data/shims"
  # a copy of the global config, trusted in this sandbox only; the ceiling keeps mise from reading a config above it
  [ -f "$home/.config/mise/config.toml" ] && cp "$home/.config/mise/config.toml" "$s/config.toml"
  real=$(find "$s/data/shims" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort)
  (cd "$s/work" && env -i HOME="$s/userhome" PATH=/usr/bin:/bin XDG_CONFIG_HOME="$s/userhome/.config" XDG_CACHE_HOME="$s/userhome/.cache" \
    XDG_STATE_HOME="$s/userhome/.local/state" XDG_DATA_HOME="$s/userhome/.local/share" MISE_DATA_DIR="$s/data" MISE_CACHE_DIR="$s/userhome/.cache/mise" \
    MISE_STATE_DIR="$s/userhome/.local/state/mise" MISE_CONFIG_DIR="$s/userhome/.config/mise" MISE_GLOBAL_CONFIG_FILE="$s/config.toml" \
    MISE_TRUSTED_CONFIG_PATHS="$s" MISE_CEILING_PATHS="$s" MISE_OFFLINE=1 timeout 600 "$mise_bin" reshim < /dev/null > "$s/out.txt" 2>&1) || fail "the preview reshim failed"
  sim=$(find "$s/data/shims" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort)
  stale=$(comm -23 <(printf '%s\n' "$real") <(printf '%s\n' "$sim") | wc -l)
  missing=$(comm -13 <(printf '%s\n' "$real") <(printf '%s\n' "$sim") | wc -l)
  [ "$stale" -eq 0 ] && [ "$missing" -eq 0 ] || fail "a reshim would remove $stale shims and add $missing"
}
