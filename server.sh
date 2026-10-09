#!/usr/bin/env bash
set -euo pipefail

LUKS=/dev/disk/by-uuid/$(awk '$2 ~ /^UUID=/ {sub(/^UUID=/, "", $2); print $2; exit}' /etc/crypttab)

dpkg -s tailscale >/dev/null 2>&1 || curl -fsSL https://tailscale.com/install.sh | sh

tailscale status >/dev/null 2>&1 || sudo tailscale up --ssh

sudo tailscale set --operator="$USER"

sshd_conf=/etc/ssh/sshd_config.d/10-loopback.conf
sshd_want=$'ListenAddress 127.0.0.1\nListenAddress ::1\nPasswordAuthentication no\nKbdInteractiveAuthentication no'
if [ "$(cat "$sshd_conf" 2>/dev/null)" != "$sshd_want" ]; then
  sudo install -dm755 "${sshd_conf%/*}"
  printf '%s\n' "$sshd_want" | sudo tee "$sshd_conf" >/dev/null
  sshd_changed=1
fi
if ! dpkg -s openssh-server >/dev/null 2>&1; then
  sudo apt install -y openssh-server
  sshd_changed=1
fi
if [ -n "${sshd_changed:-}" ]; then
  sudo systemctl daemon-reload
  sudo systemctl restart ssh.socket
fi

if [ ! -f /etc/apt/sources.list.d/mise.list ]; then
  sudo install -dm755 /etc/apt/keyrings
  curl -fsSL https://mise.jdx.dev/gpg-key.pub \
    | sudo gpg --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg] https://mise.jdx.dev/deb stable main" \
    | sudo tee /etc/apt/sources.list.d/mise.list >/dev/null
fi

if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
  sudo install -dm755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
fi

sudo apt update
sudo apt upgrade -y
sudo apt install -y git tmux lazygit docker.io tpm2-tools mise gh

if ! dpkg -s google-chrome-stable >/dev/null 2>&1; then
  curl -fsSLo /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo apt install -y /tmp/chrome.deb
  rm /tmp/chrome.deb
fi

sudo usermod -aG docker "$USER"

[ -x ~/.local/bin/claude ] || curl -fsSL https://claude.ai/install.sh | bash

if [ ! -x ~/.local/bin/codex ]; then
  curl -fsSL https://chatgpt.com/codex/install.sh \
    | PATH="$HOME/.local/bin:$PATH" CODEX_NON_INTERACTIVE=1 sh
fi

[ -x ~/.local/bin/t3 ] || curl -fsSL https://t3.codes/install.sh | T3CODE_CHANNEL=nightly sh
sudo loginctl enable-linger "$USER"
systemctl --user is-enabled t3code.service >/dev/null 2>&1 || ~/.local/bin/t3 service install

dropin=~/.config/systemd/user/t3code.service.d/telemetry.conf
want=$'[Service]\nEnvironment=T3CODE_TELEMETRY_ENABLED=false'
if [ "$(cat "$dropin" 2>/dev/null)" != "$want" ]; then
  mkdir -p "${dropin%/*}"
  printf '%s\n' "$want" >"$dropin"
  systemctl --user daemon-reload
  systemctl --user restart t3code.service
fi

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com

if ! grep -qF 'mise activate bash' ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'

# Activate mise so the tools it manages are on the PATH
eval "$(mise activate bash)"
BASHRC
fi

if ! sudo cryptsetup luksDump "$LUKS" | grep -q systemd-tpm2; then
  sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$LUKS"
fi
if ! grep -q tpm2-device /etc/crypttab; then
  sudo sed -i 's/ luks$/ luks,tpm2-device=auto/' /etc/crypttab
fi
for k in /boot/vmlinuz-*; do
  sudo dracut --force --kver "${k#/boot/vmlinuz-}"
done
