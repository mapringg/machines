# machines

Setup scripts for my machines. Each takes a clean install to the starting point I want:
only what I'd miss within a day, with everything else left at its default. After that
the machines drift, and that's fine.

| Script | Machine |
|---|---|
| `macbook.sh` | MacBook Air M3 — thin client, remote work only |
| `ubuntu.sh` | Desktop, 931GB NVMe — all development |
| `windows.ps1` | Desktop, 1.9TB NVMe — gaming only |
| `server.sh` | Getorli GT105 mini PC, 8845HS, 32GB — always on, agents |

## Architecture

```
 macbook ──── Tailscale ────┬──── server    (always on; agents, SSH + tmux)
   (thin client)            ├──── ubuntu    (dev; SSH + tmux)
                            └──── windows   (gaming; offline most of the week)
```

`server` runs T3 Code's threads, so they keep going while the desktop sleeps or plays
games.

At the desk I use Ubuntu directly; away, I SSH in from the MacBook. Tailscale SSH means
no host keys, and tmux means a dropped connection loses nothing.

## Reinstall

Steps in order for each machine; running the script is one of them.

### ubuntu.sh

1. **BIOS.** See [Desktop BIOS](#desktop-bios).
2. **Installer.** Install Windows first. Default selection, both third-party boxes
   ticked. Erase disk onto the 931GB drive, encrypt with a passphrase, hostname
   `ubuntu`, user `mapring`.
3. **Backup drive.** Format it ext4, label it `Backup`, and leave it plugged in.
4. **Run `ubuntu.sh`.**
5. **Sign in.** Add the 1Password extension to Firefox, then sign in to Tailscale. Run
   `claude` and `codex` once each.
6. **Restore.** Copy back `~/.ssh`, `~/.kube`, `~/Work` and the `.env` files, then run
   the first Déjà Dup backup. Reboot for the docker group.
7. **Displays.** Settings → Displays: MSI 3840x2160 @ 240Hz, 150%, primary; LG
   2560x1440 @ 165Hz, portrait, 100%, left of the MSI and centred on its height.

### server.sh

1. **BIOS.** Auto Power ON enabled, AMD fTPM on. If offered, set the iGPU's UMA frame
   buffer to its minimum.
2. **Installer.** Ubuntu Server 26.04, wired Ethernet. Entire disk, LVM encrypted with
   LUKS, with a passphrase. Hostname `server`, user `mapring`. Leave OpenSSH server
   unticked.
3. **Burn-in.** Within Shopee's 7-day return window, before tapping "received":
   1. `curl -fsSL https://tailscale.com/install.sh | sh` and `sudo tailscale up --ssh`.
      Then `scp ubuntu:Work/mapringg/machines/burnin.sh ~/` and run `./burnin.sh` in
      tmux. It takes 24 hours and writes `~/burnin-*.log`.
   2. Reboot, pick memtest86+ from the GRUB menu (Esc at boot) and run it overnight. If
      Secure Boot refuses it, turn Secure Boot off for the test and back on before
      `server.sh`.
   3. Reboot 20 times and cold-start a few, watching for one that doesn't come up.
4. **Run `server.sh`.**
5. **Sign in.** Run `claude` and `codex` once each, and `gh auth login`. Clone the repos
   and copy the `.env` files from `ubuntu`.
6. **Pair.** Run `t3 pair --tailscale` and add its URL in T3 Code on `ubuntu`, the
   MacBook and the phone: Settings → Connections → Add environment.

### windows.ps1

1. **USB.** Rufus, GPT / UEFI. Under Windows User Experience tick only "remove
   requirement for an online Microsoft account".
2. **Installer.** Delete all partitions on both disks, then install to the 1907GB drive.
3. **OOBE.** Offline account `mapring`, with a password.
4. **Drivers.** NVIDIA from nvidia.com, Custom, driver only. Everything else from
   Windows Update; skip the MSI Driver Utility.
5. **Run `windows.ps1`** as Administrator.
6. **Sign in.** Add the 1Password extension to Edge, then sign in to Tailscale, Steam
   and Discord.
7. **NVIDIA Control Panel.**
   - Change resolution: MSI 3840x2160 @ 240Hz, LG 2560x1440 @ 165Hz.
   - Set up G-SYNC: on for full screen and windowed, "G-SYNC Compatible", for the MSI
     and again with the LG selected.
   - Manage 3D settings: Max Frame Rate 237, Vertical sync On, Low Latency Mode On.
8. **Settings → Display.** LG portrait at 100%, left of the MSI; MSI 150% and main
   display. HDR on for the MSI only, then run Windows HDR Calibration with the monitor's
   DisplayHDR on True Black 400. Match the MSI's brightness to the LG with "SDR content
   brightness".
9. **Each game.** V-Sync off, NVIDIA Reflex On.

### macbook.sh

1. **Setup Assistant**, signing in to the Apple Account: 1Password's Safari extension
   needs it.
2. **1Password.** Safari → 1password.com, install, sign in. Have the Emergency Kit's
   Secret Key before erasing.
3. **Tailscale.** Safari → tailscale.com, install, sign in.
4. **Run `macbook.sh`.** `scp ubuntu:Work/mapringg/machines/macbook.sh ~/`, then
   `~/macbook.sh`.
5. **Log out**, so key repeat applies.

## Desktop BIOS

MSI PRO B650-P WIFI (MS-7D78), shared by Ubuntu and Windows. After a CMOS reset:

- **EXPO / A-XMP → Profile 1**, for the kit's 5200 MT/s instead of 4800.
- **Boot Option #1 → `ubuntu`**, in *UEFI Hard Disk Drive BBS Priorities* too; changing
  only the top-level list silently reverts.
- **Fan curves.** Both headers PWM, Smart Fan Mode on:

  | | CPU_FAN | SYS_FAN |
  |---|---|---|
  | | 0 °C → 20% | 40 °C → 30% |
  | | 45 °C → 35% | 55 °C → 45% |
  | | 65 °C → 50% | 70 °C → 70% |
  | | 80 °C → 100% | 85 °C → 100% |

Confirm the defaults: Re-Size BAR on, Secure Boot on, AMD fTPM on, CSM off.

## Considered and rejected

- **WSL2** — fragile auto-start after reboot, and Windows Update reboots at will.
- **Staying on Omarchy** — heavily customised, and I didn't choose most of it. The point
  is to know what changed and why.
- **Nix / nix-darwin** — the largest possible deviation from defaults, and it can't
  cover Windows at all, so I'd need a second mechanism anyway.
- **Sway or a minimal WM** — would mean writing a WM config from scratch. Stock GNOME is
  less deviation, which matters more than saving RAM.
- **restic / borg by hand** — Déjà Dup 50 *is* restic underneath, without the wiring.
- **Headless desktop** — I'm a web developer; I need a browser at the desk. The NVIDIA
  card also idles *higher* headless, so it saves nothing.
- **Autologin** — remote work is terminal-only, and SSH works fine at a login screen.
