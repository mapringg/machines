# machines

Setup scripts for my three machines. Run the script on a fresh install and get back to work.

| Script | Machine |
|---|---|
| `macbook.sh` | MacBook Air M3 — thin client, remote work only |
| `ubuntu.sh` | Desktop, 931GB NVMe — all development |
| `windows.ps1` | Desktop, 1.9TB NVMe — gaming only |

Scripts contain only what I'd notice missing within a day. Everything else stays at
its default. The machines will drift from these scripts over time; that's fine. The
goal is a fast path back to working, not a perfect mirror.

## Architecture

The desktop is one PC with two drives — Ubuntu for work, Windows for gaming on weekends.
Ubuntu is the default boot entry.

At the desk I work on Ubuntu directly, with the good keyboard, mouse and monitor.
Away from home I SSH in from the MacBook over Tailscale.

```
 macbook ──── Tailscale ────┬──── ubuntu    (dev; SSH + tmux)
   (thin client)            ├──── windows   (gaming; offline most of the week)
                            └──── umbrel    (always on; sends the wake packet)
```

**Power.** Automatic suspend is off. The desktop sleeps only when I tell it to:

    ssh ubuntu 'systemctl suspend'

and umbrel wakes it with a magic packet. umbrel is an appliance with no script of
its own, and installing `wakeonlan` there wouldn't survive an OS update, so the
packet is sent with the python3 it already has:

    ssh umbrel 'python3 -c "
    import socket
    pkt = b\"\\xff\"*6 + bytes.fromhex(\"047c16483772\")*16
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    s.sendto(pkt, (\"192.168.1.255\", 9))"'

`047c16483772` is enp12s0's MAC. It has to be sent from the LAN — a magic packet
won't cross Tailscale, which is the whole reason this job belongs to umbrel.

Suspend keeps the LUKS volume unlocked in RAM, so waking never stops at a passphrase
prompt — which a cold boot would, unreachably. Measured: SSH answers about 15 seconds
after the packet. Asleep it draws a few watts instead of ~100W; the PC is in my
bedroom and the LED is annoying at night.

**Access.** Tailscale SSH, so there are no host keys to manage. tmux so a dropped
connection never loses work.

**Backups.** Déjà Dup to an external USB drive, daily, 30 days kept, encrypted.
It is *not* in the installer's Default selection, so `ubuntu.sh` installs and
configures it. Everything is gsettings, so nothing about it lives in a GUI only.

## Desktop BIOS

MSI PRO B650-P WIFI (MS-7D78). Shared by both OSes, so it lives here rather than in
either script. After a CMOS reset, only these differ from defaults:

- **EXPO / A-XMP → Profile 1.** A reset drops DDR5 to the JEDEC default of 4800 MT/s
  and silently loses the 5200 the kit is rated for.
- **ErP Ready → Disabled.** ErP cuts standby power to the NIC and Wake-on-LAN dies
  with it.
- **Resume By PCI-E Device → Enabled.** This is the Wake-on-LAN toggle on MSI boards.
- **Boot Option #1 → `ubuntu`.** The Windows install puts its own entry first, and
  this board re-asserts its own priority list over whatever `efibootmgr` sets from
  Linux — so the OS can't fix this, only the firmware can. Set it in *UEFI Hard Disk
  Drive BBS Priorities* too; changing only the top-level list silently reverts.

Already correct at default, but worth confirming: Re-Size BAR enabled, Secure Boot on,
AMD fTPM on, CSM disabled.

**Fan curves.** Both headers set to PWM with Smart Fan Mode on. A CMOS reset wipes
these, and the machine is in my bedroom.

| | CPU_FAN | SYS_FAN |
|---|---|---|
| | 0 °C → 20% | 40 °C → 30% |
| | 45 °C → 35% | 55 °C → 45% |
| | 65 °C → 50% | 70 °C → 70% |
| | 80 °C → 100% | 85 °C → 100% |

SYS_FAN reads the motherboard sensor, which idles around 35–45 °C — so a curve that
starts at 50% duty runs the case fans hard permanently. The CPU curve stays flat
through 65 °C because the 7800X3D sits in the 55–70 °C band during ordinary dev work;
the 80 °C → 100% point is the safety net and shouldn't move.

## Considered and rejected

- **Buying a mini PC / home server** — nothing under ~40,000 THB beats the 7800X3D I
  already own, and DDR4/DDR5 are both in a historic price spike. The desk is where I
  work; the chair, keyboard and monitor are already paid for.
- **WSL2** — fragile auto-start after reboot, and Windows Update reboots at will.
- **Staying on Omarchy** — heavily customised, and I didn't choose most of it. The point
  is to know what changed and why.
- **Nix / nix-darwin** — the largest possible deviation from defaults, and it can't cover
  Windows at all, so I'd need a second mechanism anyway.
- **Sway or a minimal WM** — would mean writing a WM config from scratch. Stock GNOME is
  less deviation, which matters more than saving RAM. Resources were never the constraint.
- **restic / borg by hand** — repository, password, timer and retention is four
  moving parts to own. Déjà Dup 50 *is* restic underneath — the destination is a
  real restic repository — so this gets the same engine with none of the wiring.
- **Syncthing** — replication, not backup. Dropped with Omarchy.
- **Headless desktop** — I'm a web developer; I need a browser at the desk. The NVIDIA
  card also idles *higher* headless, so it saves nothing.
- **The Firefox snap** — kept as long as possible, but a confined snap can't execute
  `/opt/1Password/1Password-BrowserSupport`, so the browser extension can never reach
  the desktop app. `ubuntu.sh` uses Mozilla's deb and pins it.
- **Ghostty** — a terminal to install and configure on two machines, replacing one
  that already ships and works. It was originally chosen for the Nerd Font it
  bundles, which mattered only for `eza`'s icons over ssh — and `eza` left with
  Omarchy. Ptyxis and Terminal.app are fine.
- **Autologin** — not needed. Remote work is terminal-only, and SSH works fine with the
  machine sitting at a login screen. An un-logged-in desktop costs no RAM.
