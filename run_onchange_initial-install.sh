#!/usr/bin/env bash

type brew &>/dev/null || \
  bash -c "$(curl -fsSL https://raw.github.com/rcmdnk/homebrew-file/install/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

if [ -f "$(brew --prefix)/etc/brew-wrap" ];then
  # shellcheck disable=SC1091
  source "$(brew --prefix)/etc/brew-wrap"
fi

brew file install

pipx install-all "$HOME/.local/pipx/packages.json"

#brew install \
#  mise \
#  helix \
#  tmux \
#  jq \
#  ripgrep \
#  fd \
#  direnv \

