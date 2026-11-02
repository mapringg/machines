# machines

`ubuntu` does all development. `windows` (desk, games) and `apple` (away) are clients
over Tailscale: VS Code Remote-SSH, T3 Code in Chrome. GitHub is the backup.

Use the matching machine section for setup; reinstall only when a machine is new or
broken. Have 1Password's Emergency Kit before starting. Installation steps erase
disks, so confirm the target machine and disks before proceeding.

The linked scripts define installed tools and automated configuration. The steps
below cover manual setup. For a repository change, review the local script; the
download commands run the version published on `main`.

## ubuntu

Getorli GT105, 8845HS, 32GB.

1. **BIOS:** Auto Power ON, UMA frame buffer minimum.
2. **Install** Ubuntu Server 26.04:
   - Storage: whole disk, LVM, no encryption; grow `ubuntu-lv` to the maximum
   - Hostname `ubuntu`, user `mapring`, OpenSSH unticked
3. **Tailscale,** at the console; the rest is over SSH:
   ```
   curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh
   ```
4. **[Script](ubuntu.sh),** then log out and back in. Confirm `id -nG` includes
   `docker`:
   ```
   bash <(curl -fsSL https://raw.githubusercontent.com/mapringg/machines/main/ubuntu.sh)
   ```
5. **Sign in:** `gh auth login`, and Ubuntu Pro (Livepatch, ESM) with the token from
   ubuntu.com/pro: `sudo pro attach <token>`.
6. **T3 Code:** open the URL this prints in Chrome on each client:
   ```
   sudo tailscale set --operator=$USER && t3 pair --tailscale
   ```
7. **Obsidian Sync,** once the end-to-end encrypted remote vault `vault` exists:
   ```
   ob login && ob sync-setup --vault vault --path ~/vault --device-name ubuntu
   systemctl --user enable --now obsidian-sync
   ```

Setup is complete when a new Tailscale SSH session reaches `ubuntu`, `gh auth status`
shows the intended account, `pro status` shows Livepatch and ESM enabled, and
`systemctl --user status obsidian-sync` shows the service running with the remote
vault's contents appearing in `~/vault`. Check client access using
[Client connections](#client-connections).

### Design decisions

- Disk encryption stays off: this machine stays in the bedroom, and a TPM unlock can
  break on a BIOS update. If the SSD goes back under warranty, revoke its credentials.
- Use the server without a desktop; Windows handles games.
- Use native Linux development; WSL2 was unreliable after Windows Update reboots.
- Use platform package managers; Nix is far from defaults and does not cover Windows.
- Use local database tools compatible with work's MongoDB 4.0; the web tools considered
  required MongoDB 4.2.

## windows

Desktop, 7800X3D, 1.9TB NVMe.

1. **USB:** Rufus, GPT / UEFI, tick only "remove requirement for an online Microsoft
   account".
2. **Install:** delete all partitions on both disks, install to the 1907GB drive.
   Offline account `mapring`.
3. **Drivers:** NVIDIA from nvidia.com, Custom, driver only. The rest from Windows
   Update; skip the MSI Driver Utility.
4. **[Script](windows.ps1),** in PowerShell:
   ```
   irm https://raw.githubusercontent.com/mapringg/machines/main/windows.ps1 | iex
   ```
5. **Settings:**
   - About → Rename this PC: `windows`
   - Personalization → Colors: Dark
   - Mouse → Additional mouse settings: untick "Enhance pointer precision"
   - Display → Graphics → Advanced: "Optimizations for windowed games" on
6. **NVIDIA Control Panel** → 3D settings: Max Frame Rate 237, Vertical sync On, Low
   Latency Mode On.
7. **HDR:** on for the MSI, then Windows HDR Calibration with the monitor on True Black
   400.
8. **Each game:** V-Sync off, NVIDIA Reflex On.

Finish with the [client connection checks](#client-connections).

### BIOS after a CMOS reset

MSI PRO B650-P WIFI: select EXPO Profile 1 and these fan curves, both PWM:

| CPU_FAN | SYS_FAN |
|---|---|
| 0 °C → 20% | 40 °C → 30% |
| 45 °C → 35% | 55 °C → 45% |
| 65 °C → 50% | 70 °C → 70% |
| 80 °C → 100% | 85 °C → 100% |

Leave Re-Size BAR, Secure Boot and fTPM on, CSM off.

## apple

MacBook Air M3.

1. **Setup Assistant,** then System Settings:
   - General → About → Name: `apple`
   - Keyboard: key repeat fastest, delay shortest
2. **[Script](apple.sh),** in Terminal:
   ```
   bash <(curl -fsSL https://raw.githubusercontent.com/mapringg/machines/main/apple.sh)
   ```

Finish with the [client connection checks](#client-connections).

## Client connections

On each client, sign in to Tailscale on the same tailnet as `ubuntu`. Setup is complete
when VS Code Remote-SSH can open a folder as `mapring` on `ubuntu`, and Chrome can open
the T3 Code page paired in the [Ubuntu setup](#ubuntu).

Use T3 Code through Ubuntu's page so the client always matches its version. Run
Kubernetes tooling on `ubuntu`; its k9s installation covers the clients' needs.
