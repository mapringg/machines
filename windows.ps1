# Windows 11 Pro desktop, hostname `windows`. Gaming only.
# Run as Administrator after the manual steps in README. Safe to re-run.

# --- machine ------------------------------------------------------------------
if ($env:COMPUTERNAME -ne "windows") { Rename-Computer -NewName windows }

# Fast Startup's hibernation stops the NIC waking on LAN
powercfg /h off

# Hardware clock in UTC, like Ubuntu
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" `
    /v RealTimeIsUniversal /t REG_DWORD /d 1 /f

# --- apps ---------------------------------------------------------------------
foreach ($id in "AgileBits.1Password", "Tailscale.Tailscale", "Valve.Steam",
                "Discord.Discord") {
    winget list --id $id --exact --accept-source-agreements | Out-Null
    if ($LASTEXITCODE -ne 0) {
        winget install --id $id --exact --silent `
            --accept-source-agreements --accept-package-agreements
    }
}

# --- per-user: run from mapring's session; applies at next sign-in ------------
# Dark mode and auto-hidden taskbar, for OLED burn-in. Auto-hide is byte 8 of
# StuckRects3 (3 hides), which Explorer reads only when it restarts.
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

# Grayscale smoothing (type 1), not ClearType: QD-OLED isn't RGB stripes
reg add "HKCU\Control Panel\Desktop" /v FontSmoothing /t REG_SZ /d 2 /f
reg add "HKCU\Control Panel\Desktop" /v FontSmoothingType /t REG_DWORD /d 1 /f

# Optimizations for windowed games on: borderless gets fullscreen's latency.
# Other Graphics settings share this string, so edit it rather than overwrite.
$gpuPrefs = "HKCU\Software\Microsoft\DirectX\UserGpuPreferences"
$directx = (Get-ItemProperty "Registry::$gpuPrefs" -ErrorAction Ignore)
$directx = $directx.DirectXUserGlobalSettings
$windowed = "SwapEffectUpgradeEnable=1;"
if ($directx -notmatch $windowed) {
    $directx = ($directx -replace "SwapEffectUpgradeEnable=\d;", "") + $windowed
    reg add $gpuPrefs /v DirectXUserGlobalSettings /t REG_SZ /d $directx /f
}

# Enhance pointer precision off, to match Ubuntu's flat pointer
reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f
