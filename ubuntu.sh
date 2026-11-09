#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y btop docker.io docker-compose-v2 ffmpeg lazygit unzip wireguard-tools
sudo usermod -aG docker "$USER"
sudo timedatectl set-timezone Asia/Bangkok

[ -x ~/.local/bin/mise ] || curl -fsSL https://mise.run/bash | sh
PATH=~/.local/bin:$PATH
mise use -g gh kubectl k9s yazi lazydocker pnpm
mise settings experimental=true
mise settings minimum_release_age=0
mise settings add idiomatic_version_file_enable_tools node
mise settings npm.package_manager=npm
mise use -g 'npm:obsidian-headless[postinstall=cd $MISE_TOOL_INSTALL_PATH/lib/node_modules/obsidian-headless && npm rebuild better-sqlite3]'

mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/obsidian-sync.service <<'EOF'
[Unit]
Description=Obsidian Sync for ~/vault
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=%h/.local/bin/mise x -- ob sync --continuous --path %h/vault
Restart=on-failure
RestartSec=30

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload

[ -x ~/.opencode/bin/opencode ] || curl -fsSL https://opencode.ai/v2/install | bash

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com
