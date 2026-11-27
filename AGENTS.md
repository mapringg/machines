# Machines

## Sources

- Use [PR writing](https://github.com/mapringg/standard/blob/v1.11.0/.claude/skills/pr/SKILL.md) when writing a pull request.
- Follow [Capture](https://github.com/mapringg/standard/blob/v1.11.0/.claude/skills/capture/SKILL.md) when preparing pull request evidence.

## Provisioning Runbook

When the user asks to `set up <machine>` (or sync an existing machine), drive the checklist below
step-by-step from `ubuntu`:

- Do every **[Agent]** step over SSH automatically.
- Whenever a **[User]** step is needed, give one short, exact instruction, wait for confirmation,
  verify it worked, and continue.
- Never ask for passwords in chat — use `request_secret` (`delivery: "file"`), and store new machine
  passwords in 1Password under `mapringg.machines.ops`.
- `ubuntu` is the **sole hub** for CLIProxyAPI (`:8317`) and Executor (`:4789`). Never run
  `cliproxyapi` or a local `executor` daemon on spoke machines (`desktop`, `apple`).
- This repo is public — never commit secrets, MAC addresses, or tailnet IDs.

### `infra` (Ubuntu Server 26.04, Beelink N150)

1. **[Agent]** Copy `ubuntu.sh`, `wallos/compose.yml`, and the Wallos `data/` backup to `infra`.
2. **[Agent]** Run `ubuntu.sh` over SSH (using a PTY for Ubuntu 26.04 `sudo-rs` prompt matching `password:`).
3. **[Agent]** If Ethernet is unplugged (Wi-Fi only), add `/etc/netplan/99-optional-ethernet.yaml`
   marking the Ethernet NIC `optional: true`, then `sudo netplan generate && sudo netplan apply`.
4. **[Agent]** Start Wallos (`docker compose up -d` in `~/wallos/`) and expose over Tailscale
   (`sudo tailscale serve --bg 8282`). Verify `https://infra.<tailnet>/` returns `HTTP 302`.

### `desktop` (Ubuntu Desktop 26.10, 7800X3D + RTX 4080)

1. **[User]** Set Display: VRR on, max refresh rate (240Hz), HDR on, 150% scale. Download Grok Bot
   `amd64.deb` from `x.ai/bot` and install it (`sudo apt install ~/Downloads/grok-bot_*_amd64.deb`).
2. **[Agent]** Run `ubuntu.sh` and `desktop.sh` (`DEBIAN_FRONTEND=noninteractive`, Paper Mono,
   93% normalized/rounded icons, 4-app dock, A–Z App Grid, dark mode, pure black OLED background,
   fast key repeat, 5-min OLED screen blank, no suspend, Wi-Fi/BT off, `tailscale set --accept-routes`).
3. **[Agent]** Configure GRUB dual-boot: set `GRUB_DEFAULT=saved`, `GRUB_SAVEDEFAULT=false`,
   `GRUB_DISABLE_OS_PROBER=false`, `GRUB_TIMEOUT_STYLE=menu`, `GRUB_TIMEOUT=5` in `/etc/default/grub`,
   run `sudo update-grub`, and point `reboot-windows` in `~/.bashrc` to the exact
   `Windows Boot Manager (on /dev/nvme0n1p1)` entry.
4. **[Agent]** Enable Wake-on-LAN (`nmcli connection modify <eth-conn> 802-3-ethernet.wake-on-lan magic`)
   and `sudo tailscale set --operator=mapring`.
5. **[Agent]** Clone `mapringg/environment` into `~/code/mapringg/environment` and run `install.sh`.
6. **[User]** Open a new terminal and run `secret setup` (paste `1Password Service Account (Dev)` token).
7. **[Agent]** Rerun `environment/install.sh` (restores SSH keys, kubeconfig, npmrc, and `ubuntu`
   CLIProxyAPI + Executor hub routing). Verify `ssh -T git@github.com` and remote Executor integrations.
8. **[User]** Run `gh auth login` (SSH, skip key upload), `t3 up --connect --lan`, and
   `t3 pair --tailscale`. In T3 Code, turn **Local environment OFF**, add `desktop` via the pairing URL,
   and link two-way with `ubuntu` + `apple` (Load balancing: `ubuntu`/`desktop` Prefer, `apple` Less often;
   Pull request sharing ON; pick Paper Mono in T3 Code and Warp).
9. **[Agent]** Verify `t3code.service` active, `Linger=yes`, `RouteAll: True`, and T3 link reachable.

### `apple` (macOS, MacBook Air M3)

1. **[Agent]** Install `ubuntu`'s `~/.ssh/id_ed25519.pub` into `apple:~/.ssh/authorized_keys` for
   passwordless SSH.
2. **[Agent]** Run `apple.sh` (CLI + GUI + OrbStack + 4-app Dock + Dark mode + pure black wallpaper +
   `mise activate zsh`) and clone + run `mapringg/environment/install.sh`.
3. **[User]** Click through OrbStack's first-run prompt, then run `secret setup` (`1Password Service Account (Dev)`).
4. **[Agent]** Rerun `environment/install.sh` (restores SSH keys and `ubuntu` hub routing). Verify
   `ssh -T git@github.com`, `docker --version`, and remote Executor integrations.
5. **[User]** Run `gh auth login` (SSH, skip key upload). In T3 Code, turn **Local environment ON**,
   enable Tailscale HTTPS, link two-way with `ubuntu` + `desktop`, and set Load balancing (`apple` Less often).

### `windows` (Windows 11, Gaming PC)

1. **[User]** Add `ubuntu`'s `~/.ssh/id_ed25519.pub` to `C:\ProgramData\ssh\administrators_authorized_keys`
   with `icacls ... /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"`.
2. **[Agent]** SSH in passwordless and run `windows.ps1` (pipe PowerShell over stdin to avoid `cmd.exe`
   quoting). Apply `black.bmp` via an interactive Session 1 scheduled task if running remotely over SSH.
   Verify `RouteAll: True` in Tailscale.
3. **[User]** Apply NVIDIA 3D settings (Max Frame Rate 237, V-Sync On, Low Latency On), HDR +
   True Black 400 calibration, and in-game V-Sync off + Reflex On.
