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
- `ubuntu` is the **sole hub** for CLIProxyAPI (`:8317`), Executor (`:4789`), and Zanroo VPN (`wg0`).
  Never run `cliproxyapi`, a local `executor` daemon, or `wg0` on spoke machines (`desktop`, `apple`).
- This repo is public — never commit secrets, MAC addresses, or tailnet IDs.
- For `secret setup` on spokes, you may either ask the user to run it or request the `1Password Service Account (Dev)` token via `request_secret` (`delivery: "file"`) and pipe it to `ssh <host> '~/.local/bin/secret setup' < "$file"`.

### `infra` (Ubuntu Server 26.04, Beelink N150)

1. **[Agent]** Copy `ubuntu.sh` and `wallos/compose.yml` to `infra:~/wallos/`. **Only on a fresh install**
   (when `infra:~/wallos/data/db/wallos.db` does not already exist — never overwrite live Wallos data
   during a routine sync), copy `ubuntu:~/backups/wallos/latest.tar.gz` to `infra:~/wallos/`, stage
   extraction on the same filesystem (`cd ~/wallos && test ! -e data && tmp=$(mktemp -d ~/wallos/.restore.XXXXXX) && tar -xzf latest.tar.gz -C "$tmp" && test -f "$tmp/data/db/wallos.db" && mv -T "$tmp/data" data && test -f data/db/wallos.db && rm -rf "$tmp" latest.tar.gz`),
   and confirm `~/wallos/data/db/wallos.db` exists.
2. **[Agent]** Run `ubuntu.sh` over SSH in a PTY (Ubuntu 26.04 `sudo-rs` prompts `password:`), then
   reconnect in a fresh SSH session so `docker` group membership applies.
3. **[Agent]** If Ethernet is unplugged (Wi-Fi only), add `/etc/netplan/99-optional-ethernet.yaml`
   marking the Ethernet NIC `optional: true`, then `sudo netplan generate && sudo netplan apply`.
4. **[Agent]** Start Wallos (`docker compose up -d` in `~/wallos/` — bound to `127.0.0.1:8282`),
   expose over Tailscale (`sudo tailscale serve --bg 8282`), and verify `https://infra.<tailnet>/`
   returns `HTTP 302` and `docker exec wallos ls -la /var/www/html/db/wallos.db` shows the restored DB.
5. **[Agent]** Confirm `wallos-backup.timer` is active on `ubuntu` (`systemctl --user is-active wallos-backup.timer`;
   installed by `ubuntu.sh`) and run `systemctl --user start wallos-backup.service` once to verify backup pull.

### `desktop` (Ubuntu Desktop 26.10, 7800X3D + RTX 4080)

1. **[User]** Set Display: VRR on, max refresh rate (240Hz), HDR on, 150% scale. Download Grok Bot
   `amd64.deb` from `x.ai/bot` and install it (`sudo apt install ~/Downloads/grok-bot_*_amd64.deb`).
2. **[Agent]** Run `ubuntu.sh` and `desktop.sh` over SSH in a PTY (configures Docker, zram, `t3` CLI,
   GRUB `GRUB_DEFAULT=saved` + `os-prober` + dynamic `reboot-windows`, GUI apps, Paper Mono, 93%
   normalized/rounded icons, 4-app dock, A–Z grid, dark mode, pure black OLED background, fast key
   repeat, 5-min OLED screen blank, no suspend, Wi-Fi/BT off, and `tailscale set --operator=$USER --accept-routes`).
3. **[Agent]** Enable Wake-on-LAN (`sudo nmcli connection modify <eth-conn> 802-3-ethernet.wake-on-lan magic`)
   and save `desktop`'s Ethernet MAC to `mapringg.machines.ops` (`DESKTOP_MAC --plain`). To wake from
   `ubuntu`, run `wakeonlan <DESKTOP_MAC>`.
4. **[Agent]** Clone `mapringg/environment` into `~/code/mapringg/environment` and run `install.sh`.
5. **[User]** Run `secret setup` (or provide the token via `request_secret`).
6. **[Agent]** Rerun `environment/install.sh` (restores SSH keys, kubeconfig, npmrc, and `ubuntu`
   CLIProxyAPI + Executor hub routing). Verify `ssh -T git@github.com`, `https://ubuntu.<tailnet>:8317/v1/models`
   returns `200` with `~/.config/cliproxy/key`, and `EXECUTOR_AUTH_HEADER="Bearer $(jq -r .token ~/.executor/ubuntu-auth.json)" executor tools integrations` succeeds.
7. **[User]** Run `gh auth login` (SSH, skip key upload), `t3 up --connect --lan`, and
   `t3 pair --tailscale`. In T3 Code, turn **Local environment OFF**, add `desktop` via the pairing URL,
   link two-way with `ubuntu` (and `apple` once online), enable **Automatically balance load**
   (`ubuntu`/`desktop` Prefer; `apple` Less often or manual) + **Pull request sharing**, and pick Paper
   Mono in T3 Code and Warp. After the first Antigravity turn on `desktop`, rerun `environment/install.sh`
   once so Antigravity picks up skills/MCP; run `/hooks` once in Codex.
8. **[Agent]** Verify `t3code.service` active, `Linger=yes`, `RouteAll: True`, T3 link reachable, and
   company VPN reachability through `ubuntu`.

### `apple` (macOS, MacBook Air M3)

1. **[Agent]** Install `ubuntu`'s `~/.ssh/id_ed25519.pub` into `apple:~/.ssh/authorized_keys` for
   passwordless SSH.
2. **[Agent]** Run `apple.sh` over SSH in a PTY (sudo keep-alive, CLI + GUI + OrbStack + 4-app Dock +
   Dark mode + pure black wallpaper + 5-min display sleep + `mise activate zsh` + `tailscale set --accept-routes`),
   then clone and run `mapringg/environment/install.sh`.
3. **[User]** Click through OrbStack's first-run prompt, then run `secret setup` (or provide token via `request_secret`).
4. **[Agent]** Rerun `environment/install.sh` (restores SSH keys and `ubuntu` hub routing). Verify
   `ssh -T git@github.com`, `docker --version`, `RouteAll: True`, and remote Executor integrations
   (`EXECUTOR_AUTH_HEADER="Bearer $(jq -r .token ~/.executor/ubuntu-auth.json)" executor tools integrations`).
5. **[User]** Run `gh auth login` (SSH, skip key upload). In T3 Code, turn **Local environment ON**,
   enable Tailscale HTTPS, link two-way with `ubuntu` + `desktop`, and set Load balancing (`apple` Less
   often or manual; remember only shared projects participate in load balancing). Log out/in once if
   Dark mode or key repeat hasn't refreshed.

### `windows` (Windows 11, Gaming PC)

1. **[User]** In Admin PowerShell, authorize `ubuntu`'s public key (agent prints the exact key from
   `cat ~/.ssh/id_ed25519.pub` on `ubuntu`):
   `Set-Content -Path C:\ProgramData\ssh\administrators_authorized_keys -Value '<pubkey>'; icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"`
2. **[Agent]** Copy `windows.ps1` to `windows` via `scp` and run it with
   `ssh mapring@windows 'powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\mapring\AppData\Local\Temp\windows.ps1'`
   (using `-File` instead of stdin so `$ErrorActionPreference = 'Stop'` and `throw` halt execution),
   then remove the temp script.
3. **[Agent]** Verify `sshd` is `Automatic`, `RouteAll: True`, `RealTimeIsUniversal: 1`, and `WallPaper`
   points to `black.bmp`. If `Rename-Computer` ran, reboot and verify SSH reconnects.
4. **[User]** Apply NVIDIA 3D settings (Max Frame Rate 237, V-Sync On, Low Latency On), HDR +
   True Black 400 calibration, in-game V-Sync off + Reflex On, and connect T3 Code to `ubuntu` (Local
   environment OFF, pick Paper Mono).
