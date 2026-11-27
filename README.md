# machines

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
4. `bash <(curl -fsSL https://raw.githubusercontent.com/mapringg/machines/main/ubuntu.sh)`,
   then log out and in.
5. Wallos: copy `wallos/compose.yml` to `~/wallos/`, extract the `data/` backup alongside it,
   run `docker compose up -d`, and expose over Tailscale with `sudo tailscale serve --bg 8282`.

## desktop / windows

7800X3D, 32GB, 2× 1TB NVMe, MSI PRO B650-P WIFI.

BIOS: EXPO 1, Re-Size BAR, Secure Boot, fTPM on, CSM off, `Resume By PCI-E Device` on,
`ErP Ready` off, Ubuntu NVMe first in boot order. Fans PWM:

| CPU_FAN | SYS_FAN |
|---|---|
| 0 °C → 20% | 40 °C → 30% |
| 45 °C → 35% | 55 °C → 45% |
| 65 °C → 50% | 70 °C → 70% |
| 80 °C → 100% | 85 °C → 100% |

### desktop

1. Ubuntu Desktop 26.10: install on the 2nd NVMe with its own EFI partition and third-party
   graphics drivers enabled. Hostname `desktop`, user `mapring`. Disable automatic suspend.
2. GRUB: set `GRUB_DISABLE_OS_PROBER=false` in `/etc/default/grub` and run `sudo update-grub`.
   One-shot reboot to Windows: `sudo grub-reboot "Windows Boot Manager" && sudo reboot`.
3. Wake-on-LAN (Ethernet): `nmcli connection modify <conn> 802-3-ethernet.wake-on-lan magic`.
   Wake from `ubuntu` with `wakeonlan <MAC>`.
4. `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh`
5. `bash <(curl -fsSL https://raw.githubusercontent.com/mapringg/machines/main/ubuntu.sh)`,
   then log out and in.
6. `gh auth login`

### windows

1. Rufus: GPT/UEFI, no online account. Install to the 1st NVMe, offline account `mapring`.
2. NVIDIA driver only, rest from Windows Update.
3. Admin PowerShell: `irm https://raw.githubusercontent.com/mapringg/machines/main/windows.ps1 | iex`
4. NVIDIA 3D settings: Max Frame Rate 237, V-Sync On, Low Latency On.
5. HDR on, HDR Calibration with monitor on True Black 400.
6. Games: V-Sync off, Reflex On.

## apple

MacBook Air M3.

1. `bash <(curl -fsSL https://raw.githubusercontent.com/mapringg/machines/main/apple.sh)`

## clients

The macOS and Windows setup scripts install Visual Studio Code, T3 Code, Grok Bot,
Warp, and the [Paper Mono](https://paper.design/mono) font. Sign in to Tailscale, then:

- **VS Code:** install the Remote - SSH extension and connect to `mapring@ubuntu` or `mapring@desktop`.
- **T3 Code:** run `t3 pair --tailscale` on `ubuntu` / `desktop` and add each environment in the
  T3 Code desktop app using the pairing URL or code.
- **Paper Mono:** in T3 Code, pick it under Settings → Appearance → Monospace font, which also
  covers the terminal. In Warp, pick it under Settings → Appearance → Text → Terminal font.
