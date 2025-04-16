#!/usr/bin/env bash
set -euo pipefail

type brew &>/dev/null || \
  bash -c "$(curl -fsSL https://raw.github.com/rcmdnk/homebrew-file/install/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

if [ -f "$(brew --prefix)/etc/brew-wrap" ];then
  # shellcheck disable=SC1091
  source "$(brew --prefix)/etc/brew-wrap"
fi

brew file install

#brew install \
#  mise \
#  helix \
#  tmux \
#  jq \
#  ripgrep \
#  fd \
#  direnv \


# {{ include "dot_config/mise/config.toml" | sha256sum }}

#mise plugins install --all --yes
#
#mise install
#
#for SH in bash fish; do
#    mise activate --shell "$SH" > ~/.config/"$SH"/conf.d/mise."$SH"
#    mise complete --shell "$SH" > ~/.config/"$SH"/completions/mise."$SH"
#done
#
#mkdir -p  ~/.config/direnv/lib
#mise direnv >~/.config/direnv/lib/use_mise.sh
#ln -snf ~/.config/direnv/lib/use_mise.sh ~/.config/direnv/lib/use_rtx.sh
#
#mise plugins install --force \
#    pdm \
#    php \
#    pnpm

pipx install-all "$HOME/.local/pipx/packages.json"

