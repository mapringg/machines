# machines

`ubuntu` does all development. `windows` (desk, games) and `apple` (away) are clients
over Tailscale: VS Code Remote-SSH, T3 Code in Chrome. GitHub is the backup.

Reinstall only when a machine is new or broken. Have 1Password's Emergency Kit first.

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
4. **Script,** then log out and back in for the `docker` group:
   ```
   bash <(curl -fsSL https://raw.githubusercontent.com/mapringg/machines/main/ubuntu.sh)
   ```
5. **Sign in:** `claude`, `codex`, `gh auth login`, and Ubuntu Pro (Livepatch, ESM) with
   the token from ubuntu.com/pro: `sudo pro attach <token>`.
6. **Agents:** skills, instructions, and settings from the private `skills` repo. In
   `codex`, trust the secrets guard once with `/hooks`.
   ```
   gh repo clone mapringg/skills ~/code/mapringg/skills
   bash ~/code/mapringg/skills/install.sh
   ```
7. **T3 Code:** open the URL this prints in Chrome on each client:
   ```
   sudo tailscale set --operator=$USER && t3 pair --tailscale
   ```
8. **Secrets:** paste the token from the 1Password item
   `1Password Service Account (Dev)`, then run `secret init <item>...` in each app
   folder (`secret list` shows the items).
   ```
   secret setup
   ```
9. **Obsidian Sync,** once the end-to-end encrypted remote vault `vault` exists:
   ```
   ob login && ob sync-setup --vault vault --path ~/vault --device-name ubuntu
   systemctl --user enable --now obsidian-sync
   ```

## windows

Desktop, 7800X3D, 1.9TB NVMe.

1. **USB:** Rufus, GPT / UEFI, tick only "remove requirement for an online Microsoft
   account".
2. **Install:** delete all partitions on both disks, install to the 1907GB drive.
   Offline account `mapring`.
3. **Drivers:** NVIDIA from nvidia.com, Custom, driver only. The rest from Windows
   Update; skip the MSI Driver Utility.
4. **Script,** in PowerShell:
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

### BIOS

MSI PRO B650-P WIFI. After a CMOS reset, EXPO Profile 1 and these fan curves, both PWM:

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
2. **Script,** in Terminal:
   ```
   bash <(curl -fsSL https://raw.githubusercontent.com/mapringg/machines/main/apple.sh)
   ```

## Rejected

- Disk encryption on `ubuntu`: it never leaves the bedroom, and a TPM unlock can break
  on a BIOS update. If the SSD goes back under warranty, revoke its credentials.
- A desktop on `ubuntu`: Windows is already there for games.
- Kubernetes on the clients: k9s on `ubuntu` is enough.
- WSL2: unreliable after Windows Update reboots.
- Nix: far from defaults, and doesn't cover Windows.
- T3 Code desktop app: `ubuntu`'s page always matches its version.
- Web database tools: they need MongoDB 4.2; work runs 4.0.
