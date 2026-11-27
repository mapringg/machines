# machines

`ubuntu` is the only machine you bootstrap manually. Every other machine only needs OS install + SSH over Tailscale — then open a T3 thread in `machines` on `ubuntu` and say `set up <machine>`.

## ubuntu

Getorli GT105, 8845HS, 32GB. Primary T3 Code node and central CLIProxyAPI + Executor hub.

1. BIOS: Auto Power ON, UMA frame buffer minimum.
2. Ubuntu Server 26.04: whole disk, LVM, no encryption, grow `ubuntu-lv` to max.
   Hostname `ubuntu`, user `mapring`, no OpenSSH.
3. `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh`
4. `bash <(curl -fsSL https://raw.githubusercontent.com/mapringg/machines/main/ubuntu.sh)`,
   then log out and in.
5. `gh auth login`, `sudo pro attach <token>`
6. Tailscale: set `--operator=$USER --advertise-routes=<company subnets>` and approve the routes
   (ensure the Tailscale ACL grants `autogroup:member` access to those subnets).
7. Clone and run `mapringg/environment` (`install.sh`, `secret setup`, rerun `install.sh`), then `t3 up`.

## infra

Beelink N150, 16GB, 500GB. Always-on Docker services (Wallos and shared DBs).

1. BIOS: Auto Power ON.
2. Ubuntu Server 26.04: whole disk, LVM, no encryption, grow `ubuntu-lv` to max.
   Hostname `infra`, user `mapring`, no OpenSSH.
3. `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh`
4. Open a T3 thread in `machines` on `ubuntu` and say: `set up infra`.

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
2. `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh`
3. Open a T3 thread in `machines` on `ubuntu` and say: `set up desktop`.

### windows

1. Rufus: GPT/UEFI, no online account. Install to the 2TB NVMe, offline account `mapring`.
2. NVIDIA driver only, rest from Windows Update.
3. Install Tailscale, then enable OpenSSH Server in Admin PowerShell:
   `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; Start-Service sshd; Set-Service -Name sshd -StartupType Automatic`
4. Open a T3 thread in `machines` on `ubuntu` and say: `set up windows`.

## apple

MacBook Air M3, 16GB, 512GB.

1. Enable **System Settings → General → Sharing → Remote Login** (with full disk access) and
   Tailscale CLI integration (`/usr/local/bin/tailscale`).
2. Open a T3 thread in `machines` on `ubuntu` and say: `set up apple`.
