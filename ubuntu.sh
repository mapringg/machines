#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y docker.io docker-compose-v2 lazygit wireguard-tools
sudo usermod -aG docker "$USER"

[ -x ~/.local/bin/mise ] || curl -fsSL https://mise.run/bash | sh
~/.local/bin/mise use -g gh kubectl k9s claude codex yazi lazydocker
~/.local/bin/mise settings add idiomatic_version_file_enable_tools node

[ -x ~/.local/bin/t3 ] || curl -fsSL https://t3.codes/install.sh | T3CODE_CHANNEL=nightly sh
~/.local/bin/t3 service install
sudo ~/.local/bin/t3 browser setup

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com
