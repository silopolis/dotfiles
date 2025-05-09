#!/bin/bash

echo "-- Update APT package sources"
sudo apt update

echo "-- Upgrade Debian packages"
sudo apt -V upgrade \
    && sudo apt -V full-upgrade \
    && sudo apt autoremove \
    && sudo apt clean

echo "-- Update Brew package sources"
brew update -v \
    && echo "-- Upgrade Brew packages" \
    && brew upgrade

echo "-- Upgrade pipx packages"
pipx upgrade-all --include-injected

echo "-- Update Flatpack packages"
flatpak update

#echo "-- Update Snap packages"
#snap refresh
echo "--Update gh CLI extensions"
gh extensions update --all

echo "-- Clean disabled Snap packages"
snap-clean

echo "-- Clean up Journal"
sudo journalctl --vacuum-size=256M

