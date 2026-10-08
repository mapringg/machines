#Requires -RunAsAdministrator

if ($env:COMPUTERNAME -ne "windows") { Rename-Computer -NewName windows }

reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" `
    /v RealTimeIsUniversal /t REG_DWORD /d 1 /f

foreach ($id in "AgileBits.1Password", "Tailscale.Tailscale", "Valve.Steam",
                "Discord.Discord") {
    winget list --id $id --exact --accept-source-agreements | Out-Null
    if ($LASTEXITCODE -ne 0) {
        winget install --id $id --exact --silent `
            --accept-source-agreements --accept-package-agreements
    }
}

$personalize = "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
reg add $personalize /v AppsUseLightTheme /t REG_DWORD /d 0 /f
reg add $personalize /v SystemUsesLightTheme /t REG_DWORD /d 0 /f

$gpuPrefs = "HKCU\Software\Microsoft\DirectX\UserGpuPreferences"
$directx = (Get-ItemProperty "Registry::$gpuPrefs" -ErrorAction Ignore)
$directx = $directx.DirectXUserGlobalSettings
$windowed = "SwapEffectUpgradeEnable=1;"
if ($directx -notmatch $windowed) {
    $directx = ($directx -replace "SwapEffectUpgradeEnable=\d;", "") + $windowed
    reg add $gpuPrefs /v DirectXUserGlobalSettings /t REG_SZ /d $directx /f
}

reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f
