winget install --exact --silent --accept-source-agreements --accept-package-agreements `
    Tailscale.Tailscale Google.Chrome Microsoft.VisualStudioCode `
    WisprFlow.WisprFlow Valve.Steam Discord.Discord AgileBits.1Password `
    T3Tools.T3Code
if ($env:COMPUTERNAME -ne 'WINDOWS') { Rename-Computer windows }
$t = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
Set-ItemProperty $t AppsUseLightTheme 0
Set-ItemProperty $t SystemUsesLightTheme 0
Set-ItemProperty 'HKCU:\Control Panel\Mouse' MouseSpeed 0
Set-ItemProperty 'HKCU:\Control Panel\Mouse' MouseThreshold1 0
Set-ItemProperty 'HKCU:\Control Panel\Mouse' MouseThreshold2 0
$g = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
if (!(Test-Path $g)) { New-Item $g | Out-Null }
Set-ItemProperty $g DirectXUserGlobalSettings 'SwapEffectUpgradeEnable=1;'
