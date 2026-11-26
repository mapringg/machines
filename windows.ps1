winget install --exact --silent --accept-source-agreements --accept-package-agreements `
    Tailscale.Tailscale Google.Chrome Microsoft.VisualStudioCode `
    WisprFlow.WisprFlow Valve.Steam Discord.Discord AgileBits.1Password `
    T3Tools.T3Code xAI.GrokBot Warp.Warp
$z = "$env:TEMP\paper-mono.zip"
Invoke-WebRequest https://github.com/paper-design/paper-mono/releases/download/v1.000/paper-mono-v1.000.zip -OutFile $z
if ((Get-FileHash $z).Hash -ne '8642652985DC87BF4CFD07C89942899E611C3C774FC25284C0DD4FE86A993A13') { throw 'Paper Mono checksum mismatch' }
Expand-Archive $z "$env:TEMP\paper-mono" -Force
$d = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
New-Item -ItemType Directory -Force $d | Out-Null
$r = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
Get-ChildItem "$env:TEMP\paper-mono\paper-mono-v1.000\fonts\ttf\*.ttf" | ForEach-Object {
    Copy-Item $_ $d -Force
    Set-ItemProperty $r "$($_.BaseName -replace '-', ' ') (TrueType)" "$d\$($_.Name)"
}
Remove-Item -Recurse -Force $z, "$env:TEMP\paper-mono"
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
