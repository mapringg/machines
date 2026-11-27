#!/usr/bin/env bash
set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

t3_deb=$(curl -fsSL https://api.github.com/repos/pingdotgg/t3code/releases/latest |
	jq -r '.assets[] | select(.name | endswith("-amd64.deb")) | .browser_download_url')

curl -fsSL "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -o "$tmp/chrome.deb"
curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" -o "$tmp/vscode.deb"
curl -fsSL "https://downloads.1password.com/linux/debian/amd64/stable/1password-latest.deb" -o "$tmp/1password.deb"
curl -fsSL "https://app.warp.dev/download?package=deb" -o "$tmp/warp.deb"
curl -fsSL "$t3_deb" -o "$tmp/t3-code.deb"

sudo apt update
sudo apt install -y "$tmp/chrome.deb" "$tmp/vscode.deb" "$tmp/1password.deb" "$tmp/warp.deb" "$tmp/t3-code.deb"

curl -fsSL "https://github.com/paper-design/paper-mono/releases/download/v1.000/paper-mono-v1.000.zip" -o "$tmp/paper-mono.zip"
echo "8642652985dc87bf4cfd07c89942899e611c3c774fc25284c0dd4fe86a993a13  $tmp/paper-mono.zip" | sha256sum -c -
unzip -qo "$tmp/paper-mono.zip" -d "$tmp/paper-mono"
mkdir -p ~/.local/share/fonts/paper-mono
cp "$tmp"/paper-mono/paper-mono-v1.000/fonts/ttf/*.ttf ~/.local/share/fonts/paper-mono/
fc-cache -f
