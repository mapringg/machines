#!/usr/bin/env bash
set -euo pipefail

export NONINTERACTIVE=1
unset HOMEBREW_ASK

[ -x /opt/homebrew/bin/brew ] || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
/opt/homebrew/bin/brew install btop ffmpeg jq lazygit mise
/opt/homebrew/bin/brew install --cask --adopt visual-studio-code google-chrome wispr-flow 1password tailscale-app t3-code grok-bot warp font-paper-mono
for k in ComputerName HostName LocalHostName; do sudo scutil --set $k apple; done
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15

PATH=/opt/homebrew/bin:$PATH
mise use -g gh kubectl k9s yazi lazydocker pnpm
mise settings experimental=true
mise settings minimum_release_age=0
mise settings add idiomatic_version_file_enable_tools node
mise settings npm.package_manager=npm
touch ~/.zshrc
grep -q 'mise activate zsh' ~/.zshrc || echo 'eval "$(/opt/homebrew/bin/mise activate zsh)"' >>~/.zshrc

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com
