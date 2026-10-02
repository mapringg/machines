# windows.ps1 — desktop, 1.9TB NVMe, hostname `windows`
# Windows 11 Pro, English (US), region Thailand. Gaming only; nothing is developed here.
# Run as Administrator. Safe to re-run.
#
# MANUAL STEPS — do these first:
#   BIOS       see README — shared with ubuntu.sh
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
#   Display    NVIDIA Control Panel → Change resolution: 3840x2160 @ 240Hz,
#              "Use NVIDIA color settings", RGB, 10 bpc, Full range — over HDMI
#              the default can be limited, which turns OLED black grey.
#              Same for the LG ULTRAGEAR at 2560x1440 @ 165Hz, then Settings →
#              Display: LG portrait, 100%, left of the MSI as on Ubuntu, MSI
#              150% and main display.
#              Set up G-SYNC: on, full screen and windowed, "G-SYNC Compatible",
#              and again with the LG selected under "Enable settings for the
#              selected display model".
#              Manage 3D settings → Max Frame Rate 237, so G-SYNC never hits the
#              240Hz ceiling and falls back to V-Sync lag.
#              Settings → Display → Use HDR on, for the MSI only, then run
#              "Windows HDR Calibration" from the Store with the monitor's
#              DisplayHDR set to True Black 400. With HDR on, the MSI's desktop
#              brightness is the "SDR content brightness" slider, not the
#              monitor's own — match it to the LG with that.

# Fast Startup off. Windows otherwise "shuts down" into a hibernation state that
# leaves the NIC unable to wake — which kills Wake-on-LAN. Also frees hiberfil.sys.
powercfg /h off

# Treat the hardware clock as UTC, like Linux does. Without this the clock is
# 7 hours out every time we switch between the two OSes.
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" `
    /v RealTimeIsUniversal /t REG_DWORD /d 1 /f

# The rest is per-user, so run elevated from mapring's own session, not another
# admin account. Text and mouse take effect at the next sign-in; the rename
# below needs a reboot anyway.

# Dark mode, and a taskbar that hides. Both are about OLED burn-in, same as
# ubuntu.sh: a light theme lights every pixel of every window, and a pinned
# taskbar is the one thing on screen that never moves. Auto-hide has no named
# value — it's byte 8 of a binary blob (3 hides, 2 doesn't), which Explorer
# only rereads when it restarts. It comes back on its own.
$personalize = "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
reg add $personalize /v AppsUseLightTheme /t REG_DWORD /d 0 /f
reg add $personalize /v SystemUsesLightTheme /t REG_DWORD /d 0 /f
$stuckRects = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
$taskbar = (Get-ItemProperty $stuckRects).Settings
if ($taskbar[8] -ne 3) {
    $taskbar[8] = 3
    Set-ItemProperty $stuckRects -Name Settings -Value $taskbar
    Stop-Process -Name explorer
}

# Grayscale text smoothing instead of ClearType. ClearType assumes RGB stripes;
# QD-OLED subpixels sit in a triangle, so it leaves coloured fringes on every
# letter. FontSmoothingType 1 is plain antialiasing, 2 is ClearType.
reg add "HKCU\Control Panel\Desktop" /v FontSmoothing /t REG_SZ /d 2 /f
reg add "HKCU\Control Panel\Desktop" /v FontSmoothingType /t REG_DWORD /d 1 /f

# Enhance pointer precision off. It's on by default — an acceleration curve —
# and ubuntu.sh's flat pointer is meant to match this side of the desk, so
# both have to be flat. Speed stays at the default 10, which is 1:1.
reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f

if ($env:COMPUTERNAME -ne "windows") { Rename-Computer -NewName windows }
