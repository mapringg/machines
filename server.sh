#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y docker.io lazygit
sudo usermod -aG docker "$USER"

[ -x ~/.local/bin/mise ] || curl -fsSL https://mise.run/bash | sh
~/.local/bin/mise use -g gh kubectl k9s claude codex yazi lazydocker

[ -x ~/.local/bin/t3 ] || curl -fsSL https://t3.codes/install.sh | sh
~/.local/bin/t3 service install

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com
