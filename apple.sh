#!/usr/bin/env bash
set -euo pipefail

[ -x /opt/homebrew/bin/brew ] || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
/opt/homebrew/bin/brew install --cask --adopt visual-studio-code google-chrome wispr-flow 1password tailscale-app
for k in ComputerName HostName LocalHostName; do sudo scutil --set $k apple; done
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15
