#!/usr/bin/env bash
set -euo pipefail

sudo scutil --set ComputerName macbook
sudo scutil --set LocalHostName macbook
sudo scutil --set HostName macbook

if [ ! -x /opt/homebrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

rm -rf "$HOMEBREW_PREFIX/Caskroom/tailscale" "$HOMEBREW_PREFIX/Caskroom/tailscale-app"
brew install --cask --adopt visual-studio-code handy t3-code@nightly

code --install-extension ms-vscode-remote.remote-ssh

rm -rf ~/.local/bin/claude ~/.local/share/claude
rm -f ~/.zshrc ~/.hushlogin

git config --global --remove-section user 2>/dev/null || true
[ -s ~/.gitconfig ] || rm -f ~/.gitconfig

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

reset() { defaults delete "$1" "$2" 2>/dev/null || true; }
reset NSGlobalDomain NSAutomaticCapitalizationEnabled
reset NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled
reset NSGlobalDomain NSAutomaticDashSubstitutionEnabled

reset NSGlobalDomain AppleShowAllExtensions
reset com.apple.finder AppleShowAllFiles
reset com.apple.finder FXDefaultSearchScope
reset com.apple.finder ShowPathbar
reset com.apple.finder ShowStatusBar
reset com.apple.finder StandardViewSettings
reset com.apple.finder FXPreferredViewStyle
chflags hidden "$HOME/Library"

reset com.apple.screencapture location
rmdir "$HOME/Screenshots" 2>/dev/null || true

reset com.apple.dock autohide
reset com.apple.dock show-recents

sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

killall Finder SystemUIServer Dock
