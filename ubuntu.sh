#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y docker.io docker-compose-v2 lazygit wireguard-tools
sudo usermod -aG docker "$USER"
sudo timedatectl set-timezone Asia/Bangkok

[ -x ~/.local/bin/mise ] || curl -fsSL https://mise.run/bash | sh
~/.local/bin/mise use -g gh kubectl k9s claude codex yazi lazydocker pnpm
~/.local/bin/mise settings add idiomatic_version_file_enable_tools node
~/.local/bin/mise settings npm.package_manager=npm
~/.local/bin/mise use -g 'npm:obsidian-headless[postinstall=cd $MISE_TOOL_INSTALL_PATH/lib/node_modules/obsidian-headless && npm rebuild better-sqlite3]'

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

[ -x ~/.local/bin/t3 ] || curl -fsSL https://t3.codes/install.sh | T3CODE_CHANNEL=nightly sh
~/.local/bin/t3 service install
sudo ~/.local/bin/t3 browser setup

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com
