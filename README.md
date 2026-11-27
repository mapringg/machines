# machines

`ubuntu` is the only machine you bootstrap manually (it also hosts the central CLIProxyAPI and Executor hub). Every other machine only needs OS install + SSH over Tailscale, then hand off to the agent on `ubuntu` to run its scripts and `mapringg/environment`.

## ubuntu

Getorli GT105, 8845HS, 32GB.

1. BIOS: Auto Power ON, UMA frame buffer minimum.
2. Ubuntu Server 26.04: whole disk, LVM, no encryption, grow `ubuntu-lv` to max.
   Hostname `ubuntu`, user `mapring`, no OpenSSH.
3. `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh`
4. `bash <(curl -fsSL https://raw.githubusercontent.com/mapringg/machines/main/ubuntu.sh)`,
   then log out and in.
5. `gh auth login`, `sudo pro attach <token>`
6. Tailscale: set `--operator=$USER --advertise-routes=<company subnets>` and approve the routes.

## infra

Beelink N150, 16GB, 500GB. Always-on Docker services (Wallos and shared dev DBs).

1. BIOS: Auto Power ON.
2. Ubuntu Server 26.04: whole disk, LVM, no encryption, grow `ubuntu-lv` to max.
   Hostname `infra`, user `mapring`, no OpenSSH.
3. `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh`
4. Hand off to `ubuntu` agent: runs `ubuntu.sh`, marks unplugged Ethernet `optional: true` in netplan,
   deploys `wallos/compose.yml` with `data/` backup, and exposes Wallos via `tailscale serve --bg 8282`.

## desktop / windows

7800X3D, 32GB, RTX 4080, 2TB NVMe (`windows`) + 1TB NVMe (`desktop`), MSI PRO B650-P WIFI.

BIOS: EXPO 1, Re-Size BAR, Secure Boot, fTPM on, CSM off, `Resume By PCI-E Device` on,
`ErP Ready` off, Ubuntu NVMe first in boot order. Fans PWM:

| CPU_FAN | SYS_FAN |
|---|---|
| 0 °C → 20% | 40 °C → 30% |
| 45 °C → 35% | 55 °C → 45% |
| 65 °C → 50% | 70 °C → 70% |
| 80 °C → 100% | 85 °C → 100% |

### desktop

1. Ubuntu Desktop 26.10: install on the 1TB NVMe with its own EFI partition and third-party
   graphics drivers enabled. Hostname `desktop`, user `mapring`.
2. Display: VRR on, max refresh rate (240Hz), HDR on, 150% scale.
3. `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh`
4. Hand off to `ubuntu` agent: runs `ubuntu.sh`, `desktop.sh` (GUI apps, Paper Mono, rounded/normalized
   icons, 4-app dock, A–Z App Grid, dark mode, key repeat, 5-min OLED blanking, no suspend, Wi-Fi/BT off),
   GRUB `os-prober` (`reboot-windows`), Wake-on-LAN, and `mapringg/environment`.
5. Interactive: download Grok Bot `.deb` from `x.ai/bot` (then rerun `desktop.sh` to round/pin its icon),
   run `secret setup`, `gh auth login`, `t3 up --connect --lan`, and `t3 pair --tailscale`.

### windows

1. Rufus: GPT/UEFI, no online account. Install to the 2TB NVMe, offline account `mapring`.
2. NVIDIA driver only, rest from Windows Update.
3. Install Tailscale, then enable OpenSSH Server in Admin PowerShell:
   `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; Start-Service sshd; Set-Service -Name sshd -StartupType Automatic`
4. Hand off to `ubuntu` agent: runs `windows.ps1` (apps, Paper Mono, dark mode, pure black OLED
   wallpaper, fast key repeat, 5-min display off, Wi-Fi off, mouse/GPU tweaks).
5. NVIDIA 3D settings: Max Frame Rate 237, V-Sync On, Low Latency On.
6. HDR on, HDR Calibration with monitor on True Black 400.
7. Games: V-Sync off, Reflex On.

## apple

MacBook Air M3, 16GB, 512GB.

1. Enable **System Settings → General → Sharing → Remote Login** and Tailscale CLI integration.
2. Hand off to `ubuntu` agent: installs SSH key, runs `apple.sh` and `mapringg/environment`.
3. Interactive: `secret setup`, `gh auth login`, and enable T3 Code Local environment + Tailscale HTTPS.

## clients

The macOS, Windows, and Ubuntu Desktop scripts install Google Chrome, Visual Studio Code,
1Password, T3 Code, Warp, and the [Paper Mono](https://paper.design/mono) font. `ubuntu` hosts the
shared CLIProxyAPI (`:8317`) and Executor (`:4789`) hub; `desktop` and `apple` route to it over Tailscale.

- **T3 Code:** link `ubuntu`, `desktop`, and `apple` two-way; enable Load balancing (`ubuntu`/`desktop`
  Prefer, `apple` Less often) and Pull request sharing.
- **Paper Mono:** in T3 Code, pick it under Settings → Appearance → Monospace font, which also
  covers the terminal. In Warp, pick it under Settings → Appearance → Text → Terminal font.
