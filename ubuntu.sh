#!/usr/bin/env bash
set -euo pipefail

BACKUP=/dev/disk/by-label/Backup
[[ -e $BACKUP ]] || { echo "Plug in the Backup drive first." >&2; exit 1; }

if [ ! -f /etc/apt/sources.list.d/mise.list ]; then
  sudo install -dm755 /etc/apt/keyrings
  curl -fsSL https://mise.jdx.dev/gpg-key.pub \
    | sudo gpg --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg] https://mise.jdx.dev/deb stable main" \
    | sudo tee /etc/apt/sources.list.d/mise.list >/dev/null
fi

snap list code >/dev/null 2>&1 || sudo snap install code --classic

if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
  sudo install -dm755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
fi

command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh

tailscale status >/dev/null 2>&1 || sudo tailscale up --ssh

sudo apt update
sudo apt install -y git tmux lazygit deja-dup docker.io mise gh python3-pil

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

sudo usermod -aG docker "$USER"

gsettings set org.gnome.shell app-picker-layout "[]"

gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat'
gsettings set org.gnome.desktop.peripherals.mouse speed -0.33

gnome-extensions disable ding@rastersoft.com

gsettings set org.gnome.desktop.interface font-antialiasing 'grayscale'

gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Yaru-dark'

command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash

[ -x ~/.local/bin/codex ] || curl -fsSL https://chatgpt.com/codex/install.sh \
  | PATH="$HOME/.local/bin:$PATH" CODEX_NON_INTERACTIVE=1 sh

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
