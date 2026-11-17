#!/usr/bin/env bash
# Fetch the pinned bats helper libraries into tests/.lib (`mise run test:deps`).
#
# tests/deps.txt lists each library with its URL, its tag and the commit the tag resolves to.
# For each line:
#   - a library already at its pinned commit is left alone, with no network call;
#   - otherwise the tag is cloned shallow into a temporary directory below tests/.lib,
#     the commit it resolves to is compared with the pinned one, and only on a match
#     the directory is moved into place;
#   - a failed fetch or a different commit removes the temporary directory and exits 1
#     with one message that names the library, the tag and, for a mismatch, both commits.
#
# The fetch is anonymous: git runs under `env -i` with a scratch home, no system or user
# configuration (so no credential helper and no rewrite rule), no terminal prompt, and none
# of the variables of the calling shell except the proxy and certificate settings that a
# network behind a proxy needs. A token variable of the shell is never sent to a host.
# Everything this script writes sits below tests/.lib, inside the repository.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
lib=$here/.lib
deps=$here/deps.txt

die() {
  printf 'deps.sh: %s\n' "$*" >&2
  exit 1
}

command -v git > /dev/null 2>&1 || die 'git is not installed'
[ -r "$deps" ] || die "cannot read $deps"
mkdir -p -- "$lib"

work=$(mktemp -d "$lib/.tmp.XXXXXX")
cleanup() {
  case $work in
    "$lib"/.tmp.*) rm -rf -- "$work" ;;
  esac
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -m 0700 -- "$work/home"

# The environment of every git call: nothing from the shell but PATH and the network settings.
envargs=(PATH="$PATH" HOME="$work/home" LANG=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0)
for v in http_proxy https_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY \
  SSL_CERT_FILE SSL_CERT_DIR CURL_CA_BUNDLE GIT_SSL_CAINFO; do
  if [ -n "${!v:-}" ]; then
    envargs+=("$v=${!v}")
  fi
done

clean_git() {
  env -i "${envargs[@]}" git -c credential.helper= "$@"
}

limit=()
if command -v timeout > /dev/null 2>&1; then
  limit=(timeout 180)
fi

while read -r name url tag commit extra; do
  case $name in
    '' | '#'*) continue ;;
  esac
  [[ $name =~ ^[a-z0-9][a-z0-9_-]*$ ]] || die "deps.txt: bad library name '$name'"
  [[ $url =~ ^https://[A-Za-z0-9._/-]+$ ]] || die "deps.txt: $name: the URL must be https"
  [[ $tag =~ ^[A-Za-z0-9._-]+$ ]] || die "deps.txt: $name: bad tag"
  [[ $commit =~ ^[0-9a-f]{40}$ ]] || die "deps.txt: $name: the commit must be 40 hexadecimal digits"
  [ -z "$extra" ] || die "deps.txt: $name: more than four fields"

  target=$lib/$name
  if [ -d "$target/.git" ]; then
    have=$(clean_git -C "$target" rev-parse HEAD 2> /dev/null || true)
    if [ "$have" = "$commit" ]; then
      printf '%s %s %s: already at the pinned commit\n' "$name" "$tag" "${commit:0:7}"
      continue
    fi
  fi

  if ! "${limit[@]}" env -i "${envargs[@]}" git -c credential.helper= clone --quiet --depth 1 --branch "$tag" -- "$url" "$work/$name" 2> "$work/err"; then
    die "$name $tag is missing and cannot be fetched: run mise run test:deps again online ($(tail -n 1 "$work/err"))"
  fi
  got=$(clean_git -C "$work/$name" rev-parse HEAD)
  if [ "$got" != "$commit" ]; then
    die "$name $tag resolves to $got but tests/deps.txt pins $commit"
  fi
  rm -rf -- "${target:?}"
  mv -- "$work/$name" "$target"
  printf '%s %s %s: fetched\n' "$name" "$tag" "${commit:0:7}"
done < "$deps"
