# machines

Setup scripts for my three machines. Run one on a fresh install and get back to work.
They hold only what I'd miss within a day; everything else stays default, and drift
is fine.

| Script | Machine |
|---|---|
| `macbook.sh` | MacBook Air M3 — thin client, remote work only |
| `ubuntu.sh` | Desktop, 931GB NVMe — all development |
| `windows.ps1` | Desktop, 1.9TB NVMe — gaming only |

## Architecture

```
 macbook ──── Tailscale ────┬──── ubuntu    (dev; SSH + tmux)
   (thin client)            ├──── windows   (gaming; offline most of the week)
                            └──── umbrel    (always on; sends the wake packet)
```

At the desk I use Ubuntu directly; away, I SSH in from the MacBook. Tailscale SSH means
no host keys, and tmux means a dropped connection loses nothing. Déjà Dup backs up to a
USB drive daily, encrypted, keeping 30 days.

**Power.** Automatic suspend is off, so the desktop sleeps only when told to. umbrel
wakes it because a magic packet can't cross Tailscale, using the python3 it ships with.
Both are Termius snippets on the phone, *Sleep PC* on `ubuntu` and *Wake PC* on
`umbrel` (`047c16483772` is enp12s0's MAC):

    systemctl suspend

    python3 -c 'import socket;s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.setsockopt(socket.SOL_SOCKET,socket.SO_BROADCAST,1);s.sendto(b"\xff"*6+bytes.fromhex("047c16483772")*16,("192.168.1.255",9))'

SSH answers about 15 seconds after the packet. Reboots and power cuts come back on
their own; see [Desktop BIOS](#desktop-bios).

## Manual steps

What the scripts can't do. Do these first unless marked *after*.

### ubuntu.sh

- **BIOS.** See [Desktop BIOS](#desktop-bios).
- **Installer.** Default selection, both third-party boxes ticked (the NVIDIA driver is
  Canonical-signed, so Secure Boot needs no MOK). Erase disk onto the 931GB drive,
  encrypt with passphrase, hostname `ubuntu`, user `mapring`. Install Windows first.
- **Backup drive.** Format it ext4, label it `Backup`, and leave it plugged in.
- ***After.*** Sign in to 1Password, then Tailscale. Restore `~/.ssh`, `~/Work` and the
  `.env` files. Run `claude` and `codex` once each to sign in, and the first Déjà Dup
  backup. Reboot for the docker and input groups.
- ***After:* Handy.** Pick Cohere Transcribe, not Parakeet, which mishears a non-native
  accent. Turn on launch at login, and set Advanced → Paste Method to Clipboard
  (Ctrl+Shift+V): ydotool's typing is slow, and terminals only paste with Shift. Leave
  the overlay off: on GNOME it takes focus and the paste misses. The in-app shortcut
  does nothing on Wayland; Super+O is GNOME's.
- ***After:* Android.** Open Android Studio once and take the Standard setup, which
  installs the SDK into `~/Android/Sdk`, accepts its licenses and creates a Medium Phone
  emulator. On every virtual device, Device Manager → edit → Additional settings → Graphics
  acceleration → Hardware: Automatic fails its GPU check and falls back to software
  rendering, which lags and trips GNOME's "not responding" dialog.

### windows.ps1

- **USB.** Rufus, GPT / UEFI. Under Windows User Experience tick only "remove
  requirement for an online Microsoft account". Don't bypass TPM or Secure Boot.
- **Installer.** Delete all partitions on both disks, then install to the 1907GB drive.
  Otherwise the boot files land on the Ubuntu drive and its install wipes them.
- **OOBE.** Offline account `mapring`, with a password.
- **Drivers.** AMD chipset from amd.com, not MSI's copy: its power provisioning driver
  tells the scheduler which cores hold the 3D V-Cache. NVIDIA from nvidia.com, Custom,
  driver only. Everything else from Windows Update; skip the MSI Driver Utility.
- **NVIDIA Control Panel.** Change resolution: MSI 3840x2160 @ 240Hz, LG ULTRAGEAR
  2560x1440 @ 165Hz, both with NVIDIA color settings, RGB, 10 bpc, Full range (HDMI can
  default to limited, which greys OLED black). G-SYNC on for full screen and windowed,
  "G-SYNC Compatible", and again with the LG selected. Manage 3D settings → Max Frame
  Rate 237, so G-SYNC never hits 240Hz and falls back to V-Sync.
- **Settings → Display.** LG portrait at 100%, left of the MSI as on Ubuntu; MSI 150%
  and main display. HDR on for the MSI only, then run Windows HDR Calibration with the
  monitor's DisplayHDR on True Black 400. Match the MSI's brightness to the LG with
  "SDR content brightness", not the monitor's own.
- ***After.*** Sign in to 1Password, Tailscale, Steam and Discord.

### macbook.sh

- **Bootstrap.** The repo is private and the Mac has no key yet, so:
  1. Setup Assistant, sign in to iCloud.
  2. Safari → 1password.com, install, sign in. Have the Emergency Kit's Secret Key
     before erasing.
  3. Safari → tailscale.com, install, sign in.
  4. `scp ubuntu:Work/mapringg/machines/macbook.sh ~/ && ~/macbook.sh`. Tailscale SSH
     needs no key.

  brew then adopts Tailscale. 1Password stays out of brew: it updates itself, and
  macOS App Management blocks brew's `--adopt` on its bundle even under sudo.
- ***After:* Finder.** ⌘2 for list view, then ⌘J → Date Created and Show Library Folder
  on, relative dates and Calculate all sizes off → Use as Defaults. Old per-folder
  views in `.DS_Store` win over it: `find ~ -name .DS_Store -type f -delete`. The
  `defaults` keys for this are no-ops on macOS 27.
- ***After:* Handy.** Grant Microphone and Accessibility, pick Cohere Transcribe, turn
  on launch at login.
- ***After:* Log out.** Key repeat only applies to a new session.

## Desktop BIOS

MSI PRO B650-P WIFI (MS-7D78). Shared by both OSes, so it lives here rather than in
either script. After a CMOS reset, only these differ from defaults:

- **EXPO / A-XMP → Profile 1.** A reset drops DDR5 to the JEDEC default of 4800 MT/s
  and silently loses the 5200 the kit is rated for.
- **ErP Ready → Disabled.** ErP cuts standby power to the NIC and Wake-on-LAN dies
  with it.
- **Resume By PCI-E Device → Enabled.** This is the Wake-on-LAN toggle on MSI boards.
- **Restore after AC Power Loss → Power On.** After a power cut the PC is fully off,
  not suspended, and a magic packet may not wake it from there.
- **Boot Option #1 → `ubuntu`.** The Windows install puts its own entry first, and
  this board re-asserts its own priority list over whatever `efibootmgr` sets from
  Linux. Set it in *UEFI Hard Disk
  Drive BBS Priorities* too; changing only the top-level list silently reverts.

Already correct at default, but worth confirming: Re-Size BAR enabled, Secure Boot on,
AMD fTPM on, CSM disabled.

The TPM unlocks LUKS, so unattended boots need no passphrase. It's bound to PCR7
(Secure Boot state), so a BIOS update or toggling Secure Boot makes the next boot ask
for it. Only do either at the desk.

**Fan curves.** Both headers set to PWM with Smart Fan Mode on. A CMOS reset wipes
these, and the machine is in my bedroom.

| | CPU_FAN | SYS_FAN |
|---|---|---|
| | 0 °C → 20% | 40 °C → 30% |
| | 45 °C → 35% | 55 °C → 45% |
| | 65 °C → 50% | 70 °C → 70% |
| | 80 °C → 100% | 85 °C → 100% |

SYS_FAN reads the motherboard sensor, which idles at 35–45 °C, so its curve starts
low. The CPU curve stays flat through the 7800X3D's 55–70 °C dev-work band.

## Considered and rejected

- **Buying a mini PC / home server** — nothing under ~40,000 THB beats the 7800X3D I
  already own.
- **WSL2** — fragile auto-start after reboot, and Windows Update reboots at will.
- **Staying on Omarchy** — heavily customised, and I didn't choose most of it. The point
  is to know what changed and why.
- **Nix / nix-darwin** — the largest possible deviation from defaults, and it can't cover
  Windows at all, so I'd need a second mechanism anyway.
- **Sway or a minimal WM** — would mean writing a WM config from scratch. Stock GNOME is
  less deviation, which matters more than saving RAM.
- **restic / borg by hand** — Déjà Dup 50 *is* restic underneath, without the wiring.
- **Headless desktop** — I'm a web developer; I need a browser at the desk. The NVIDIA
  card also idles *higher* headless, so it saves nothing.
- **Ghostty** — the stock terminals work, and its bundled Nerd Font only mattered for
  `eza`, which left with Omarchy.
- **Autologin** — remote work is terminal-only, and SSH works fine at a login screen.
