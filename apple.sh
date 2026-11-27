#!/usr/bin/env bash
set -euo pipefail

export NONINTERACTIVE=1
unset HOMEBREW_ASK

sudo -v
(while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null || break; sleep 50; done) </dev/null >/dev/null 2>&1 &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

[ -x /opt/homebrew/bin/brew ] || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
touch ~/.zprofile
grep -q 'brew shellenv' ~/.zprofile || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile

/opt/homebrew/bin/brew install btop dockutil ffmpeg jq lazygit mise
/opt/homebrew/bin/brew install --cask --adopt visual-studio-code google-chrome wispr-flow 1password t3-code grok-bot warp orbstack font-paper-mono
[[ -d /Applications/Tailscale.app ]] || /opt/homebrew/bin/brew install --cask --adopt tailscale-app

for k in ComputerName HostName LocalHostName; do sudo scutil --set $k apple; done
defaults delete -g AppleInterfaceStyleSwitchesAutomatically 2>/dev/null || true
defaults write -g AppleInterfaceStyle -string Dark
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15
defaults write com.apple.dock show-recents -bool false
sudo pmset -c sleep 0 displaysleep 5

/opt/homebrew/bin/dockutil --remove all --no-restart || true
for app in "/Applications/Google Chrome.app" "/Applications/Grok Bot.app" /Applications/T3\ Code*.app "/Applications/Warp.app"; do
	[[ -d "$app" ]] && /opt/homebrew/bin/dockutil --add "$app" --no-restart
done
killall Dock || true

if [[ -f "/System/Library/Desktop Pictures/Solid Colors/Black.png" ]]; then
	osascript -e 'tell application "System Events" to tell every desktop to set picture to "/System/Library/Desktop Pictures/Solid Colors/Black.png"' ||
		echo "apple.sh: could not set wallpaper over SSH; set Solid Black in System Settings -> Wallpaper" >&2
fi

PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
mise use -g gh kubectl k9s yazi lazydocker pnpm
mise settings experimental=true
mise settings minimum_release_age=0
mise settings add idiomatic_version_file_enable_tools node
mise settings npm.package_manager=npm
touch ~/.zshrc
grep -q 'mise activate zsh' ~/.zshrc || echo 'eval "$(/opt/homebrew/bin/mise activate zsh)"' >>~/.zshrc

[[ -x /usr/local/bin/tailscale ]] && /usr/local/bin/tailscale set --accept-routes || true

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com

echo "=== VERIFY apple ==="
defaults read -g AppleInterfaceStyle
defaults read -g KeyRepeat
pmset -g custom | grep -E 'displaysleep|sleep ' | head -n 4 || true
/opt/homebrew/bin/dockutil --list | awk -F'\t' '{print $1}'
