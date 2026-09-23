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

and umbrel wakes it with a magic packet. Suspend keeps the LUKS volume unlocked in RAM,
so waking never stops at a passphrase prompt — which a cold boot would, unreachably.
Asleep it draws a few watts instead of ~100W; the PC is in my bedroom and the LED is
annoying at night.

**Access.** Tailscale SSH, so there are no host keys to manage. tmux so a dropped
connection never loses work.

**Backups.** Déjà Dup to an external drive, ~30 day retention. It is *not* in the
installer's Default selection, so `ubuntu.sh` installs it.

## Desktop BIOS

MSI PRO B650-P WIFI (MS-7D78). Shared by both OSes, so it lives here rather than in
either script. After a CMOS reset, only these differ from defaults:

- **EXPO / A-XMP → Profile 1.** A reset drops DDR5 to the JEDEC default of 4800 MT/s
  and silently loses the 5200 the kit is rated for.
- **ErP Ready → Disabled.** ErP cuts standby power to the NIC and Wake-on-LAN dies
  with it.
- **Resume By PCI-E Device → Enabled.** This is the Wake-on-LAN toggle on MSI boards.

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
- **restic / borg** — repository, password, timer and retention is four moving parts.
  Déjà Dup is one apt package and a GUI, and it is enough for what's on this machine.
- **Syncthing** — replication, not backup. Dropped with Omarchy.
- **Headless desktop** — I'm a web developer; I need a browser at the desk. The NVIDIA
  card also idles *higher* headless, so it saves nothing.
- **The Firefox snap** — kept as long as possible, but a confined snap can't execute
  `/opt/1Password/1Password-BrowserSupport`, so the browser extension can never reach
  the desktop app. `ubuntu.sh` uses Mozilla's deb and pins it.
- **Autologin** — not needed. Remote work is terminal-only, and SSH works fine with the
  machine sitting at a login screen. An un-logged-in desktop costs no RAM.
