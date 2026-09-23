# windows.ps1 — desktop, 1.9TB NVMe, hostname `windows`
# Windows 11, gaming only. Nothing developed here. Safe to re-run.
#
# MANUAL STEPS — do these first:
#   Installer  delete ALL partitions on BOTH disks, then install to the 1.9TB drive.
#              (Windows will otherwise put its boot files on the Ubuntu drive, and
#               the Ubuntu install then wipes them and Windows won't boot.)
#   After      sign in to Steam etc. and re-download games
#
# --- filled in as the machine is built ---
# Fast Startup off  — it breaks Wake-on-LAN and leaves shared drives dirty
# Hardware clock to UTC — else the clock is 7 hours out after every Linux boot
# Tailscale
