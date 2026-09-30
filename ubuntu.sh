#!/usr/bin/env bash
# ubuntu.sh — desktop, 931GB NVMe, user mapring, hostname `ubuntu`
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
#   Drive      format the external drive ext4, label `Backup`, and leave it
#              plugged in — the script refuses to run without it.
#   After      sign in to 1Password, then Tailscale; restore ~/.ssh, ~/Work and
#              the .env files; run `claude` once to sign in (T3 Code drives it);
#              run the first backup from Déjà Dup; reboot (docker and input
#              groups), then open Handy, pick Parakeet V3, turn on launch at
#              login, and set Advanced → Paste Method to Clipboard
#              (Ctrl+Shift+V) — ydotool's typing is slow, and terminals only
#              paste with the Shift variant.
#
# Close Firefox before running: removing the snap fails while it is open.
set -euo pipefail

NIC=enp12s0
# The installer's crypttab names the LUKS partition by UUID. Not /dev/nvmeXn1pY:
# the kernel doesn't keep the two NVMe drives in the same order across boots,
# and on the wrong boot that path is the Windows drive.
LUKS=/dev/disk/by-uuid/$(awk '$2 ~ /^UUID=/ {sub(/^UUID=/, "", $2); print $2; exit}' /etc/crypttab)
# Déjà Dup is pointed at the backup drive by UUID, so it has to be plugged in.
# Checked up front rather than failing halfway through.
BACKUP=/dev/disk/by-label/Backup
[[ -e $BACKUP ]] || { echo "Plug in the Backup drive first." >&2; exit 1; }

# --- third-party repositories -------------------------------------------------
# Everything else comes from the Ubuntu archive. These don't ship there.

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

if [ ! -f /etc/apt/sources.list.d/vscode.list ]; then
  sudo install -dm755 /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
fi

# GitHub CLI. The archive has a `gh` too, but it lags behind and GitHub asks
# people not to use it. The key is already binary, so no dearmor.
if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
  sudo install -dm755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
fi

command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh

# --ssh is what removes host-key management entirely; without it this machine is
# on the tailnet but not reachable the way the rest of the setup assumes.
# Prints a URL to authenticate in the browser, so 1Password has to be signed in.
tailscale status >/dev/null 2>&1 || sudo tailscale up --ssh

# Serve config is root-only by default, and `t3 pair --tailscale` publishes
# T3 Code with `tailscale serve` as me, so it's denied without this.
sudo tailscale set --operator="$USER"

# A real sshd, but loopback only. T3 Code enables "Open in VS Code" from the
# MacBook only if something listens on 127.0.0.1:22 or ::1:22, and Tailscale
# SSH doesn't — it intercepts port 22 on the tailnet address alone. The link it
# builds points at the MagicDNS name, which Tailscale SSH still answers, so
# this sshd is never actually reached from outside. Written before the install
# so it never listens anywhere else, even for a moment. Ubuntu starts sshd from
# ssh.socket, whose addresses a generator derives from ListenAddress on
# daemon-reload.
sshd_conf=/etc/ssh/sshd_config.d/10-loopback.conf
sshd_want=$'ListenAddress 127.0.0.1\nListenAddress ::1\nPasswordAuthentication no\nKbdInteractiveAuthentication no'
if [ "$(cat "$sshd_conf" 2>/dev/null)" != "$sshd_want" ]; then
  sudo install -dm755 "${sshd_conf%/*}"
  printf '%s\n' "$sshd_want" | sudo tee "$sshd_conf" >/dev/null
  sshd_changed=1
fi
dpkg -s openssh-server >/dev/null 2>&1 || { sudo apt install -y openssh-server; sshd_changed=1; }
if [ -n "${sshd_changed:-}" ]; then
  sudo systemctl daemon-reload
  sudo systemctl restart ssh.socket
fi

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
# docker.io, deja-dup and tmux are all in the 26.04 archive, so no vendor repo
# is needed for them.
# The upgrade is here because an install image is always months behind by the
# time it's used, and "ready to work" doesn't mean "37 updates pending".
sudo apt update
sudo apt upgrade -y
sudo apt install -y git tmux lazygit deja-dup docker.io tpm2-tools \
                    1password mise code gh python3-pil

# --allow-downgrades because Ubuntu's `firefox` stub carries an epoch
# (1:1snap1-...) and Mozilla's real version does not, so apt scores the genuine
# package as older. The pin already decided which one we want.
sudo apt install -y --allow-downgrades firefox

# Google Chrome, for social-intelligence's verify skill, which drives it over
# CDP. Not the Chromium snap: the skill keeps its browser profile under
# ~/.cache, and a confined snap can't write to hidden directories in $HOME.
# The .deb adds Google's apt repo itself, so apt keeps it updated from then on.
if ! dpkg -s google-chrome-stable >/dev/null 2>&1; then
  curl -fsSLo /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo apt install -y /tmp/chrome.deb
  rm /tmp/chrome.deb
fi

# Chrome's circle fills its whole canvas; Firefox's globe fills 112 of 128px,
# so Chrome sits visibly larger in the dock. Scale each size down to match,
# centred, into the user icon theme, which is looked up before /usr/share —
# Chrome's updates rewrite the system copies and leave these alone. Rebuilt
# from Chrome's own logos on each run, so a new logo carries over.
for src in /opt/google/chrome/product_logo_*.png; do
  n=${src##*_}; n=${n%.png}
  mkdir -p ~/.local/share/icons/hicolor/${n}x${n}/apps
  python3 - "$src" ~/.local/share/icons/hicolor/${n}x${n}/apps/google-chrome.png <<'PY'
import sys
from PIL import Image
src, dst = sys.argv[1:]
im = Image.open(src).convert("RGBA")
side = round(im.width * 112 / 128)
out = Image.new("RGBA", im.size)
out.paste(im.resize((side, side), Image.LANCZOS), ((im.width - side) // 2,) * 2)
out.save(dst)
PY
done

# The dock's favourites still name the snap's app id, which no longer exists,
# leaving a dead icon where Firefox used to be. Same slot, real package.
gsettings set org.gnome.shell favorite-apps \
  "$(gsettings get org.gnome.shell favorite-apps | sed 's/firefox_firefox.desktop/firefox.desktop/')"

# Alphabetical app grid. GNOME orders it by install time and keeps a saved
# layout; clearing the layout is what makes it sort.
gsettings set org.gnome.shell app-picker-layout "[]"

# Flat pointer, no acceleration. GNOME's default is libinput's adaptive curve,
# which is neither Windows' curve nor off, so small moves land slightly wrong
# for a hand trained on the Windows side of this same desk. Speed too: Windows
# moves the cursor in physical pixels at any scale, GNOME in logical ones, so at
# 150% the same mouse ran 1.5× faster here. With a flat profile the speed is a
# plain multiplier of 1 + speed, and 1 − 0.33 undoes the 1.5.
gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat'
gsettings set org.gnome.desktop.peripherals.mouse speed -0.33

# Desktop Icons. Nothing lives on the desktop, and it hitches clicks and drags
# on the background. Ubuntu enables it from the session mode, so disabling it
# is what sticks — it lands in org.gnome.shell disabled-extensions.
gnome-extensions disable ding@rastersoft.com

# Tiling Assistant. Ubuntu's take on window snapping: it pops a picker to fill
# the other half after each snap and takes over Super+arrows. Stock GNOME
# already does half and full-screen snapping without it. Same session-mode
# story as Desktop Icons, so disable rather than uninstall.
gnome-extensions disable tiling-assistant@ubuntu.com

# HDR, 240Hz, 150%. GNOME has done HDR since 48 (Settings → Displays), but it
# lives in ~/.config/monitors.xml, not gsettings, so gdctl writes it the same way
# Settings does. `gdctl set` replaces the whole layout, hence mode and scale too
# — the monitor's EDID prefers a 60Hz mode. The connector is read rather than
# fixed: the monitor has been HDMI-1 and HDMI-2. Skipped once HDR is on, since
# applying a layout blanks the screen for a moment.
conn=$(gdctl show | awk '/Monitor .*Microstep/ {print $2; exit}')
if ! awk -v c="$conn" '/<connector>/ {hit = index($0, ">" c "<")}
                      hit && /<colormode>bt2100</ {found = 1}
                      END {exit !found}' ~/.config/monitors.xml 2>/dev/null; then
  gdctl set --persistent --logical-monitor --primary --scale 1.5 \
    --monitor "$conn" --mode 3840x2160@239.990 --color-mode bt2100
fi

sudo usermod -aG docker "$USER"   # takes effect at next boot, see Handy below

# --- Claude Code --------------------------------------------------------------
# The official installer, same as macbook.sh — it self-updates, so mise would
# only add a layer between it and its own updates. It lands in ~/.local/bin,
# which Ubuntu's stock .profile already puts on PATH.
command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash

# --- T3 Code ------------------------------------------------------------------
# Runs as a systemd user service so the phone and web apps can reach the agents
# here without a terminal left open. The installer also lands in ~/.local/bin,
# which isn't on PATH yet during a first run, hence the full path. Lingering is
# what keeps the service up at boot and after logout; the service setup would
# only print this command if it lacked the rights, so do it here with sudo.
# Updates are `t3 update`, not a re-run of this script.
[ -x ~/.local/bin/t3 ] || curl -fsSL https://t3.codes/install.sh | sh
sudo loginctl enable-linger "$USER"
systemctl --user is-enabled t3code.service >/dev/null 2>&1 || ~/.local/bin/t3 service install

# Lingering starts the service at boot, before GNOME exports the session's
# display variables, and T3's "open in editor" hands its own environment to
# `code` — which then dies with "Missing X server or $DISPLAY", even when a
# window is already open, since Electron sets up the display before handing off
# to it. Fixed values are safe: GNOME's socket is always wayland-0, and Wayland
# needs no auth file. DISPLAY wouldn't do — Xwayland's XAUTHORITY is renamed at
# each login. A drop-in, so `t3 service install` can't overwrite it.
dropin=~/.config/systemd/user/t3code.service.d/display.conf
want=$'[Service]\nEnvironment=WAYLAND_DISPLAY=wayland-0 XDG_SESSION_TYPE=wayland'
if [ "$(cat "$dropin" 2>/dev/null)" != "$want" ]; then
  mkdir -p "${dropin%/*}"
  printf '%s\n' "$want" >"$dropin"
  systemctl --user daemon-reload
  systemctl --user restart t3code.service
fi

# --- Handy (dictation) --------------------------------------------------------
# No apt repo, only a .deb on GitHub releases; it updates itself from then on,
# so this only runs once. The latest tag is read from the redirect rather than
# the API, which rate-limits.
if ! dpkg -s handy >/dev/null 2>&1; then
  tag=$(curl -fsSLo /dev/null -w '%{url_effective}' https://github.com/cjpais/Handy/releases/latest)
  ver=${tag##*/v}
  curl -fsSLo /tmp/handy.deb "https://github.com/cjpais/Handy/releases/download/v$ver/Handy_${ver}_amd64.deb"
  sudo apt install -y /tmp/handy.deb
  rm /tmp/handy.deb
fi

# Handy's tray glyphs fill three quarters of their canvas, 1Password's 89%
# (227 of 256px), so Handy sits visibly smaller in the top bar. Scale each one
# up to match, centred. The originals are diverted rather than overwritten, so
# Handy's updates land in the .orig files instead of undoing this, and a
# re-run rebuilds from them. Handy picks the new icons up at its next start.
for f in handy handy_warning recording transcribing; do
  png=/usr/lib/Handy/resources/$f.png
  [ -n "$(dpkg-divert --list "$png")" ] || sudo dpkg-divert --rename --divert "$png.orig" --add "$png"
  sudo python3 - "$png.orig" "$png" <<'PY'
import sys
from PIL import Image
src, dst = sys.argv[1:]
im = Image.open(src).convert("RGBA")
glyph = im.crop(im.getchannel("A").getbbox())
k = im.width * 227 / 256 / max(glyph.size)
glyph = glyph.resize((round(glyph.width * k), round(glyph.height * k)), Image.LANCZOS)
out = Image.new("RGBA", im.size)
out.paste(glyph, ((im.width - glyph.width) // 2, (im.height - glyph.height) // 2))
out.save(dst)
PY
done

# The .deb puts its 256px icon in hicolor/256x256@2, a folder meant for 512px
# icons, so at this display's scale (1.5, which the Shell rounds up to 2) the
# app grid loads it at half size and stretches it. Pointing the launcher
# straight at the file skips that lookup. Rebuilt on each run so Handy's own
# changes to its launcher carry over.
mkdir -p ~/.local/share/applications
sed 's|^Icon=.*|Icon=/usr/share/icons/hicolor/256x256@2/apps/handy.png|' \
  /usr/share/applications/Handy.desktop > ~/.local/share/applications/Handy.desktop

# Handy types into the focused window through ydotool: wtype doesn't work on
# GNOME's compositor. ydotoold needs /dev/uinput, which Ubuntu's udev rule
# gives to the input group — so the service only starts after a reboot. Not a
# re-login: lingering (T3 Code, above) keeps the user manager alive across
# logout, and with it the group list every session process inherits.
sudo apt install -y ydotool
sudo usermod -aG input "$USER"
systemctl --user enable ydotool.service

# Wayland won't let Handy grab a global hotkey itself, so GNOME owns it.
# Super+O is GNOME's rotation-lock key by default, meaningless on a desktop.
gsettings set org.gnome.settings-daemon.plugins.media-keys rotate-video-lock-static "['XF86RotationLockToggle']"
KB=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/handy/
list=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
case "$list" in
  *"$KB"*) ;;
  "@as []") gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$KB']" ;;
  *)        gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "${list%]}, '$KB']" ;;
esac
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KB name 'Handy'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KB command 'handy --toggle-transcription'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KB binding '<Super>o'

# --- git and mise -------------------------------------------------------------
git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com

# mise is inert until it's hooked into the shell. Appended once, in the stock
# .bashrc's own comment style, so re-runs don't stack lines onto the end of it.
if ! grep -qF 'mise activate bash' ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'

# activate mise so the tools it manages are on the PATH
eval "$(mise activate bash)"
BASHRC
fi

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

# --- backups ------------------------------------------------------------------
# Déjà Dup to the external drive: everything in $HOME, daily, 30 days kept.
# The drive is ext4 labelled `Backup`, formatted by hand. The `drive` backend
# finds it by UUID and mounts it before each run. The `local` backend took a
# fixed /run/media path, and GNOME only automounts drives plugged in after login,
# so after every reboot the path was missing and the scheduled backup failed.
# A fresh ext4 root is root-owned, so mount it once here and chown it.
mnt=$(findmnt -no TARGET "$BACKUP" | head -1 || true)
if [[ -z $mnt ]]; then
  udisksctl mount -b "$BACKUP" >/dev/null
  mnt=$(findmnt -no TARGET "$BACKUP" | head -1)
fi
sudo chown "$USER:$USER" "$mnt"
gsettings set org.gnome.DejaDup backend 'drive'
gsettings set org.gnome.DejaDup.Drive uuid "$(lsblk -no UUID "$BACKUP")"
gsettings set org.gnome.DejaDup.Drive name 'Backup'
gsettings set org.gnome.DejaDup.Drive folder 'ubuntu'
gsettings reset org.gnome.DejaDup.Local folder
gsettings set org.gnome.DejaDup include-list "['\$HOME']"
gsettings set org.gnome.DejaDup exclude-list "['\$TRASH', '\$DOWNLOAD', '\$HOME/Backup', '\$HOME/.cache', '\$HOME/snap']"
gsettings set org.gnome.DejaDup periodic true
gsettings set org.gnome.DejaDup periodic-period 1
gsettings set org.gnome.DejaDup delete-after 30

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
# One per kernel in /boot, not --regenerate-all: that walks /usr/lib/modules,
# where a removed kernel leaves a stub directory behind until it's purged, and
# dracut fails on it.
for k in /boot/vmlinuz-*; do
  sudo dracut --force --kver "${k#/boot/vmlinuz-}"
done
