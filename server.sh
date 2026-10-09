#!/usr/bin/env bash
set -euo pipefail

LUKS=/dev/disk/by-uuid/$(awk '$2 ~ /^UUID=/ {sub(/^UUID=/, "", $2); print $2; exit}' /etc/crypttab)

sudo apt install -y tpm2-tools

if ! sudo cryptsetup luksDump "$LUKS" | grep -q systemd-tpm2; then
  sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$LUKS"
fi
if ! grep -q tpm2-device /etc/crypttab; then
  sudo sed -i 's/ luks$/ luks,tpm2-device=auto/' /etc/crypttab
fi
for k in /boot/vmlinuz-*; do
  sudo dracut --force --kver "${k#/boot/vmlinuz-}"
done
