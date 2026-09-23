#!/usr/bin/env bash
# macbook.sh — MacBook Air M3, user mapring, hostname `macbook`
# macOS 27, stock. Thin client: all development happens on `ubuntu` over
# Tailscale, so nothing here is a development environment. Safe to re-run.
#
# MANUAL STEPS — do these first, they can't be scripted:
#   Bootstrap  the repo is private and this machine has no key yet, so the
#              script cannot be fetched with curl. Order that works from bare
#              metal, needing nothing but a browser:
#                1. Setup Assistant, sign in to iCloud
#                2. Safari -> 1password.com, install, sign in (Emergency Kit
#                   has the Secret Key — have it before erasing)
#                3. Safari -> tailscale.com, install, sign in
#                4. scp ubuntu:Work/mapringg/machines/macbook.sh ~/ && ~/macbook.sh
#              Tailscale SSH means step 4 needs no key. brew then adopts the two
#              apps installed by hand rather than colliding with them.
#   Finder     ⌘2 for list view, then ⌘J → Date Created and Show Library Folder
#              on, relative dates and Calculate all sizes off → Use as Defaults.
#              Per-folder views live in .DS_Store and override the default, so
#              `find ~ -name .DS_Store -type f -delete` if an old one wins.
#              FXPreferredViewStyle and AlwaysOpenWindowsInListView are no-ops
#              on macOS 27 — they look like they should work and don't.
#   Log out    key repeat only applies to a new login session.
set -euo pipefail

# --- command line tools -------------------------------------------------------
xcode-select -p >/dev/null 2>&1 || xcode-select --install

# --- Homebrew and apps --------------------------------------------------------
# brew earns its place only because without it this script cannot install a
# single application, and four manual downloads is the friction it exists to
# remove. Nothing else uses it — there is no development toolchain on this
# machine. The 1Password Safari extension ships inside the 1Password app.
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

brew install --cask --adopt 1password tailscale visual-studio-code

# --- Claude Code --------------------------------------------------------------
command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash

# --- dotfiles -----------------------------------------------------------------
cat > ~/.zshrc <<'ZSHRC'
export PATH="$HOME/.local/bin:$PATH"
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
ZSHRC

git config --global user.name mapringg
git config --global user.email work@mapringg.com

# Tailscale SSH means no host keys to manage, so this is only about not leaving
# a connection hanging when the link drops. tmux on the far end does the rest.
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat > ~/.ssh/config <<'SSHCONFIG'
Host ubuntu
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
# Typing: the stock key repeat is far too slow for terminal work, and the
# automatic substitutions corrupt code and commit messages.
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Finder: show what's actually there.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # search this folder, not the Mac
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
chflags nohidden "$HOME/Library"

# Screenshots land in ~/Screenshots instead of burying the Desktop.
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false

sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

killall Finder SystemUIServer Dock
