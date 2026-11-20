#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y btop docker.io docker-compose-v2 ffmpeg lazygit unzip wireguard-tools
sudo usermod -aG docker "$USER"
if [[ ! -f /etc/docker/daemon.json ]]; then
	echo '{"bip":"10.200.0.1/24","default-address-pools":[{"base":"10.201.0.0/16","size":24}]}' |
		sudo tee /etc/docker/daemon.json >/dev/null
fi
sudo systemctl restart docker
sudo timedatectl set-timezone Asia/Bangkok

[ -x ~/.local/bin/mise ] || curl -fsSL https://mise.run/bash | sh
PATH=~/.local/bin:$PATH
mise use -g gh kubectl k9s yazi lazydocker pnpm npm:defuddle
mise settings experimental=true
mise settings minimum_release_age=0
mise settings add idiomatic_version_file_enable_tools node
mise settings npm.package_manager=npm

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com
