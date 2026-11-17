#!/usr/bin/env bash
# Fixtures of the install-script cases: responders of the stubbed tools, scratch homes and package lists, all built at run
# time in a scratch directory. Plain bash, no bats. Source it (`. tests/helpers/script-fixtures.sh`; it loads harness.sh),
# or call one function: tests/helpers/script-fixtures.sh <function> [args...]
#
# Nothing here is a copy of a real listing: the lists come from the data of the repository (apt, limits, krew plugins,
# VSCodium extensions, the pipx spec file, which a fixture links and never copies), the installed sets are derived from
# them, and the extension ids of the .vsix archives are synthetic.
#
# Provides:
#   dt_script_data_files DIR     write the data that the fixtures and the expected messages use, one file each:
#                                apt.txt, limits (two numbers), krews-linux.txt, krews-darwin.txt, vscodium.txt, venvs.txt
#   dt_script_fixture NAME DIR   build the fixture NAME (a name of the cases below) into DIR; needs DT_DATA_DIR, the directory
#                                of dt_script_data_files. The fixture directory is what `dt_harness_run -f` takes.
#
# Names: prereq-ok prereq-missing, limits-match limits-absent limits-old limits-inf, decrypt-present decrypt-absent,
# brew-ok brew-drift brew-norust brew-nofile, pipx-ok pipx-missing pipx-nospec pipx-shim, krew-ok krew-miss krew-nokrew krew-ok4,
# vim-ok vim-fails vim-novundle vim-ycm-missing vim-ycm-built, vs-base vs-missing vs-newvsix vs-case vs-fbname vs-badzip
# vs-both vs-listfail vs-fail vs-novsix, st-apt st-pipx st-krew st-codium (the stateful ones: the stub tools keep their state in
# the scratch home, which dt_harness_run -K reuses for a second run).

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"

# The extension id that the .vsix archives of the fixtures hold, and the one that is not an archive.
DT_VSIX_ID=demopub.local-ext
DT_VSIX_BAD=acme.tool

dt_script_data_files() {
  local dir=${1:?dt_script_data_files DIR} jq_bin soft hard
  jq_bin=${DT_TOOL_JQ:-$(dt_find_tool jq)} || return 2
  mkdir -p -- "$dir"
  dt_script_data '.packages.linux.apt' | "$jq_bin" -r '.[]' > "$dir/apt.txt"
  read -r soft hard < <(dt_script_data '.system.limits.nofile' | "$jq_bin" -r '[.soft, .hard] | @tsv')
  printf '%s %s\n' "$soft" "$hard" > "$dir/limits"
  dt_script_data '(concat (default (list) (dig "common" "krews" (list) .packages)) (default (list) (dig "linux" "krews" (list) .packages))) | uniq | sortAlpha' \
    | "$jq_bin" -r '.[]' > "$dir/krews-linux.txt"
  dt_script_data '(concat (default (list) (dig "common" "krews" (list) .packages)) (default (list) (dig "darwin" "krews" (list) .packages))) | uniq | sortAlpha' \
    | "$jq_bin" -r '.[]' > "$dir/krews-darwin.txt"
  dt_script_data '.vscodium.extensions' | "$jq_bin" -r '.[]' > "$dir/vscodium.txt"
  "$jq_bin" -r '.venvs | keys[]' "$(dt_source_file dot_config/pipx/packages.json)" | LC_ALL=C sort > "$dir/venvs.txt"
}

# _dtf_exec FILE: standard input becomes an executable responder (mode 0700: the stub tests -x)
_dtf_exec() {
  cat > "$1"
  chmod 0700 "$1"
}

# _dtf_brew DIR: the brew responder, with the answers of `brew file`, `brew list --cask` and `brew completions`
_dtf_brew() {
  _dtf_exec "$1/brew" << 'EOF'
#!/bin/sh
d=$(dirname "$0")
case "$*" in
  "file version") echo "brew-file fixture"; exit 0 ;;
  "file clean --dry-run")
    printf '##################\n# This is dry run.\n##################\n\n'
    [ -f "$d/undeclared" ] && cat "$d/undeclared"
    printf '$ brew cleanup\n$ rm -rf /cache\n'; exit 0 ;;
  "list --cask") [ -f "$d/casks" ] && cat "$d/casks"; exit 0 ;;
  "completions state")
    if [ -f "$d/linked" ]; then echo 'Completions are linked.'; else echo 'Completions are not linked.'; fi
    exit 0 ;;
  "bundle"*) cat > "$HOME/bundle.in"; exit 0 ;;
esac
exit 0
EOF
}

_dtf_brewfile() {
  mkdir -p -- "$1/userhome/.config/brewfile"
  printf 'tap acme/tap\nbrew foo\nbrew acme/tap/bar\ncask baz\n' > "$1/userhome/.config/brewfile/Brewfile"
}

_dtf_pipx() {
  _dtf_exec "$1/pipx" << 'EOF'
#!/bin/sh
d=$(dirname "$0")
case "$1" in
  list) cat "$d/installed.txt" ;;
  install-all) cp "$2" "$HOME/captured.json"; ls -d "$(dirname "$2")" > "$HOME/captured.dir" ;;
esac
exit 0
EOF
}

_dtf_spec_link() {
  mkdir -p -- "$1/userhome/.config/pipx"
  ln -s -- "$(dt_source_file dot_config/pipx/packages.json)" "$1/userhome/.config/pipx/packages.json"
}

_dtf_kubectl() {
  _dtf_exec "$1/kubectl" << 'EOF'
#!/bin/sh
d=$(dirname "$0")
[ "$1" = krew ] || exit 0
case "$2" in
  version) [ -f "$d/nokrew" ] && exit 1; echo "krew fixture"; exit 0 ;;
  list) cat "$d/installed.txt" ;;
esac
exit 0
EOF
}

# _dtf_vim DIR: a vimrc, the links that the apply makes (~/.vimrc and ~/.vim), and the Vundle directory
_dtf_vim() {
  mkdir -p -- "$1/userhome/.config/vim/bundle/Vundle.vim"
  printf '" vimrc fixture\n' > "$1/userhome/.config/vim/vimrc"
  ln -s .config/vim "$1/userhome/.vim"
  ln -s .config/vim/vimrc "$1/userhome/.vimrc"
}

# _dtf_vsix FILE ID: a .vsix (a zip with extension/package.json); an empty ID makes a text file instead
_dtf_vsix() {
  local py3 publisher name
  py3=$(dt_find_tool python3) || return 2
  if [ -n "$2" ]; then
    publisher=${2%%.*}
    name=${2#*.}
    "$py3" -c 'import sys, zipfile, json; z = zipfile.ZipFile(sys.argv[1], "w"); z.writestr("extension/package.json", json.dumps({"publisher": sys.argv[2], "name": sys.argv[3], "version": "1.0.0"})); z.close()' "$1" "$publisher" "$name"
  else
    printf 'not an archive\n' > "$1"
  fi
}

# _dtf_codium DIR: a codium responder that lists installed.txt, fails the installs named in failing.txt, and fails
# the listing when the file listfail exists; unzip is the real one, behind its stub
_dtf_codium() {
  local unzip_bin
  unzip_bin=$(dt_find_tool unzip) || return 2
  _dtf_exec "$1/codium" << 'EOF'
#!/bin/sh
d=$(dirname "$0")
case "$1" in
  --list-extensions) [ -f "$d/listfail" ] && exit 1; cat "$d/installed.txt" ;;
  --install-extension) if [ -f "$d/failing.txt" ] && grep -qxF "$2" "$d/failing.txt"; then exit 1; fi ;;
esac
exit 0
EOF
  printf '#!/bin/sh\nexec %q "$@"\n' "$unzip_bin" | _dtf_exec "$1/unzip"
}

# _dtf_drop FILE LINE: the file without that line
_dtf_drop() {
  local tmp
  tmp=$(grep -v -x -F -e "$2" "$1" || true)
  printf '%s\n' "$tmp" > "$1"
}

dt_script_fixture() {
  local name=${1:?dt_script_fixture NAME} d=${2:?dt_script_fixture DIR}
  local data=${DT_DATA_DIR:?DT_DATA_DIR is not set} soft hard first last e1 e2 extra
  rm -rf -- "$d"
  mkdir -p -- "$d/userhome"
  chmod 0700 -- "$d"
  read -r soft hard < "$data/limits"
  first=$(head -n 1 "$data/apt.txt")
  last=$(tail -n 1 "$data/apt.txt")
  case $name in
    prereq-ok)
      _dtf_exec "$d/dpkg-query" << 'EOF'
#!/bin/sh
printf "ii "
EOF
      ;;
    prereq-missing)
      printf '%s\n%s\n' "$first" "$last" > "$d/missing.txt"
      _dtf_exec "$d/dpkg-query" << 'EOF'
#!/bin/sh
for last; do :; done
grep -qxF "$last" "$(dirname "$0")/missing.txt" && exit 1
printf "ii "
EOF
      ;;
    limits-match) printf '* soft nofile %s\n* hard nofile %s\n' "$soft" "$hard" > "$d/userhome/ulimit.conf" ;;
    limits-absent) ;;
    limits-old) printf '* soft nofile %s\n* hard nofile %s\n' "$((soft / 2))" "$((hard / 2))" > "$d/userhome/ulimit.conf" ;;
    limits-inf) printf '* soft nofile unlimited\n* hard nofile %s\n' "$hard" > "$d/userhome/ulimit.conf" ;;
    decrypt-present)
      mkdir -p -- "$d/userhome/.config/chezmoi"
      printf 'placeholder\n' > "$d/userhome/.config/chezmoi/key.age"
      ;;
    decrypt-absent)
      _dtf_exec "$d/chezmoi" << 'EOF'
#!/bin/sh
# fixture for "chezmoi age decrypt --output F --passphrase S": record the umask, create F
out=
while [ $# -gt 0 ]; do [ "$1" = --output ] && out=$2; shift; done
printf 'umask=%s\n' "$(umask)" > "${out}.fixture-log"
: > "$out"
EOF
      ;;
    brew-ok | brew-drift | brew-norust | brew-nofile)
      _dtf_brew "$d"
      if [ "$name" = brew-nofile ]; then
        mkdir -p -- "$d/userhome/.config/brewfile"
      else
        _dtf_brewfile "$d"
      fi
      printf '#!/bin/sh\nexit %s\n' "$([ "$name" = brew-norust ] && echo 1 || echo 0)" | _dtf_exec "$d/gh"
      if [ "$name" = brew-norust ]; then
        printf '#!/bin/sh\n[ "$*" = default ] && echo "no default toolchain is configured"\nexit 0\n' | _dtf_exec "$d/rustup"
      else
        printf '#!/bin/sh\n[ "$*" = default ] && echo "stable-x86_64-unknown-linux-gnu (default)"\nexit 0\n' | _dtf_exec "$d/rustup"
      fi
      case $name in
        brew-ok | brew-norust) printf 'baz\n' > "$d/casks" ;;
        brew-drift)
          printf 'baz\nwhosthere\n' > "$d/casks"
          printf '$ brew uninstall --ignore-dependencies oldtool othertool\n$ brew untap acme/oldtap\n' > "$d/undeclared"
          ;;
      esac
      ;;
    pipx-ok | pipx-missing | pipx-nospec | pipx-shim)
      _dtf_pipx "$d"
      case $name in
        pipx-ok | pipx-nospec) sed 's/$/ 1.0/' "$data/venvs.txt" > "$d/installed.txt" ;;
        pipx-missing | pipx-shim)
          tail -n +4 "$data/venvs.txt" | sed 's/$/ 1.0/' > "$d/installed.txt"
          printf 'unlistedtool 2.0\na.c 1\n' >> "$d/installed.txt"
          ;;
      esac
      [ "$name" = pipx-nospec ] || _dtf_spec_link "$d"
      if [ "$name" = pipx-shim ]; then
        # a jq that exists only as a mise shim under the scratch home: found through use_tool_dirs
        mkdir -p -- "$d/userhome/.local/share/mise/shims"
        printf '#!/bin/sh\nexec %q "$@"\n' "$(dt_find_tool jq)" > "$d/userhome/.local/share/mise/shims/jq"
        chmod 0755 "$d/userhome/.local/share/mise/shims/jq"
      fi
      ;;
    krew-ok | krew-miss | krew-nokrew | krew-ok4)
      _dtf_kubectl "$d"
      case $name in
        krew-ok) cp "$data/krews-linux.txt" "$d/installed.txt" ;;
        krew-ok4) cp "$data/krews-darwin.txt" "$d/installed.txt" ;;
        krew-miss)
          # the declared plugins without the first and the last, an undeclared one, and krew itself
          sed '1d;$d' "$data/krews-linux.txt" > "$d/installed.txt"
          printf 'extraplugin\nkrew\n' >> "$d/installed.txt"
          ;;
        krew-nokrew)
          head -n 1 "$data/krews-linux.txt" > "$d/installed.txt"
          : > "$d/nokrew"
          ;;
      esac
      ;;
    vim-ok | vim-fails | vim-novundle | vim-ycm-missing | vim-ycm-built)
      _dtf_vim "$d"
      case $name in
        vim-fails) printf '#!/bin/sh\nexit 1\n' | _dtf_exec "$d/vim" ;;
        vim-novundle) rmdir "$d/userhome/.config/vim/bundle/Vundle.vim" ;;
        vim-ycm-missing)
          mkdir -p -- "$d/userhome/.config/vim/bundle/YouCompleteMe/third_party/ycmd"
          : > "$d/userhome/.config/vim/bundle/YouCompleteMe/install.py"
          ;;
        vim-ycm-built)
          mkdir -p -- "$d/userhome/.config/vim/bundle/YouCompleteMe/third_party/ycmd"
          : > "$d/userhome/.config/vim/bundle/YouCompleteMe/install.py"
          : > "$d/userhome/.config/vim/bundle/YouCompleteMe/third_party/ycmd/ycm_core.cpython-313-x86_64-linux-gnu.so"
          ;;
      esac
      ;;
    vs-*)
      mkdir -p -- "$d/userhome/.local/share/vsix"
      _dtf_codium "$d"
      e1=$(sed -n 2p "$data/vscodium.txt")
      e2=$(sed -n 6p "$data/vscodium.txt")
      cp "$data/vscodium.txt" "$d/installed.txt"
      _dtf_vsix "$d/userhome/.local/share/vsix/$DT_VSIX_ID-0.1.2.vsix" "$DT_VSIX_ID"
      printf '%s\n' "$DT_VSIX_ID" >> "$d/installed.txt"
      case $name in
        vs-base) ;;
        vs-missing) _dtf_drop "$d/installed.txt" "$e1"; _dtf_drop "$d/installed.txt" "$e2" ;;
        vs-newvsix) _dtf_drop "$d/installed.txt" "$DT_VSIX_ID" ;;
        vs-case) sed -i "s/^$DT_VSIX_ID\$/Demopub.Local-Ext/" "$d/installed.txt" ;;
        vs-fbname)
          rm -f -- "$d"/userhome/.local/share/vsix/*.vsix
          _dtf_vsix "$d/userhome/.local/share/vsix/other.name-1.0.vsix" "$DT_VSIX_ID"
          ;;
        vs-badzip)
          rm -f -- "$d"/userhome/.local/share/vsix/*.vsix
          _dtf_vsix "$d/userhome/.local/share/vsix/$DT_VSIX_BAD-2.0.1.vsix" ''
          printf '%s\n' "$DT_VSIX_BAD" >> "$d/installed.txt"
          ;;
        vs-both) _dtf_drop "$d/installed.txt" "$e1"; _dtf_drop "$d/installed.txt" "$DT_VSIX_ID" ;;
        vs-listfail) : > "$d/listfail" ;;
        vs-fail)
          _dtf_drop "$d/installed.txt" "$e1"
          _dtf_drop "$d/installed.txt" "$e2"
          printf '%s\n' "$e1" > "$d/failing.txt"
          ;;
        vs-novsix) rm -rf -- "$d/userhome/.local/share/vsix" ;;
        *) printf 'dt_script_fixture: unknown fixture %s\n' "$name" >&2; return 2 ;;
      esac
      ;;
    st-apt)
      # the stateful fixtures keep their state in the scratch home: the files below are what the second run reads
      sed -n '1,$p' "$data/apt.txt" | grep -v -x -F -e "$first" -e "$last" > "$d/userhome/dpkg.txt"
      _dtf_exec "$d/dpkg-query" << 'EOF'
#!/bin/sh
for last; do :; done
grep -qxF "$last" "$HOME/dpkg.txt" && printf 'ii ' || exit 1
EOF
      _dtf_exec "$d/apt-get" << 'EOF'
#!/bin/sh
[ "$1" = install ] || exit 0
shift
for a; do case "$a" in -*) ;; *) echo "$a" >> "$HOME/dpkg.txt" ;; esac; done
exit 0
EOF
      ;;
    st-pipx)
      _dtf_spec_link "$d"
      _dtf_exec "$d/pipx" << 'EOF'
#!/bin/sh
case "$1" in
  list) cat "$HOME/installed.txt" ;;
  install-all) jq -r '.venvs | keys[]' "$2" | sed 's/$/ 1.0/' >> "$HOME/installed.txt" ;;
esac
exit 0
EOF
      tail -n +4 "$data/venvs.txt" | sed 's/$/ 1.0/' > "$d/userhome/installed.txt"
      ;;
    st-krew)
      sed '1d;$d' "$data/krews-linux.txt" > "$d/userhome/krew.txt"
      _dtf_exec "$d/kubectl" << 'EOF'
#!/bin/sh
[ "$1" = krew ] || exit 0
case "$2" in
  version) echo krew ;;
  list) cat "$HOME/krew.txt" ;;
  install) shift 2; printf '%s\n' "$@" >> "$HOME/krew.txt" ;;
esac
exit 0
EOF
      ;;
    st-codium)
      mkdir -p -- "$d/userhome/.local/share/vsix"
      tail -n +3 "$data/vscodium.txt" > "$d/userhome/ext.txt"
      _dtf_vsix "$d/userhome/.local/share/vsix/$DT_VSIX_ID-0.1.2.vsix" "$DT_VSIX_ID"
      extra=$(dt_find_tool unzip) || return 2
      _dtf_exec "$d/codium" << EOF
#!/bin/sh
case "\$1" in
  --list-extensions) cat "\$HOME/ext.txt" ;;
  --install-extension)
    case "\$2" in
      *.vsix) $extra -p "\$2" extension/package.json | jq -r '.publisher + "." + .name' >> "\$HOME/ext.txt" ;;
      *) echo "\$2" >> "\$HOME/ext.txt" ;;
    esac ;;
esac
exit 0
EOF
      printf '#!/bin/sh\nexec %q "$@"\n' "$extra" | _dtf_exec "$d/unzip"
      ;;
    *)
      printf 'dt_script_fixture: unknown fixture %s\n' "$name" >&2
      return 2
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn=${1:?usage: script-fixtures.sh <function> [args...]}
  shift
  "$fn" "$@"
fi
