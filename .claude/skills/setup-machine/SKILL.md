---
name: setup-machine
description: Bootstrap, reinstall, or sync a machine in the fleet and verify its services.
---

# Set up a machine

`ubuntu` is the sole hub (CLIProxyAPI `:8317`, Executor `:4789`, Zanroo VPN `wg0`) and the only machine bootstrapped manually. Before reinstalling an existing machine, delete its old node in Tailscale admin so it keeps its hostname.

For every other machine, finish **Install**, then open a T3 thread in `machines` on `ubuntu` and say `set up <machine>`.

## `ubuntu`

Getorli GT105, 8845HS, 32GB.

1. BIOS: Auto Power ON, UMA frame buffer minimum.
2. Ubuntu Server 26.04: whole disk, LVM, no encryption, grow `ubuntu-lv` to max. Hostname `ubuntu`, user `mapring`, no OpenSSH.
3. `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh --operator="$USER"`
4. Run `ubuntu.sh`, then log out and in.
5. `gh auth login`, `sudo pro attach <token>`
6. Clone `mapringg/environment` into `~/code/mapringg/environment`, run `install.sh`, run `secret setup` (1Password `1Password Service Account (Dev)`), and rerun `install.sh`. If rebuilding an existing hub, rerun `environment/install.sh` on spokes (`desktop`, `apple`).
7. Advertise the `AllowedIPs` subnets from `/etc/wireguard/wg0.conf` via `sudo tailscale set --operator=$USER --advertise-routes=<subnets>`, approve them in Tailscale admin, and allow `autogroup:member` access in Tailscale ACLs.
8. Interactive auth: `cliproxy-login claude`, `cliproxy-login codex`, `t3 up --connect --lan`, `t3 pair --tailscale`, add usage hub `http://127.0.0.1:8317` in T3 Settings (key in `~/.config/cliproxy/management-key`), and complete Executor OAuth at `https://<ubuntu-dns>:4789`.

## `infra`

Beelink N150, 16GB, 500GB. Always-on Wallos host.

### Install

1. BIOS: Auto Power ON.
2. Ubuntu Server 26.04: whole disk, LVM, no encryption, grow `ubuntu-lv` to max. Hostname `infra`, user `mapring`, no OpenSSH.
3. `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh --operator="$USER"`

### Setup (`set up infra`)

1. Copy `ubuntu.sh` and `wallos/compose.yml` to `infra:~/wallos/`. On a **fresh install only** (`~/wallos/data/db/wallos.db` absent), copy `ubuntu:~/backups/wallos/latest.tar.gz` to `infra:~/wallos/` and atomically restore it:
   ```sh
   cd ~/wallos && test ! -e data && tmp=$(mktemp -d ~/wallos/.restore.XXXXXX) && tar -xzf latest.tar.gz -C "$tmp" && test -f "$tmp/data/db/wallos.db" && mv -T "$tmp/data" data && test -f data/db/wallos.db && rm -rf "$tmp" latest.tar.gz
   ```
2. Run `ubuntu.sh` in a PTY, then reconnect so the `docker` group applies.
3. If Wi-Fi only, mark the unplugged Ethernet NIC `optional: true` in `/etc/netplan/99-optional-ethernet.yaml` and `sudo netplan apply`.
4. In `~/wallos/`: `docker compose up -d` and `sudo tailscale serve --bg 8282`. Verify `https://infra.<tailnet>/` returns `302` and `wallos-backup.timer` on `ubuntu` pulls cleanly.

## `desktop` / `windows`

7800X3D, 32GB, RTX 4080, 2TB NVMe (`windows`) + 1TB NVMe (`desktop`), MSI PRO B650-P WIFI.

BIOS: EXPO 1, Re-Size BAR, Secure Boot, fTPM on, CSM off, `Resume By PCI-E Device` on, `ErP Ready` off, Ubuntu NVMe first in boot order. Fans PWM:

| CPU_FAN     | SYS_FAN     |
| ----------- | ----------- |
| 0 °C → 20%  | 40 °C → 30% |
| 45 °C → 35% | 55 °C → 45% |
| 65 °C → 50% | 70 °C → 70% |
| 80 °C → 100% | 85 °C → 100% |

### `desktop`

#### Install

1. Ubuntu Desktop 26.10 on the 1TB NVMe (own EFI partition, third-party graphics drivers enabled). Hostname `desktop`, user `mapring`.
2. `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --ssh`

#### Setup (`set up desktop`)

1. **Manual:** Display settings (VRR on, 240Hz, HDR on, 150% scale) and install Grok Bot `amd64.deb` from `x.ai/bot`.
2. Run `ubuntu.sh` and `desktop.sh` in a PTY.
3. Enable Wake-on-LAN (`sudo nmcli connection modify <eth-conn> 802-3-ethernet.wake-on-lan magic`) and save the Ethernet MAC to 1Password `mapringg.machines.ops` (`DESKTOP_MAC --plain`). Wake from `ubuntu` with `wakeonlan <DESKTOP_MAC>`.
4. Clone `mapringg/environment` into `~/code/mapringg/environment`, run `install.sh`, complete `secret setup`, and rerun `install.sh`.
5. **Manual:** `gh auth login` (SSH, skip key upload), `t3 up --connect --lan`, `t3 pair --tailscale`. In T3 Code: **Local environment OFF**, pair `desktop`, link two-way with `ubuntu`/`apple`, enable Load balancing + PR sharing, pick Paper Mono in T3 Code & Warp. After the first Antigravity turn, rerun `environment/install.sh`; run `/hooks` once in Codex.
6. Verify `t3code.service` active, `Linger=yes`, `RouteAll: True`, hub CLIProxyAPI/Executor reachability, and Zanroo VPN via `ubuntu`.

### `windows`

#### Install

1. Rufus: GPT/UEFI, no online account. Install to the 2TB NVMe, offline account `mapring`.
2. NVIDIA driver only; rest from Windows Update.
3. Install Tailscale (PC name `windows` or `--hostname=windows`), then in Admin PowerShell:
   `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; Start-Service sshd; Set-Service -Name sshd -StartupType Automatic`

#### Setup (`set up windows`)

1. **Manual (Admin PowerShell):** Authorize `ubuntu`'s `~/.ssh/id_ed25519.pub` in `C:\ProgramData\ssh\administrators_authorized_keys` (`icacls ... /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"`).
2. `scp` `windows.ps1` to `windows`, run via `powershell -NoProfile -ExecutionPolicy Bypass -File <temp-path>` (not stdin, so `$ErrorActionPreference = 'Stop'` halts on errors), then delete the temp file. Reboot if renamed.
3. **Manual:** NVIDIA 3D settings (Max Frame Rate 237, V-Sync On, Low Latency On), HDR + True Black 400 calibration, in-game V-Sync off + Reflex On, and connect T3 Code to `ubuntu` (Local environment OFF, Paper Mono).

## `apple`

MacBook Air M3, 16GB, 512GB.

### Install

1. Install standalone Tailscale, sign in, and enable CLI integration (`/usr/local/bin/tailscale`).
2. Enable **System Settings → General → Sharing → Remote Login** (with Full Disk Access).

### Setup (`set up apple`)

1. Add `ubuntu`'s `~/.ssh/id_ed25519.pub` to `apple:~/.ssh/authorized_keys`.
2. Run `apple.sh` in a PTY, then clone `mapringg/environment` and run `install.sh`.
3. **Manual:** Click through OrbStack's first-run prompt, then complete `secret setup`.
4. Rerun `environment/install.sh` and verify `ssh -T git@github.com`, `docker --version`, `RouteAll: True`, and hub Executor reachability.
5. **Manual:** `gh auth login` (SSH, skip key upload). In T3 Code: **Local environment ON**, enable Tailscale HTTPS, link two-way with `ubuntu`/`desktop`, set Load balancing (`apple` Less often or manual). Log out/in if Dark mode or key repeat hasn't refreshed.

## Agent execution

Use a PTY for sudo on Ubuntu. Give one exact instruction for each manual step, wait, and verify.

Request passwords through `request_secret` with file delivery. Store machine passwords in `mapringg.machines.ops`. For `secret setup` on spokes, request the Dev service account through that tool and pipe the file to the remote setup command.
