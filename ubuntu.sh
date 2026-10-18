#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y docker.io docker-compose-v2 lazygit wireguard-tools
sudo usermod -aG docker "$USER"

[ -x ~/.local/bin/mise ] || curl -fsSL https://mise.run/bash | sh
~/.local/bin/mise use -g gh kubectl k9s yazi lazydocker

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com
