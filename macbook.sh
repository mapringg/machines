#!/usr/bin/env bash
set -euo pipefail

sudo scutil --set ComputerName macbook
sudo scutil --set LocalHostName macbook
sudo scutil --set HostName macbook

if [ ! -x /opt/homebrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

brew install --cask --adopt visual-studio-code t3-code@nightly

code --install-extension ms-vscode-remote.remote-ssh

mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat > ~/.ssh/config <<'SSHCONFIG'
Host ubuntu ubuntu.*.ts.net
    HostName ubuntu
    User mapring
    ServerAliveInterval 30
    ServerAliveCountMax 6
SSHCONFIG
chmod 600 ~/.ssh/config

defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
