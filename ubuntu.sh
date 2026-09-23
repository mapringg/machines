#!/usr/bin/env bash
# ubuntu.sh — desktop, 931GB NVMe (nvme1n1), user mapring, hostname `ubuntu`
# Ubuntu 26.04.1 LTS Desktop, stock GNOME. Safe to re-run.
#
# MANUAL STEPS — do these first, they can't be scripted:
#   BIOS       see README — shared with windows.ps1
#   Installer  Default selection; tick both third-party boxes (the NVIDIA driver
#              comes from there, Canonical-signed, so Secure Boot needs no MOK
#              enrolment); "Erase disk and install" onto the 931GB drive;
#              "Encrypt with passphrase"; hostname `ubuntu`, user `mapring`.
#              Delete all partitions on BOTH disks during the Windows install
#              first, so Windows can't put its boot files on this drive.
#   After      sign in to 1Password, then Tailscale; point Déjà Dup at the
#              external drive; restore ~/.ssh, ~/Work and the .env files.
set -euo pipefail

NIC=enp12s0
LUKS=/dev/nvme1n1p3   # nvme1n1 is the 931GB Ubuntu drive; nvme0n1 is Windows

# --- third-party repositories -------------------------------------------------
# Everything else comes from the Ubuntu archive. These three don't ship there.

if [ ! -f /etc/apt/sources.list.d/1password.list ]; then
  curl -sS https://downloads.1password.com/linux/keys/1password.asc \
    | sudo gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" \
    | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
fi

if [ ! -f /etc/apt/sources.list.d/mise.list ]; then
  sudo install -dm755 /etc/apt/keyrings
  curl -fsSL https://mise.jdx.dev/gpg-key.pub \
    | sudo gpg --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg] https://mise.jdx.dev/deb stable main" \
    | sudo tee /etc/apt/sources.list.d/mise.list >/dev/null
fi

command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh

# Firefox from Mozilla, not the Ubuntu snap. A confined snap can't execute
# /opt/1Password/1Password-BrowserSupport, so the extension can never reach the
# desktop app and every unlock has to be done twice. Pinned so the `firefox`
# deb in the archive — a stub that reinstalls the snap — can't win.
if [ ! -f /etc/apt/sources.list.d/mozilla.list ]; then
  sudo install -dm755 /etc/apt/keyrings
  curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
    | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc >/dev/null
  echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
    | sudo tee /etc/apt/sources.list.d/mozilla.list >/dev/null
  printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
    | sudo tee /etc/apt/preferences.d/mozilla >/dev/null
fi
if snap list firefox >/dev/null 2>&1; then sudo snap remove --purge firefox; fi

# --- packages -----------------------------------------------------------------
# ghostty, docker.io, deja-dup and tmux are all in the 26.04 archive, so no
# vendor repo is needed for them.
sudo apt update
sudo apt install -y git tmux ghostty deja-dup docker.io ethtool \
                    tpm2-tools 1password mise

# --allow-downgrades because Ubuntu's `firefox` stub carries an epoch
# (1:1snap1-...) and Mozilla's real 154.0 does not, so apt scores the genuine
# package as older. The pin already decided which one we want.
sudo apt install -y --allow-downgrades firefox

sudo usermod -aG docker "$USER"   # takes effect at next login

# --- Wake-on-LAN --------------------------------------------------------------
# Two separate switches, and the machine only wakes if both are on: the r8169
# driver's own WoL mode, and PCI wakeup for the device, which defaults to
# `disabled`. Re-applied on every boot because neither survives one.
sudo tee /etc/systemd/system/wake-on-lan.service >/dev/null <<SERVICE
[Unit]
Description=Arm Wake-on-LAN on $NIC
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/ethtool -s $NIC wol g
ExecStart=/bin/sh -c 'echo enabled > /sys/class/net/$NIC/device/power/wakeup'

[Install]
WantedBy=multi-user.target
SERVICE
sudo systemctl daemon-reload
sudo systemctl enable --now wake-on-lan.service

# --- boot order ---------------------------------------------------------------
# The Windows install left its own entry first. Put Ubuntu ahead of it; GRUB
# still offers Windows from the menu.
UBUNTU_ENTRY=$(efibootmgr | sed -n 's/^Boot\([0-9A-F]\{4\}\)\*\?[[:space:]]*Ubuntu[[:space:]].*/\1/p' | head -1)
OTHERS=$(efibootmgr | sed -n 's/^BootOrder: //p' | tr ',' '\n' | grep -v "^$UBUNTU_ENTRY$" | paste -sd, -)
sudo efibootmgr -o "$UBUNTU_ENTRY${OTHERS:+,$OTHERS}" >/dev/null

# --- LUKS auto-unlock via TPM -------------------------------------------------
# Bound to PCR7 (Secure Boot state), so kernel updates don't invalidate it but
# disabling Secure Boot does. The install passphrase stays as a keyslot, so a
# failed TPM unlock falls back to typing it rather than locking me out.
if ! sudo cryptsetup luksDump "$LUKS" | grep -q systemd-tpm2; then
  sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$LUKS"
fi
if ! grep -q tpm2-device /etc/crypttab; then
  sudo sed -i 's/ luks$/ luks,tpm2-device=auto/' /etc/crypttab
fi
# Unconditional: dracut's systemd-cryptsetup module pulls in tpm2-tss, which
# needs the tpm2-tools binaries present at build time.
sudo dracut --force --regenerate-all
