#!/bin/bash
# Upgrade system (APT) and user-level package managers.
# A failing step doesn't stop the others: failures are listed at the end
# and reflected in the exit code.
set -uo pipefail
#set -x

failed=()

# run <description> <command...>
run() {
  local desc=$1
  shift
  echo "-- ${desc}"
  if ! "$@"; then
    echo "!! ${desc} failed" >&2
    failed+=("${desc}")
    return 1
  fi
}

# has <command>: true if available, otherwise say so
has() {
  command -v "$1" >/dev/null && return 0
  echo "-- $1 not available"
  return 1
}

run "Update APT package sources" sudo apt update &&
  run "Upgrade Debian packages" sudo apt -V upgrade &&
  run "Full-upgrade Debian packages" sudo apt -V full-upgrade &&
  run "Remove unused Debian packages" sudo apt autoremove &&
  run "Clean APT cache" sudo apt clean

if has mise; then
  run "Upgrade mise packages" mise upgrade
fi

if has brew; then
  run "Update brew package sources" brew update -v &&
    run "Upgrade brew packages" brew upgrade
fi

if has pipx; then
  run "Upgrade pipx packages" pipx upgrade-all --include-injected
fi

if has bin; then
  run "Upgrade bin managed packages" bin update --all --continue-on-error
fi

if has flatpak; then
  run "Update Flatpak packages" flatpak update
fi

if has snap; then
  run "Update Snap packages" snap refresh &&
    run "Clean disabled Snap packages" snap-clean
fi

if has gh; then
  run "Upgrade gh CLI extensions" gh extensions upgrade --all
fi

run "Clean up Journal" sudo journalctl --vacuum-size=256M

if ((${#failed[@]})); then
  echo
  echo "!! ${#failed[@]} step(s) failed:" >&2
  printf '   - %s\n' "${failed[@]}" >&2
  exit 1
fi
echo "-- All done"
