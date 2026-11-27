#!/usr/bin/env bash
set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

t3_deb=$(curl -fsSL https://api.github.com/repos/pingdotgg/t3code/releases/latest |
	jq -r 'first(.assets[] | select(.name | endswith("-amd64.deb")) | .browser_download_url)')

curl -fsSL "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -o "$tmp/chrome.deb"
curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" -o "$tmp/vscode.deb"
curl -fsSL "https://downloads.1password.com/linux/debian/amd64/stable/1password-latest.deb" -o "$tmp/1password.deb"
curl -fsSL "https://app.warp.dev/download?package=deb" -o "$tmp/warp.deb"
curl -fsSL "$t3_deb" -o "$tmp/t3-code.deb"

sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y python3-pil \
	"$tmp/chrome.deb" "$tmp/vscode.deb" "$tmp/1password.deb" "$tmp/warp.deb" "$tmp/t3-code.deb"

curl -fsSL "https://github.com/paper-design/paper-mono/releases/download/v1.000/paper-mono-v1.000.zip" -o "$tmp/paper-mono.zip"
echo "8642652985dc87bf4cfd07c89942899e611c3c774fc25284c0dd4fe86a993a13  $tmp/paper-mono.zip" | sha256sum -c -
unzip -qo "$tmp/paper-mono.zip" -d "$tmp/paper-mono"
mkdir -p ~/.local/share/fonts/paper-mono
cp "$tmp"/paper-mono/paper-mono-v1.000/fonts/ttf/*.ttf ~/.local/share/fonts/paper-mono/
fc-cache -f

# GRUB dual-boot: Ubuntu default, 5s menu, os-prober enabled, dynamic reboot-windows helper
for kv in \
	"GRUB_DEFAULT=saved" \
	"GRUB_SAVEDEFAULT=false" \
	"GRUB_DISABLE_OS_PROBER=false" \
	"GRUB_TIMEOUT_STYLE=menu" \
	"GRUB_TIMEOUT=5"; do
	k="${kv%%=*}"
	if sudo grep -qE "^#*${k}=" /etc/default/grub; then
		sudo sed -i "s|^#*${k}=.*|${kv}|" /etc/default/grub
	else
		echo "$kv" | sudo tee -a /etc/default/grub >/dev/null
	fi
done
sudo update-grub
sed -i '/^alias reboot-windows=/d; /^reboot-windows()/d' ~/.bashrc
cat <<'EOF' >>~/.bashrc
reboot-windows() { local e; e=$(sudo grep -oP "menuentry '\KWindows Boot Manager[^']*" /boot/grub/grub.cfg | head -n 1); [[ -n "$e" ]] || { echo "Windows Boot Manager entry not found in /boot/grub/grub.cfg" >&2; return 1; }; sudo grub-reboot "$e" && sudo reboot; }
EOF

# Hide btop from GNOME App Grid
mkdir -p ~/.local/share/applications
if [[ -f /usr/share/applications/btop.desktop ]]; then
	cp /usr/share/applications/btop.desktop ~/.local/share/applications/btop.desktop
	grep -q '^NoDisplay=' ~/.local/share/applications/btop.desktop &&
		sed -i 's/^NoDisplay=.*/NoDisplay=true/' ~/.local/share/applications/btop.desktop ||
		echo 'NoDisplay=true' >>~/.local/share/applications/btop.desktop
fi

# Normalize app icons to match 1Password's 476x476 (93%) proportions inside 512x512
python3 - <<'PY'
import os
from PIL import Image, ImageDraw

CANVAS, TARGET = 512, 476
specs = [
    ("google-chrome.desktop", "/usr/share/icons/hicolor/256x256/apps/google-chrome.png", "google-chrome.png", False),
    ("t3code.desktop", "/usr/share/icons/hicolor/512x512/apps/t3code.png", "t3code.png", False),
    ("dev.warp.Warp.desktop", "/usr/share/icons/hicolor/512x512/apps/dev.warp.Warp.png", "dev.warp.Warp.png", False),
    ("com.microsoft.VSCode.desktop", "/usr/share/pixmaps/vscode.png", "vscode.png", False),
    ("code.desktop", "/usr/share/pixmaps/vscode.png", "vscode.png", False),
    ("grok-bot.desktop", "/usr/share/icons/hicolor/512x512/apps/grok-bot.png", "grok-bot.png", True),
]
icon_dir = os.path.expanduser("~/.local/share/icons/hicolor/512x512/apps")
app_dir = os.path.expanduser("~/.local/share/applications")
os.makedirs(icon_dir, exist_ok=True)
os.makedirs(app_dir, exist_ok=True)

for desktop_file, src_icon, out_name, round_corners in specs:
    src_desktop = os.path.join("/usr/share/applications", desktop_file)
    if not (os.path.exists(src_desktop) and os.path.exists(src_icon)):
        continue
    im = Image.open(src_icon).convert("RGBA")
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    w, h = im.size
    scale = min(TARGET / w, TARGET / h)
    nw, nh = round(w * scale), round(h * scale)
    resized = im.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    ox, oy = (CANVAS - nw) // 2, (CANVAS - nh) // 2
    if round_corners:
        mask = Image.new("L", (nw, nh), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, nw - 1, nh - 1), radius=int(min(nw, nh) * 0.225), fill=255)
        out.paste(resized, (ox, oy), mask)
    else:
        out.paste(resized, (ox, oy), resized)
    dst_icon = os.path.join(icon_dir, out_name)
    out.save(dst_icon)
    lines = [f"Icon={dst_icon}\n" if l.startswith("Icon=") else l for l in open(src_desktop)]
    open(os.path.join(app_dir, desktop_file), "w").writelines(lines)
PY
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor 2>/dev/null || true
update-desktop-database ~/.local/share/applications 2>/dev/null || true

# GNOME desktop polish: dark mode, pure black OLED background, fast key repeat, OLED screen blank, no suspend, vanilla shell, clean dock
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
if command -v gsettings >/dev/null 2>&1; then
	gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
	gsettings set org.gnome.desktop.background picture-options 'none'
	gsettings set org.gnome.desktop.background primary-color '#000000'
	gsettings set org.gnome.desktop.background color-shading-type 'solid'
	gsettings set org.gnome.desktop.background picture-uri ''
	gsettings set org.gnome.desktop.background picture-uri-dark ''
	gsettings set org.gnome.desktop.peripherals.keyboard delay 225
	gsettings set org.gnome.desktop.peripherals.keyboard repeat-interval 30
	gsettings set org.gnome.desktop.session idle-delay 300
	gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
	gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
	gsettings set org.gnome.shell disable-user-extensions true
	gsettings set org.gnome.shell app-picker-layout "[]"
	if [[ -f /usr/share/applications/grok-bot.desktop ]]; then
		gsettings set org.gnome.shell favorite-apps "['google-chrome.desktop', 'grok-bot.desktop', 't3code.desktop', 'dev.warp.Warp.desktop']"
	else
		gsettings set org.gnome.shell favorite-apps "['google-chrome.desktop', 't3code.desktop', 'dev.warp.Warp.desktop']"
	fi
fi

sudo nmcli radio wifi off 2>/dev/null || true
sudo rfkill block bluetooth 2>/dev/null || true
sudo tailscale set --operator="$USER" --accept-routes

echo "=== VERIFY desktop ==="
gsettings get org.gnome.desktop.interface color-scheme
gsettings get org.gnome.desktop.session idle-delay
gsettings get org.gnome.shell favorite-apps
nmcli radio wifi
tailscale debug prefs 2>/dev/null | jq -r '"RouteAll=\(.RouteAll)"' || true
