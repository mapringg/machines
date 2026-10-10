# machines

`server` does all development. `windows` (desk, games) and `macbook` (away) are clients
over Tailscale: VS Code Remote-SSH, T3 Code as a Chrome bookmark. GitHub is the backup.

Reinstall only when a machine is new or broken. Have 1Password's Emergency Kit first.

## server

Getorli GT105, 8845HS, 32GB.

1. **BIOS:** Auto Power ON, UMA frame buffer minimum.
2. **Install** Ubuntu Server 26.04:
   - Network: the unplugged port's IPv4 Disabled
   - Storage: whole disk, LVM, no encryption; grow `ubuntu-lv` to the maximum
   - Hostname `server`, user `mapring`, OpenSSH unticked
3. **Tailscale,** at the console; the rest is over SSH:
   ```
   curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh
   ```
4. **Script,** then log out and back in for the `docker` group:
   ```
   bash <(curl -fsSL https://raw.githubusercontent.com/mapringg/machines/main/server.sh)
   ```
5. **Sign in:** `claude`, `codex`, `gh auth login`. Clone repos, restore `~/.kube` and
   `.env` files.
6. **T3 Code:** bookmark the URL this prints in Chrome on each client:
   ```
   sudo tailscale set --operator=$USER && t3 pair --tailscale
   ```

## windows

Desktop, 1.9TB NVMe.

1. **USB:** Rufus, GPT / UEFI, tick only "remove requirement for an online Microsoft
   account".
2. **Install:** delete all partitions on both disks, install to the 1907GB drive.
   Offline account `mapring`.
3. **Drivers:** NVIDIA from nvidia.com, Custom, driver only. The rest from Windows
   Update; skip the MSI Driver Utility.
4. **Script,** in PowerShell as Administrator:
   ```
   irm https://raw.githubusercontent.com/mapringg/machines/main/windows.ps1 | iex
   ```
5. **Sign in:** 1Password extension in Chrome, Tailscale, Wispr Flow, Steam, Discord,
   VS Code Settings Sync.
6. **Settings:**
   - About → Rename this PC: `windows`
   - Personalization → Colors: Dark
   - Mouse → Additional mouse settings: untick "Enhance pointer precision"
   - Display → Graphics → Advanced: "Optimizations for windowed games" on
7. **NVIDIA Control Panel:**
   - Resolution: MSI 3840x2160 @ 240Hz, LG 2560x1440 @ 165Hz
   - G-SYNC: full screen and windowed, "G-SYNC Compatible", on both monitors
   - 3D settings: Max Frame Rate 237, Vertical sync On, Low Latency Mode On
8. **Display:**
   - LG portrait, 100%, left of the MSI
   - MSI 150%, main display, HDR on
   - Windows HDR Calibration, monitor on True Black 400
   - "SDR content brightness" to match the LG
9. **Each game:** V-Sync off, NVIDIA Reflex On.

### BIOS

MSI PRO B650-P WIFI. After a CMOS reset, EXPO Profile 1 and these fan curves, both PWM:

| CPU_FAN | SYS_FAN |
|---|---|
| 0 °C → 20% | 40 °C → 30% |
| 45 °C → 35% | 55 °C → 45% |
| 65 °C → 50% | 70 °C → 70% |
| 80 °C → 100% | 85 °C → 100% |

Leave Re-Size BAR, Secure Boot and fTPM on, CSM off.

## macbook

MacBook Air M3.

1. **Setup Assistant,** then System Settings:
   - General → About → Name: `macbook`
   - Keyboard: key repeat fastest, delay shortest
2. **1Password** and **Tailscale** from Safari, signed in.
3. **Script,** in Terminal:
   ```
   bash <(curl -fsSL https://raw.githubusercontent.com/mapringg/machines/main/macbook.sh)
   ```
4. **Sign in:** 1Password extension in Chrome, Wispr Flow, VS Code Settings Sync.

## Rejected

- Server disk encryption: it never leaves the bedroom, and a TPM unlock can break on
  a BIOS update. If the SSD goes back under warranty, revoke its credentials.
- Ubuntu desktop: Windows is already there for games.
- Kubernetes on the clients: k9s on the server is enough.
- WSL2: unreliable after Windows Update reboots.
- Nix: far from defaults, and doesn't cover Windows.
- T3 Code desktop app: the server's page always matches its version.
- Web database tools: they need MongoDB 4.2; work runs 4.0.
