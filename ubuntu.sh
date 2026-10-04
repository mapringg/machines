#!/usr/bin/env bash
# Ubuntu 26.04 desktop, hostname `ubuntu`. Safe to re-run.
# Do the manual steps in README first, and close Firefox: the snap can't be
# removed while it's open.
set -euo pipefail

NIC=enp12s0
# By UUID: NVMe order changes across boots, and the wrong path is Windows
LUKS=/dev/disk/by-uuid/$(awk '$2 ~ /^UUID=/ {sub(/^UUID=/, "", $2); print $2; exit}' /etc/crypttab)
# Déjà Dup finds the drive by UUID, so it must be plugged in
BACKUP=/dev/disk/by-label/Backup
[[ -e $BACKUP ]] || { echo "Plug in the Backup drive first." >&2; exit 1; }

# --- third-party repositories -------------------------------------------------
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

# The archive's gh lags behind. GitHub's key is already binary, so no dearmor
if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
  sudo install -dm755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
fi

command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh

# Prints a sign-in URL, so sign in to 1Password first
tailscale status >/dev/null 2>&1 || sudo tailscale up --ssh

# Lets `t3 pair --tailscale` run `tailscale serve` without root
sudo tailscale set --operator="$USER"

# Loopback-only sshd: T3 Code offers "Open in VS Code" only if :22 listens
# locally. Config first, so it never listens elsewhere; ssh.socket reads it on
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

# Mozilla's deb, not the snap: a confined snap can't run 1Password's browser
# helper. Pinned so the archive's `firefox` stub can't bring the snap back.
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
sudo apt update
sudo apt upgrade -y
sudo apt install -y git tmux lazygit deja-dup docker.io tpm2-tools \
                    1password mise code gh python3-pil

# The stub carries an epoch, so apt sees Mozilla's real firefox as older
sudo apt install -y --allow-downgrades firefox

# For the verify skill. Not the Chromium snap: it can't write to ~/.cache
if ! dpkg -s google-chrome-stable >/dev/null 2>&1; then
  curl -fsSLo /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo apt install -y /tmp/chrome.deb
  rm /tmp/chrome.deb
fi

# Shrink Chrome's dock icon to Firefox's 112/128px. The user icon theme wins
# over /usr/share, so Chrome updates leave it alone.
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

# Its postinst adds Paper's apt repo, so apt upgrades it from then on
if ! dpkg -s paper >/dev/null 2>&1; then
  curl -fsSLo /tmp/paper.deb https://download.paper.design/linux/deb
  sudo apt install -y /tmp/paper.deb
  rm /tmp/paper.deb
fi

# Paper's tile fills ~103/128px; grow it to the same 112/128. The faint shadow
# around it still fits the canvas.
for src in /usr/share/icons/hicolor/*/apps/paper-desktop.png; do
  dir=${src#/usr/share/icons/}; dir=~/.local/share/icons/${dir%/*}
  mkdir -p "$dir"
  python3 - "$src" "$dir/paper-desktop.png" <<'PY'
import sys
from PIL import Image
src, dst = sys.argv[1:]
im = Image.open(src).convert("RGBA")
l, _, r, _ = im.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
side = round(im.width * im.width * 112 / 128 / (r - l))
c = (side - im.width) // 2
im.resize((side, side), Image.LANCZOS).crop((c, c, c + im.width, c + im.width)).save(dst)
PY
done

# Repoint the dash favourite from the removed snap
gsettings set org.gnome.shell favorite-apps \
  "$(gsettings get org.gnome.shell favorite-apps | sed 's/firefox_firefox.desktop/firefox.desktop/')"

# Clearing the saved layout makes the app grid sort alphabetically
gsettings set org.gnome.shell app-picker-layout "[]"

# Flat, like Windows. Speed scales by 1 + speed, so -0.33 undoes GNOME's
# logical-pixel 1.5× at 150%.
gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat'
gsettings set org.gnome.desktop.peripherals.mouse speed -0.33

# Ubuntu enables these per session mode, so disable rather than uninstall.
# Desktop Icons hitch clicks on the background.
gnome-extensions disable ding@rastersoft.com

# Tiling Assistant hijacks Super+arrows; stock GNOME already snaps
gnome-extensions disable tiling-assistant@ubuntu.com

# Ubuntu Dock glitches across mixed scales
gnome-extensions disable ubuntu-dock@ubuntu.com

# Monitors live in ~/.config/monitors.xml, written by gdctl like Settings does.
# SDR keeps the MSI's own brightness and sRGB mode; full range stops HDMI from
# picking limited, which greys OLED black. `gdctl set` replaces the whole
# layout and blanks the screens, so it only runs on drift. Connectors change, so
# they're looked up, and the LG is left out when unplugged.
layout() {   # one sorted line per monitor: mode, colour, range, then placement
  gdctl show --verbose | sed 's/[│├└─]//g; s/^ *//' | awk '
    /^Logical monitors/ { logical = 1 }
    !logical && /^Monitor / { mon = $2 }
    !logical && /^[0-9]+x[0-9]+@/ { mode = $1 }
    !logical && /^is-current ⇒/ { m[mon] = mode }
    !logical && /^(color-mode|rgb-range) ⇒/ { m[mon] = m[mon] " " $3 }
    logical && /^(Position|Scale|Transform|Primary):/ { sub(/^[^:]*: /, ""); l = l " " $0 }
    logical && /^[A-Z]+-[0-9]+ \(/ { print $1, m[$1] l; l = "" }' | sort
}
msi=$(gdctl show | awk '/Monitor .*Microstep/ {print $2; exit}')
lg=$(gdctl show | awk '/Monitor .*LG Electronics/ {print $2; exit}')
msi_mode=(--monitor "$msi" --mode 3840x2160@239.990 --color-mode default --rgb-range full)
lg_mode=(--monitor "$lg" --mode 2560x1440@164.958 --color-mode default --rgb-range full)
if [[ $lg ]]; then   # 2560 tall portrait, 1440 tall MSI at 150%: (2560 − 1440) / 2
  args=(--logical-monitor --scale 1 --transform 90 "${lg_mode[@]}"
        --logical-monitor --primary --scale 1.5 --x 1440 --y 560 "${msi_mode[@]}")
  want=$(printf '%s\n' "$lg 2560x1440@164.958 default full (0, 0) 1.0 90 no" \
    "$msi 3840x2160@239.990 default full (1440, 560) 1.5 normal yes" | sort)
else
  args=(--logical-monitor --primary --scale 1.5 "${msi_mode[@]}")
  want="$msi 3840x2160@239.990 default full (0, 0) 1.5 normal yes"
fi
[[ $(layout) == "$want" ]] || gdctl set --persistent "${args[@]}"

# QD-OLED subpixels aren't RGB stripes, so subpixel smoothing fringes
gsettings set org.gnome.desktop.interface font-antialiasing 'grayscale'

# Dark style for OLED burn-in; the themes match Settings → Appearance
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Yaru-dark'

sudo usermod -aG docker "$USER"   # takes effect at next boot, see Handy below

# --- Claude Code --------------------------------------------------------------
# Self-updating, so not through mise
command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash

# --- Codex --------------------------------------------------------------------
# By file: ~/.local/bin isn't on PATH on a first run. PATH is passed so the
# installer doesn't append its own to ~/.bashrc.
[ -x ~/.local/bin/codex ] || curl -fsSL https://chatgpt.com/codex/install.sh \
  | PATH="$HOME/.local/bin:$PATH" CODEX_NON_INTERACTIVE=1 sh

# --- T3 Code ------------------------------------------------------------------
# User service, so the phone and web apps reach it without a terminal; lingering
# keeps it up at boot. Update with `t3 update`, which stays on nightly. Back to
# stable: `t3 update --channel stable --allow-downgrade`.
[ -x ~/.local/bin/t3 ] || curl -fsSL https://t3.codes/install.sh | T3CODE_CHANNEL=nightly sh
sudo loginctl enable-linger "$USER"
systemctl --user is-enabled t3code.service >/dev/null 2>&1 || ~/.local/bin/t3 service install

# Started at boot, the service lacks GNOME's display variables, so `code` can't
# open. wayland-0 is fixed; a drop-in survives `t3 service install`.
dropin=~/.config/systemd/user/t3code.service.d/display.conf
want=$'[Service]\nEnvironment=WAYLAND_DISPLAY=wayland-0 XDG_SESSION_TYPE=wayland'
if [ "$(cat "$dropin" 2>/dev/null)" != "$want" ]; then
  mkdir -p "${dropin%/*}"
  printf '%s\n' "$want" >"$dropin"
  t3_changed=1
fi

# Local DNS answers PostHog with ::, and failed flushes log ~10MB a day
dropin=~/.config/systemd/user/t3code.service.d/telemetry.conf
want=$'[Service]\nEnvironment=T3CODE_TELEMETRY_ENABLED=false'
if [ "$(cat "$dropin" 2>/dev/null)" != "$want" ]; then
  printf '%s\n' "$want" >"$dropin"
  t3_changed=1
fi
if [ -n "${t3_changed:-}" ]; then
  systemctl --user daemon-reload
  systemctl --user restart t3code.service
fi

# --- Taildrop -----------------------------------------------------------------
# Linux has no receiver, so this drains the inbox into ~/Downloads. Rename,
# since skip leaves a same-named file stuck in the inbox.
unit=~/.config/systemd/user/taildrop.service
want="[Unit]
Description=Receive Taildrop files into ~/Downloads

[Service]
ExecStart=/usr/bin/tailscale file get --loop --conflict=rename %h/Downloads
Restart=always
RestartSec=5

[Install]
WantedBy=default.target"
if [ "$(cat "$unit" 2>/dev/null)" != "$want" ]; then
  printf '%s\n' "$want" >"$unit"
  systemctl --user daemon-reload
  systemctl --user restart taildrop.service
fi
systemctl --user enable --now taildrop.service

# --- Handy (dictation) --------------------------------------------------------
# Only a .deb on GitHub, then it self-updates. Tag from the redirect, since the
# API rate-limits.
if ! dpkg -s handy >/dev/null 2>&1; then
  tag=$(curl -fsSLo /dev/null -w '%{url_effective}' https://github.com/cjpais/Handy/releases/latest)
  ver=${tag##*/v}
  curl -fsSLo /tmp/handy.deb "https://github.com/cjpais/Handy/releases/download/v$ver/Handy_${ver}_amd64.deb"
  sudo apt install -y /tmp/handy.deb
  rm /tmp/handy.deb
fi

# Scale the tray glyphs to 1Password's 227/256px. Diverted, so Handy's updates
# write the .orig files instead of undoing this.
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

# The 256px icon sits in a folder for 512px ones and renders blurry at 150%,
# so the launcher points straight at it
mkdir -p ~/.local/share/applications
sed 's|^Icon=.*|Icon=/usr/share/icons/hicolor/256x256@2/apps/handy.png|' \
  /usr/share/applications/Handy.desktop > ~/.local/share/applications/Handy.desktop

# Handy pastes through ydotool; wtype fails on GNOME. /dev/uinput needs the
# input group, which applies only after a reboot: lingering keeps the session.
sudo apt install -y ydotool
sudo usermod -aG input "$USER"
systemctl --user enable ydotool.service

# Wayland apps can't grab global hotkeys. Super+O is rotation lock by default
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

# Appended once, in the stock .bashrc's comment style
if ! grep -qF 'mise activate bash' ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'

# activate mise so the tools it manages are on the PATH
eval "$(mise activate bash)"
BASHRC
fi

# --- Android (Expo) -----------------------------------------------------------
# React Native's Gradle toolchain wants 17; Studio only bundles 21. Phones need
# no udev rules: systemd's 70-uaccess already tags adb devices.
sudo apt install -y openjdk-17-jdk

# Google's tarball, not the Snapcrafters snap. Owned by me so Studio's own
# updater can patch it.
if [ ! -x /opt/android-studio/bin/studio ]; then
  url=$(curl -fsSL https://jb.gg/android-studio-releases-list.json | python3 -c '
import json, sys
rel = next(i for i in json.load(sys.stdin)["content"]["item"] if i["channel"] == "Release")
print(next(d["link"] for d in rel["download"] if d["link"].endswith("-linux.tar.gz")))')
  sudo install -d -o "$USER" -g "$USER" /opt/android-studio
  curl -fsSL "$url" | tar -xz -C /opt/android-studio --strip-components=1
fi

# Studio's badge spans 118/128px; shrink it to Chrome's 112/128. Measured on
# the PNG, applied to the SVG, so it stays sharp at 150%.
mkdir -p ~/.local/share/icons/hicolor/scalable/apps
python3 - /opt/android-studio/bin/studio.png /opt/android-studio/bin/studio.svg \
  ~/.local/share/icons/hicolor/scalable/apps/android-studio.svg <<'PY'
import re, sys
from PIL import Image
png, src, dst = sys.argv[1:]
im = Image.open(png).convert("RGBA")
l, _, r, _ = im.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
k = 112 / (r - l)
svg = open(src).read()
head = re.match(r"<svg[^>]*>", svg).end()
g = f'<g transform="translate({64 * (1 - k):.3f} {64 * (1 - k):.3f}) scale({k:.5f})">'
open(dst, "w").write(svg[:head] + g + svg[head:].replace("</svg>", "</g></svg>"))
PY

# Named for Studio's WM class, or GNOME shows its window as a second icon
cat > ~/.local/share/applications/jetbrains-studio.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Android Studio
Icon=android-studio
Exec=/opt/android-studio/bin/studio %f
Categories=Development;IDE;
StartupWMClass=jetbrains-studio
StartupNotify=true
DESKTOP

# Emulator's bundled Qt drops _NET_WM_PING, so any timeout fires. Remove once
# the emulator ships the fix: https://issuetracker.google.com/issues/563833202
gsettings set org.gnome.mutter check-alive-timeout 0

if ! grep -qF 'ANDROID_HOME' ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'

# Android SDK, where Android Studio's setup wizard puts it
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"
BASHRC
fi

# --- zapp (Voyager flashing) --------------------------------------------------
# `zapp flash <Oryx URL or .bin>`, or `zapp update`
mise use -g github:zsa/zapp

# The Voyager and its STM32 bootloader, with uaccess rather than ZSA's
# world-writable rules. Must sort before 73-seat-late.rules, which applies it.
udev_rules=/etc/udev/rules.d/50-zsa.rules
udev_want='SUBSYSTEM=="usb", ATTR{idVendor}=="3297", TAG+="uaccess"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3297", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="df11", TAG+="uaccess"'
if [ "$(cat "$udev_rules" 2>/dev/null)" != "$udev_want" ]; then
  printf '%s\n' "$udev_want" | sudo tee "$udev_rules" >/dev/null
  sudo udevadm control --reload-rules
  sudo udevadm trigger
fi

# --- Wake-on-LAN --------------------------------------------------------------
# On the NM connection, as NM undoes anything else; it also sets PCI wakeup
CON=$(nmcli -t -f NAME,DEVICE con show | awk -F: -v d="$NIC" '$2==d{print $1; exit}')
if [ "$(nmcli -g 802-3-ethernet.wake-on-lan con show "$CON")" != magic ]; then
  sudo nmcli con mod "$CON" 802-3-ethernet.wake-on-lan magic
  sudo nmcli con up "$CON" >/dev/null   # brief link bounce
fi

# --- suspend over SSH ---------------------------------------------------------
# polkit only grants suspend to local sessions
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
# The drive backend mounts by UUID; `local` needed a path that only existed
# after login. A fresh ext4 root is root-owned, hence the chown.
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
# PCR7: survives kernel updates, not Secure Boot changes. The passphrase stays.
if ! sudo cryptsetup luksDump "$LUKS" | grep -q systemd-tpm2; then
  sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$LUKS"
fi
if ! grep -q tpm2-device /etc/crypttab; then
  sudo sed -i 's/ luks$/ luks,tpm2-device=auto/' /etc/crypttab
fi
# Always rebuilt: the initramfs needs tpm2-tools. Per kernel in /boot, since
# --regenerate-all fails on stubs left in /usr/lib/modules.
for k in /boot/vmlinuz-*; do
  sudo dracut --force --kver "${k#/boot/vmlinuz-}"
done
