#!/usr/bin/env bash
set -euo pipefail

sudo scutil --set ComputerName macbook
sudo scutil --set LocalHostName macbook
sudo scutil --set HostName macbook

xcode-select -p >/dev/null 2>&1 || xcode-select --install

if [ ! -x /opt/homebrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

brew install --cask --adopt tailscale visual-studio-code handy t3-code@nightly

code --install-extension ms-vscode-remote.remote-ssh

command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash

cat > ~/.zshrc <<'ZSHRC'
export PATH="$HOME/.local/bin:$PATH"
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export T3CODE_TELEMETRY_ENABLED=false
ZSHRC

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com

mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat > ~/.ssh/config <<'SSHCONFIG'
Host ubuntu ubuntu.*.ts.net
    HostName ubuntu
    User mapring
    ServerAliveInterval 30
    ServerAliveCountMax 6
    SendEnv -LC_*
    SendEnv -LANG
SSHCONFIG
chmod 600 ~/.ssh/config

touch ~/.hushlogin

defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
chflags nohidden "$HOME/Library"

mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false

sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

killall Finder SystemUIServer Dock
