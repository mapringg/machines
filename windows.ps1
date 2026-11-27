$ErrorActionPreference = 'Stop'

$packages = @(
    'Google.Chrome',
    'Microsoft.VisualStudioCode',
    'WisprFlow.WisprFlow',
    'Valve.Steam',
    'Discord.Discord',
    'AgileBits.1Password',
    'T3Tools.T3Code',
    'xAI.GrokBot',
    'Warp.Warp'
)
foreach ($pkg in $packages) {
    winget install --exact --silent --accept-source-agreements --accept-package-agreements $pkg
    if ($LASTEXITCODE -notin @(0, 3010, -1978335189, -1978335135)) {
        throw "winget failed for $pkg (exit $LASTEXITCODE)"
    }
}

$z = "$env:TEMP\paper-mono.zip"
Invoke-WebRequest -UseBasicParsing https://github.com/paper-design/paper-mono/releases/download/v1.000/paper-mono-v1.000.zip -OutFile $z
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
if (!(Test-Path $g)) { New-Item $g -Force | Out-Null }
$curDx = (Get-ItemProperty $g -Name DirectXUserGlobalSettings -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
if (!$curDx -or $curDx -notmatch 'SwapEffectUpgradeEnable=1') {
    Set-ItemProperty $g DirectXUserGlobalSettings ("$curDx" + 'SwapEffectUpgradeEnable=1;')
}

# Pure black OLED wallpaper (applied via interactive Session 1 task when run over SSH)
$bmp = "$env:LOCALAPPDATA\black.bmp"
Add-Type -AssemblyName System.Drawing
$img = New-Object System.Drawing.Bitmap(16, 16)
$gr = [System.Drawing.Graphics]::FromImage($img)
$gr.Clear([System.Drawing.Color]::Black)
$img.Save($bmp, [System.Drawing.Imaging.ImageFormat]::Bmp)
$gr.Dispose(); $img.Dispose()
$sp = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings'
if (Test-Path $sp) { Set-ItemProperty $sp EnabledState 0 -ErrorAction SilentlyContinue }
Set-ItemProperty 'HKCU:\Control Panel\Colors' Background '0 0 0'
Set-ItemProperty 'HKCU:\Control Panel\Desktop' WallPaper $bmp
$cs = 'using System; using System.Runtime.InteropServices; public class WinWallpaper { [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int SystemParametersInfo(int a, int b, string c, int d); }'
if ($env:SESSIONNAME -and $env:SESSIONNAME -ne 'Services') {
    Add-Type -TypeDefinition $cs
    if ([WinWallpaper]::SystemParametersInfo(20, 0, $bmp, 3) -eq 0) { throw 'SystemParametersInfo failed' }
} else {
    $code = "Add-Type -TypeDefinition '$cs'; if ([WinWallpaper]::SystemParametersInfo(20, 0, '$bmp', 3) -eq 0) { exit 1 }"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -EncodedCommand $enc"
    Register-ScheduledTask -TaskName 'SetBlackWallpaperOnce' -Action $action -Principal $principal -Force | Out-Null
    try {
        Start-ScheduledTask -TaskName 'SetBlackWallpaperOnce'
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Milliseconds 500
            if ((Get-ScheduledTask -TaskName 'SetBlackWallpaperOnce').State -ne 'Running') { break }
        }
        $tr = (Get-ScheduledTaskInfo -TaskName 'SetBlackWallpaperOnce').LastTaskResult
        if ($tr -ne 0) { Write-Warning "Interactive wallpaper task returned $tr (will apply on next interactive logon)" }
    } finally {
        Unregister-ScheduledTask -TaskName 'SetBlackWallpaperOnce' -Confirm:$false -ErrorAction SilentlyContinue
    }
}

# Dual-boot UTC clock, WoL-safe Fast Startup off, OLED 5m display off, fast key repeat, clean taskbar, Wi-Fi off, Tailscale routes
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' RealTimeIsUniversal 1 -Type DWord
powercfg /h off
powercfg /change monitor-timeout-ac 5
powercfg /change standby-timeout-ac 0
Set-ItemProperty 'HKCU:\Control Panel\Keyboard' KeyboardDelay '0'
Set-ItemProperty 'HKCU:\Control Panel\Keyboard' KeyboardSpeed '31'
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' ShowTaskViewButton 0
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' SearchboxTaskbarMode 0
Get-NetAdapter | Where-Object { $_.Name -like '*Wi-Fi*' } | Disable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
if (Get-Command tailscale -ErrorAction SilentlyContinue) { tailscale set --accept-routes }
Set-Service -Name sshd -StartupType Automatic -ErrorAction SilentlyContinue

Write-Output "=== VERIFY windows ==="
Write-Output ("WallPaper: " + (Get-ItemProperty 'HKCU:\Control Panel\Desktop').WallPaper)
Write-Output ("RealTimeIsUniversal: " + (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation').RealTimeIsUniversal)
Write-Output ("KeyboardDelay: " + (Get-ItemProperty 'HKCU:\Control Panel\Keyboard').KeyboardDelay)
Write-Output ("sshd StartType: " + (Get-Service sshd -ErrorAction SilentlyContinue).StartType)
