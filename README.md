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

## windows

7800X3D, 1.9TB NVMe, MSI PRO B650-P WIFI.

1. Rufus: GPT/UEFI, no online account. Wipe both disks, install to the 1907GB drive,
   offline account `mapring`.
2. NVIDIA driver only, rest from Windows Update.
3. Admin PowerShell: `irm https://raw.githubusercontent.com/mapringg/machines/main/windows.ps1 | iex`
4. NVIDIA 3D settings: Max Frame Rate 237, V-Sync On, Low Latency On.
5. HDR on, HDR Calibration with monitor on True Black 400.
6. Games: V-Sync off, Reflex On.

BIOS: EXPO 1, Re-Size BAR, Secure Boot, fTPM on, CSM off. Fans PWM:

| CPU_FAN | SYS_FAN |
|---|---|
| 0 °C → 20% | 40 °C → 30% |
| 45 °C → 35% | 55 °C → 45% |
| 65 °C → 50% | 70 °C → 70% |
| 80 °C → 100% | 85 °C → 100% |

## apple

MacBook Air M3.

1. `bash <(curl -fsSL https://raw.githubusercontent.com/mapringg/machines/main/apple.sh)`

## Clients

The macOS and Windows setup scripts install Visual Studio Code, T3 Code, Grok Bot,
and Warp. Sign in to Tailscale, then:

- **VS Code:** install the Remote - SSH extension and connect to `mapring@ubuntu`.
- **T3 Code:** run `t3 pair --tailscale` on `ubuntu` and add the environment in the T3 Code
  desktop app using the pairing URL or code.
