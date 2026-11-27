#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y btop docker.io docker-compose-v2 ffmpeg jq lazygit systemd-zram-generator unzip wakeonlan wireguard-tools
sudo usermod -aG docker "$USER"
if [[ ! -f /etc/docker/daemon.json ]]; then
	echo '{"bip":"10.200.0.1/24","default-address-pools":[{"base":"10.201.0.0/16","size":24}]}' |
		sudo tee /etc/docker/daemon.json >/dev/null
fi
sudo systemctl restart docker
sudo timedatectl set-timezone Asia/Bangkok
sudo loginctl enable-linger "$USER"

sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = min(ram / 2, 16384)
compression-algorithm = zstd
swap-priority = 100
EOF
if ! swapon --show=NAME --noheadings | grep -qx /dev/zram0; then
	sudo systemctl daemon-reload
	sudo systemctl restart systemd-zram-setup@zram0.service
	sudo systemctl start dev-zram0.swap
fi

sudo tee /etc/sysctl.d/99-zram-memory.conf >/dev/null <<'EOF'
vm.swappiness = 150
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
sudo sysctl --system >/dev/null

mkdir -p ~/.gradle
if [[ ! -f ~/.gradle/gradle.properties ]]; then
	cat <<'EOF' >~/.gradle/gradle.properties
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g
org.gradle.daemon.idletimeout=300000
org.gradle.workers.max=8
EOF
fi

[ -x ~/.local/bin/mise ] || curl -fsSL https://mise.run/bash | sh
PATH=~/.local/bin:$PATH
mise use -g gh kubectl k9s yazi lazydocker pnpm
mise settings experimental=true
mise settings minimum_release_age=0
mise settings add idiomatic_version_file_enable_tools node
mise settings npm.package_manager=npm

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com
