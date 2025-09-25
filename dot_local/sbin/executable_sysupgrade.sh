#!/bin/bash

set -euo pipefail
#set -x

echo "-- Update APT package sources"
sudo apt update

echo "-- Upgrade Debian packages"
sudo apt -V upgrade \
    && sudo apt -V full-upgrade \
    && sudo apt autoremove \
    && sudo apt clean

command -v brew > /dev/null \
  && echo "-- Update brew package sources" \
  && brew update -v \
  && echo "-- Upgrade brew packages" \
  && brew upgrade

command -v pipx > /dev/null \
  && echo "-- Upgrade pipx packages" \
  && pipx upgrade-all --include-injected \
  || echo "-- pipx package manager not available"

command -v bin > /dev/null \
  && echo "-- Upgrade bin managed packages" \
  && bin update --all --continue-on-error \
  || echo "-- bin package manager not available"

command -v flatpack > /dev/null \
  && echo "-- Update Flatpack packages" \
  && flatpak update \
  || echo "-- flatpack package manager not available"

command -v snap > /dev/null \
  && echo "-- Update Snap packages" \
  && snap refresh \
  && echo "-- Clean disabled Snap packages" \
  && snap-clean \
  || echo "-- snap package manager not available"

command -v gh > /dev/null \
  && echo "-- Update gh CLI extensions" \
  && gh extensions upgrade --all \
  || echo "-- gh command not available"

echo "-- Clean up Journal"
sudo journalctl --vacuum-size=256M

