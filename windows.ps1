# windows.ps1 — desktop, 1.9TB NVMe, hostname `windows`
# Windows 11 Pro, English (US), region Thailand. Gaming only; nothing is developed here.
# Run as Administrator. Safe to re-run.
#
# MANUAL STEPS — do these first:
#   BIOS       EXPO profile 1 (5200 MT/s), ErP Ready disabled, Resume By PCI-E Device
#              enabled, Re-Size BAR enabled. Secure Boot + fTPM stay on (board default).
#   USB        Rufus, GPT / UEFI. In "Windows User Experience" check ONLY
#              "remove requirement for an online Microsoft account".
#              Do NOT bypass TPM/Secure Boot — this machine has both.
#   Installer  delete ALL partitions on BOTH disks, then install to the 1907GB drive.
#              Windows otherwise puts its boot files on the Ubuntu drive, and the
#              Ubuntu install then wipes them and Windows won't boot.
#   OOBE       Offline account, username `mapring`, with a password.
#   Drivers    AMD chipset from amd.com — NOT MSI's copy. It installs the power
#              provisioning driver that tells Windows which cores hold the 3D V-Cache;
#              without it the scheduler parks the wrong cores and games lose frames.
#              NVIDIA from nvidia.com, Custom install, driver only (no NVIDIA App).
#              Everything else (LAN, audio, wifi, bluetooth) comes from Windows Update.
#              Skip the MSI Driver Utility entirely.
#   Apps       1Password (needed to sign in to Tailscale), Tailscale, Steam.

# Fast Startup off. Windows otherwise "shuts down" into a hibernation state that
# leaves the NIC unable to wake — which kills Wake-on-LAN. Also frees hiberfil.sys.
powercfg /h off

# Treat the hardware clock as UTC, like Linux does. Without this the clock is
# 7 hours out every time we switch between the two OSes.
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" `
    /v RealTimeIsUniversal /t REG_DWORD /d 1 /f

Rename-Computer -NewName windows
