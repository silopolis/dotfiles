#!/bin/bash

set -euo pipefail
set -x

GITHUB_USER=${1:-$GITHUB_USER}

if [ $(type curl &> /dev/null) ]; then
  sudo apt-get -qy update
  sudo apt-get -qy install curl
fi


if [ $(type chezmoi &> /dev/null) ]; then
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply $GITHUB_USER
else
  chezmoi init --verbose --apply $GITHUB_USER
fi
