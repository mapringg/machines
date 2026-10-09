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

mkdir -p ~/.local/share/applications
entry=~/.local/share/applications/t3code.desktop
want=$(sed 's/^StartupWMClass=.*/StartupWMClass=com.t3tools.T3Code/' /usr/share/applications/t3code.desktop)
[ "$(cat "$entry" 2>/dev/null)" = "$want" ] || printf '%s\n' "$want" >"$entry"

git config --global user.name "Sorawit Kongnurat"
git config --global user.email work@mapringg.com

if ! grep -qF 'mise activate bash' ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'

# Activate mise so the tools it manages are on the PATH
eval "$(mise activate bash)"
BASHRC
fi

mise use -g kubectl k9s

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
