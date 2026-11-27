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
if ! zramctl --noheadings --output ALGORITHM /dev/zram0 2>/dev/null | grep -qx zstd; then
	sudo swapoff /dev/zram0 2>/dev/null || true
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
if [[ "$(hostname -s)" == ubuntu ]]; then
	sudo tee /etc/sysctl.d/99-tailscale.conf >/dev/null <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
	command -v tailscale >/dev/null 2>&1 && sudo tailscale set --operator="$USER"
	mkdir -m 700 -p ~/backups/wallos
	chmod 700 ~/backups/wallos
	mkdir -p ~/.config/systemd/user
	cat <<'EOF' >~/.config/systemd/user/wallos-backup.service
[Unit]
Description=Pull Wallos data backup from infra

[Service]
Type=oneshot
UMask=0077
ExecStart=/usr/bin/bash -c 'set -euo pipefail; mkdir -p "$HOME/backups/wallos"; tmp="$HOME/backups/wallos/latest.tar.gz.tmp"; rm -f "$tmp"; ssh -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new mapring@infra "tar -C ~/wallos -czf - data" > "$tmp"; list=$(tar -tzf "$tmp"); grep -qx "data/db/wallos.db" <<<"$list"; mv "$tmp" "$HOME/backups/wallos/latest.tar.gz"'
EOF
	cat <<'EOF' >~/.config/systemd/user/wallos-backup.timer
[Unit]
Description=Nightly Wallos backup from infra

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
	systemctl --user daemon-reload
	systemctl --user enable --now wallos-backup.timer
fi
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

[ -x ~/.local/bin/t3 ] || curl -fsSL https://t3.codes/install.sh | sh
grep -q 'HOME/.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.bashrc
grep -q 'mise activate bash' ~/.bashrc || echo 'eval "$(~/.local/bin/mise activate bash)"' >>~/.bashrc

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com
