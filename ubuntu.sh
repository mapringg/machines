#!/usr/bin/env bash
set -euo pipefail

LUKS=/dev/disk/by-uuid/$(awk '$2 ~ /^UUID=/ {sub(/^UUID=/, "", $2); print $2; exit}' /etc/crypttab)
BACKUP=/dev/disk/by-label/Backup
[[ -e $BACKUP ]] || { echo "Plug in the Backup drive first." >&2; exit 1; }
if snap list firefox >/dev/null 2>&1 && pgrep -x firefox >/dev/null; then
  echo "Close Firefox first." >&2; exit 1
fi

if [ ! -f /etc/apt/sources.list.d/1password.sources ]; then
  curl -sS https://downloads.1password.com/linux/keys/1password.asc \
    | sudo gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
  printf '%s\n' 'Types: deb' 'URIs: https://downloads.1password.com/linux/debian/amd64' \
    'Suites: stable' 'Components: main' 'Architectures: amd64' \
    'Signed-By: /usr/share/keyrings/1password-archive-keyring.gpg' \
    | sudo tee /etc/apt/sources.list.d/1password.sources >/dev/null
fi

if [ ! -f /etc/apt/sources.list.d/mise.list ]; then
  sudo install -dm755 /etc/apt/keyrings
  curl -fsSL https://mise.jdx.dev/gpg-key.pub \
    | sudo gpg --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg] https://mise.jdx.dev/deb stable main" \
    | sudo tee /etc/apt/sources.list.d/mise.list >/dev/null
fi

if [ ! -f /etc/apt/sources.list.d/vscode.sources ]; then
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
  printf '%s\n' 'Types: deb' 'URIs: https://packages.microsoft.com/repos/code' \
    'Suites: stable' 'Components: main' 'Architectures: amd64' \
    'Signed-By: /usr/share/keyrings/microsoft.gpg' \
    | sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null
fi

if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
  sudo install -dm755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
fi

if [ ! -f /etc/apt/sources.list.d/helium.list ]; then
  sudo install -dm755 /etc/apt/keyrings
  curl -fsSL https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/helium.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main" \
    | sudo tee /etc/apt/sources.list.d/helium.list >/dev/null
fi
if snap list firefox >/dev/null 2>&1; then sudo snap remove --purge firefox; fi

command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh

tailscale status >/dev/null 2>&1 || sudo tailscale up --ssh

sudo tailscale set --operator="$USER"

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

sudo apt update
sudo apt upgrade -y
sudo apt install -y git tmux lazygit deja-dup docker.io tpm2-tools \
                    1password mise code gh python3-pil helium-bin

if ! dpkg -s paper >/dev/null 2>&1; then
  curl -fsSLo /tmp/paper.deb https://download.paper.design/linux/deb
  sudo apt install -y /tmp/paper.deb
  rm /tmp/paper.deb
fi

fit_icon() {
  python3 - "$1" "$2" <<'PY'
import sys
from PIL import Image
src, dst = sys.argv[1:]
im = Image.open(src).convert("RGBA")
l, _, r, _ = im.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
side = round(im.width * im.width * 112 / 128 / (r - l))
c = (side - im.width) // 2
im.resize((side, side), Image.LANCZOS).crop((c, c, c + im.width, c + im.width)).save(dst)
PY
}

for src in /usr/share/icons/hicolor/*/apps/paper-desktop.png; do
  dir=${src#/usr/share/icons/}; dir=~/.local/share/icons/${dir%/*}
  mkdir -p "$dir"
  fit_icon "$src" "$dir/paper-desktop.png"
done

for src in /usr/share/icons/hicolor/*/apps/helium.png; do
  dir=${src#/usr/share/icons/}; dir=~/.local/share/icons/${dir%/*}
  mkdir -p "$dir"
  fit_icon "$src" "$dir/helium.png"
done

sudo usermod -aG docker "$USER"

favorites=$(gsettings get org.gnome.shell favorite-apps | sed 's/firefox_firefox.desktop/helium.desktop/')
[[ $favorites == *t3code.desktop* ]] ||
  favorites=${favorites/"'helium.desktop'"/"'helium.desktop', 't3code.desktop'"}
gsettings set org.gnome.shell favorite-apps "$favorites"
[ "$(xdg-settings get default-web-browser)" = helium.desktop ] ||
  xdg-settings set default-web-browser helium.desktop

gsettings set org.gnome.shell app-picker-layout "[]"

gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat'
gsettings set org.gnome.desktop.peripherals.mouse speed -0.33

gnome-extensions disable ding@rastersoft.com
gnome-extensions disable tiling-assistant@ubuntu.com
gnome-extensions disable ubuntu-dock@ubuntu.com

layout() {
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
if [[ $lg ]]; then
  args=(--logical-monitor --scale 1 --transform 90 "${lg_mode[@]}"
        --logical-monitor --primary --scale 1.5 --x 1440 --y 560 "${msi_mode[@]}")
  want=$(printf '%s\n' "$lg 2560x1440@164.958 default full (0, 0) 1.0 90 no" \
    "$msi 3840x2160@239.990 default full (1440, 560) 1.5 normal yes" | sort)
else
  args=(--logical-monitor --primary --scale 1.5 "${msi_mode[@]}")
  want="$msi 3840x2160@239.990 default full (0, 0) 1.5 normal yes"
fi
[[ -z $msi || $(layout) == "$want" ]] || gdctl set --persistent "${args[@]}"

gsettings set org.gnome.desktop.interface font-antialiasing 'grayscale'

gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Yaru-dark'

command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash

[ -x ~/.local/bin/codex ] || curl -fsSL https://chatgpt.com/codex/install.sh \
  | PATH="$HOME/.local/bin:$PATH" CODEX_NON_INTERACTIVE=1 sh

if [ -f ~/.config/systemd/user/t3code.service ]; then
  ~/.local/bin/t3 uninstall --yes
  rm -rf ~/.config/systemd/user/t3code.service.d
fi
[ "$(loginctl show-user "$USER" --property=Linger --value)" = no ] ||
  sudo loginctl disable-linger "$USER"

if ! dpkg -s t3code >/dev/null 2>&1; then
  releases=$(curl -fsSL 'https://api.github.com/repos/pingdotgg/t3code/releases?per_page=20')
  nightly_deb=$(grep -m1 -o 'https://[^"]*-nightly\.[^"]*-amd64\.deb' <<<"$releases")
  curl -fsSLo /tmp/t3code.deb "$nightly_deb"
  sudo apt install -y /tmp/t3code.deb
  rm /tmp/t3code.deb
fi

for src in /usr/share/icons/hicolor/*/apps/t3code.png; do
  dir=${src#/usr/share/icons/}; dir=~/.local/share/icons/${dir%/*}
  mkdir -p "$dir"
  fit_icon "$src" "$dir/t3code.png"
done

entry=~/.local/share/applications/t3code.desktop
want=$(sed 's/^StartupWMClass=.*/StartupWMClass=com.t3tools.T3Code/' /usr/share/applications/t3code.desktop)
[ "$(cat "$entry" 2>/dev/null)" = "$want" ] || printf '%s\n' "$want" >"$entry"

if ! grep -qF 'T3CODE_TELEMETRY_ENABLED' ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'

# T3 Code reads this at launch; keeps its usage data off PostHog
export T3CODE_TELEMETRY_ENABLED=false
BASHRC
fi

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

if ! dpkg -s handy >/dev/null 2>&1; then
  tag=$(curl -fsSLo /dev/null -w '%{url_effective}' https://github.com/cjpais/Handy/releases/latest)
  ver=${tag##*/v}
  curl -fsSLo /tmp/handy.deb "https://github.com/cjpais/Handy/releases/download/v$ver/Handy_${ver}_amd64.deb"
  sudo apt install -y /tmp/handy.deb
  rm /tmp/handy.deb
fi

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

mkdir -p ~/.local/share/applications
sed 's|^Icon=.*|Icon=/usr/share/icons/hicolor/256x256@2/apps/handy.png|' \
  /usr/share/applications/Handy.desktop > ~/.local/share/applications/Handy.desktop

sudo apt install -y ydotool
sudo usermod -aG input "$USER"
systemctl --user enable ydotool.service

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

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com

if ! grep -qF 'mise activate bash' ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'

# Activate mise so the tools it manages are on the PATH
eval "$(mise activate bash)"
BASHRC
fi

sudo apt install -y openjdk-17-jdk

if [ ! -x /opt/android-studio/bin/studio ]; then
  url=$(curl -fsSL https://jb.gg/android-studio-releases-list.json | python3 -c '
import json, sys
rel = next(i for i in json.load(sys.stdin)["content"]["item"] if i["channel"] == "Release")
print(next(d["link"] for d in rel["download"] if d["link"].endswith("-linux.tar.gz")))')
  sudo install -d -o "$USER" -g "$USER" /opt/android-studio
  curl -fsSL "$url" | tar -xz -C /opt/android-studio --strip-components=1
fi

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

gsettings set org.gnome.mutter check-alive-timeout 0

if ! grep -qF 'ANDROID_HOME' ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'

# Android SDK, where Android Studio's setup wizard puts it
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"
BASHRC
fi

mise use -g kubectl k9s

if ! dpkg -s freelens >/dev/null 2>&1; then
  tag=$(curl -fsSLo /dev/null -w '%{url_effective}' https://github.com/freelensapp/freelens/releases/latest)
  ver=${tag##*/v}
  curl -fsSLo /tmp/freelens.deb "https://github.com/freelensapp/freelens/releases/download/v$ver/Freelens-${ver}-linux-amd64.deb"
  sudo apt install -y /tmp/freelens.deb
  rm /tmp/freelens.deb
fi

for src in /usr/share/icons/hicolor/*/apps/freelens.png; do
  dir=${src#/usr/share/icons/}; dir=~/.local/share/icons/${dir%/*}
  mkdir -p "$dir"
  fit_icon "$src" "$dir/freelens.png"
done

if [ ! -x /opt/studio-3t/Studio-3T ]; then
  sudo install -d -o "$USER" -g "$USER" /opt/studio-3t
  curl -fsSL https://download.studio3t.com/studio-3t/linux/2026.13.1/studio-3t-linux-x64.tar.gz \
    | tar -xz -C /tmp
  sh /tmp/studio-3t-linux-x64.sh -q -dir /opt/studio-3t
  rm /tmp/studio-3t-linux-x64.sh
fi

sed -i 's/^createDesktopLinkAction\$Boolean=true$/createDesktopLinkAction$Boolean=false/' \
  /opt/studio-3t/.install4j/response.varfile
rm -f ~/Desktop/"Studio 3T.desktop"

mkdir -p ~/.local/share/icons/hicolor/512x512@2/apps
jar=$(ls -v /opt/studio-3t/data-man-mongodb-ent-*.jar | tail -1)
unzip -p "$jar" t3/dataman/icons/mac/1024.png >/tmp/studio-3t.png
fit_icon /tmp/studio-3t.png ~/.local/share/icons/hicolor/512x512@2/apps/studio-3t.png
rm /tmp/studio-3t.png

service=$(cat <<'UNIT'
[Unit]
Description=Reapply the Studio 3T launcher fixes

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for f in %h/.local/share/applications/install4j_*-Studio-3T.desktop; do \
  [ -f "$$f" ] || continue; \
  t=$$(mktemp); \
  sed -e "s|^Name=.*|Name=Studio 3T|" -e "s|^Icon=.*|Icon=studio-3t|" \
    -e "s|^StartupWMClass=.*|StartupWMClass=Studio 3T|" \
    -e "s|^Exec=.*|Exec=env INSTALL4J_ADD_VM_PARAMS=-splash:/nonexistent /opt/studio-3t/Studio-3T %%U|" \
    "$$f" >"$$t"; \
  cmp -s "$$t" "$$f" || cat "$$t" >"$$f"; \
  rm "$$t"; \
done'
UNIT
)
path=$(cat <<'UNIT'
[Unit]
Description=Watch for Studio 3T's updater rewriting its launcher

[Path]
PathChanged=%h/.local/share/applications

[Install]
WantedBy=default.target
UNIT
)
unit=~/.config/systemd/user/studio-3t-launcher
if [ "$(cat "$unit.service" 2>/dev/null)" != "$service" ] ||
   [ "$(cat "$unit.path" 2>/dev/null)" != "$path" ]; then
  printf '%s\n' "$service" >"$unit.service"
  printf '%s\n' "$path" >"$unit.path"
  systemctl --user daemon-reload
fi
systemctl --user enable --now studio-3t-launcher.path
systemctl --user start studio-3t-launcher.service

mise use -g github:zsa/zapp

udev_rules=/etc/udev/rules.d/50-zsa.rules
udev_want='SUBSYSTEM=="usb", ATTR{idVendor}=="3297", TAG+="uaccess"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3297", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="df11", TAG+="uaccess"'
if [ "$(cat "$udev_rules" 2>/dev/null)" != "$udev_want" ]; then
  printf '%s\n' "$udev_want" | sudo tee "$udev_rules" >/dev/null
  sudo udevadm control --reload-rules
  sudo udevadm trigger
fi

NIC=enp12s0
CON=$(nmcli -t -f NAME,DEVICE con show | awk -F: -v d="$NIC" '$2==d{print $1; exit}')
if [ "$(nmcli -g 802-3-ethernet.wake-on-lan con show "$CON")" != magic ]; then
  sudo nmcli con mod "$CON" 802-3-ethernet.wake-on-lan magic
  sudo nmcli con up "$CON" >/dev/null
fi

sudo tee /etc/polkit-1/rules.d/50-suspend.rules >/dev/null <<RULES
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.suspend" ||
         action.id == "org.freedesktop.login1.suspend-multiple-sessions") &&
        subject.user == "$USER") {
        return polkit.Result.YES;
    }
});
RULES

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

if ! sudo cryptsetup luksDump "$LUKS" | grep -q systemd-tpm2; then
  sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$LUKS"
fi
if ! grep -q tpm2-device /etc/crypttab; then
  sudo sed -i 's/ luks$/ luks,tpm2-device=auto/' /etc/crypttab
fi
for k in /boot/vmlinuz-*; do
  sudo dracut --force --kver "${k#/boot/vmlinuz-}"
done
