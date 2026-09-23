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

**Backups.** Déjà Dup (ships with Ubuntu) to an external drive, ~30 day retention.

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
  Déjà Dup is already installed.
- **Syncthing** — replication, not backup. Dropped with Omarchy.
- **Headless desktop** — I'm a web developer; I need a browser at the desk. The NVIDIA
  card also idles *higher* headless, so it saves nothing.
- **Autologin** — not needed. Remote work is terminal-only, and SSH works fine with the
  machine sitting at a login screen. An un-logged-in desktop costs no RAM.
