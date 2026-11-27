# machines

`ubuntu` is the only machine you bootstrap manually. Before reinstalling any existing machine, delete its old node in the Tailscale admin console so it keeps its clean hostname. For every machine other than `ubuntu`, just finish OS install + SSH over Tailscale, then open a T3 thread in `machines` on `ubuntu` and say `set up <machine>`.

## ubuntu

Getorli GT105, 8845HS, 32GB. Primary T3 Code node and sole central hub for CLIProxyAPI (`:8317`), Executor (`:4789`), and Zanroo VPN (`wg0`).

1. BIOS: Auto Power ON, UMA frame buffer minimum.
2. Ubuntu Server 26.04: whole disk, LVM, no encryption, grow `ubuntu-lv` to max.
   Hostname `ubuntu`, user `mapring`, no OpenSSH.
3. `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh --operator="$USER"`
4. `bash <(curl -fsSL https://raw.githubusercontent.com/mapringg/machines/main/ubuntu.sh)`,
   then log out and in.
5. `gh auth login`, `sudo pro attach <token>`
6. Clone `mapringg/environment` into `~/code/mapringg/environment`, run `install.sh`, run `secret setup`
   (1Password item `1Password Service Account (Dev)`), and rerun `install.sh` (starts `wg0`, `cliproxyapi`,
   `executor`, and saves `mapringg.executor-auth`). If rebuilding an existing hub, rerun
   `environment/install.sh` on spokes (`desktop`, `apple`) so they pull the refreshed `mapringg.executor-auth` token.
7. Advertise the `AllowedIPs` subnets from `/etc/wireguard/wg0.conf` via
   `sudo tailscale set --operator=$USER --advertise-routes=<subnets>`, approve them in Tailscale admin,
   and ensure the Tailscale ACL grants `autogroup:member` access to those subnets.
8. Interactive hub auth: `cliproxy-login claude` and `cliproxy-login codex`, `t3 up --connect --lan`,
   `t3 pair --tailscale`, add usage hub `http://127.0.0.1:8317` in T3 Settings (key in
   `~/.config/cliproxy/management-key`), and complete Executor OAuth at `https://<ubuntu-dns>:4789`.

## infra

Beelink N150, 16GB, 500GB. Always-on Wallos host.

1. BIOS: Auto Power ON.
2. Ubuntu Server 26.04: whole disk, LVM, no encryption, grow `ubuntu-lv` to max.
   Hostname `infra`, user `mapring`, no OpenSSH.
3. `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh --operator="$USER"`
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
3. Install Tailscale (rename PC to `windows` first or pass `--hostname=windows`), then enable OpenSSH
   Server in Admin PowerShell:
   `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; Start-Service sshd; Set-Service -Name sshd -StartupType Automatic`
4. Open a T3 thread in `machines` on `ubuntu` and say: `set up windows`.

## apple

MacBook Air M3, 16GB, 512GB.

1. Install standalone Tailscale, sign in, and enable Tailscale CLI integration (`/usr/local/bin/tailscale`).
2. Enable **System Settings → General → Sharing → Remote Login** (with full disk access).
3. Open a T3 thread in `machines` on `ubuntu` and say: `set up apple`.
