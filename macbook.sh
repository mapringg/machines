#!/usr/bin/env bash
# MacBook Air M3, hostname `macbook`. A thin client; development is on `ubuntu`.
# Do the manual steps in README first. Safe to re-run.
set -euo pipefail

# --- hostname -----------------------------------------------------------------
# Setup Assistant derives all three from the account name
sudo scutil --set ComputerName macbook
sudo scutil --set LocalHostName macbook
sudo scutil --set HostName macbook

# --- command line tools -------------------------------------------------------
xcode-select -p >/dev/null 2>&1 || xcode-select --install

# --- Homebrew and apps --------------------------------------------------------
# By path: the installer doesn't update the running shell's PATH
if [ ! -x /opt/homebrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

brew install --cask --adopt tailscale visual-studio-code handy

# For T3 Code's "Open in VS Code" links to ubuntu
code --install-extension ms-vscode-remote.remote-ssh

# --- Claude Code --------------------------------------------------------------
command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash

# --- dotfiles -----------------------------------------------------------------
cat > ~/.zshrc <<'ZSHRC'
export PATH="$HOME/.local/bin:$PATH"
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
ZSHRC

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com

# Keepalives for dropped links. T3 Code's links use the MagicDNS name, and
# would otherwise log in as the Mac's user.
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

touch ~/.hushlogin   # no "Last login:" banner on every new shell

# --- macOS defaults -----------------------------------------------------------
# Fast key repeat, and no autocorrect mangling code
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Finder: show what's actually there
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # search this folder, not the Mac
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
chflags nohidden "$HOME/Library"

# Screenshots out of the Desktop
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false

sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

killall Finder SystemUIServer Dock
