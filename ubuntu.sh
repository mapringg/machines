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
#
# Close Firefox before running: removing the snap fails while it is open.
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

# --ssh is what removes host-key management entirely; without it this machine is
# on the tailnet but not reachable the way the rest of the setup assumes.
# Prints a URL to authenticate in the browser, so 1Password has to be signed in.
tailscale status >/dev/null 2>&1 || sudo tailscale up --ssh

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
# The upgrade is here because an install image is always months behind by the
# time it's used, and "ready to work" doesn't mean "37 updates pending".
sudo apt update
sudo apt upgrade -y
sudo apt install -y git tmux ghostty deja-dup docker.io tpm2-tools 1password mise

# --allow-downgrades because Ubuntu's `firefox` stub carries an epoch
# (1:1snap1-...) and Mozilla's real version does not, so apt scores the genuine
# package as older. The pin already decided which one we want.
sudo apt install -y --allow-downgrades firefox

# The dock's favourites still name the snap's app id, which no longer exists,
# leaving a dead icon where Firefox used to be. Same slot, real package.
gsettings set org.gnome.shell favorite-apps \
  "$(gsettings get org.gnome.shell favorite-apps | sed 's/firefox_firefox.desktop/firefox.desktop/')"

sudo usermod -aG docker "$USER"   # takes effect at next login

# --- git and mise -------------------------------------------------------------
git config --global user.name mapringg
git config --global user.email work@mapringg.com

# mise is inert until it's hooked into the shell.
grep -q 'mise activate' ~/.bashrc || echo 'eval "$(mise activate bash)"' >> ~/.bashrc

# --- Wake-on-LAN --------------------------------------------------------------
# NetworkManager owns this NIC and re-applies its ethernet settings a couple of
# seconds into boot, so anything set behind its back — a systemd unit, a udev
# rule — is silently undone. Setting it on the connection is what sticks, and it
# also flips the PCI device's power/wakeup, which defaults to `disabled` and is
# the half that actually breaks Wake-on-LAN.
CON=$(nmcli -t -f NAME,DEVICE con show | awk -F: -v d="$NIC" '$2==d{print $1; exit}')
sudo nmcli con mod "$CON" 802-3-ethernet.wake-on-lan magic
sudo nmcli con up "$CON" >/dev/null   # brief link bounce

# --- suspend over SSH ---------------------------------------------------------
# polkit only grants suspend to a session that is physically at the machine, so
# `ssh ubuntu 'systemctl suspend'` — the whole point of the power design — is
# denied. Narrow grant: this one action, this one user.
sudo tee /etc/polkit-1/rules.d/50-suspend.rules >/dev/null <<RULES
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.suspend" ||
         action.id == "org.freedesktop.login1.suspend-multiple-sessions") &&
        subject.user == "$USER") {
        return polkit.Result.YES;
    }
});
RULES

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
