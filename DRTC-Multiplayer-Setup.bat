<# : batch part (this file is both a .bat and a PowerShell script)
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -STA -Command "$f='%~f0'; iex ((Get-Content -LiteralPath $f -Raw) -replace '(?s)^.*?\n#[>]', '')"
exit /b
#>
# =====================================================================================================
#  Death Road to Canada - Online Multiplayer: SETUP / UPDATE
#  Send THIS file to a friend. Double-click it: it downloads the mod, installs it into the game and
#  opens the multiplayer launcher. Downloads come from the PUBLIC repo that contains only the playable
#  files (no source code, no token needed).
# =====================================================================================================
$Owner  = 'GuessGames'
$Repo   = 'drtc-multiplayer-playable'
$Branch = 'main'
# =====================================================================================================

Add-Type -AssemblyName System.Windows.Forms
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'
function Fail($m) { [System.Windows.Forms.MessageBox]::Show($m, 'DRTC Multiplayer setup') | Out-Null; exit 1 }

function Find-Game {
    $roots = @()
    foreach ($k in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam') {
        try { $p = Get-ItemProperty $k -ErrorAction Stop; if ($p.SteamPath) { $roots += $p.SteamPath }; if ($p.InstallPath) { $roots += $p.InstallPath } } catch {}
    }
    $libs = @()
    foreach ($r in $roots | Select-Object -Unique) {
        $libs += $r
        $vdf = Join-Path $r 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) { foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += $m.Groups[1].Value.Replace('\\', '\') } }
    }
    foreach ($l in $libs | Select-Object -Unique) {
        $g = Join-Path $l 'steamapps\common\DeathRoadToCanada'
        if (Test-Path (Join-Path $g 'prog.exe')) { return $g }
    }
    return $null
}

$game = Find-Game
if (-not $game) {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Select your Death Road to Canada folder (the one with prog.exe)'
    if ($dlg.ShowDialog() -ne 'OK' -or -not (Test-Path (Join-Path $dlg.SelectedPath 'prog.exe'))) { Fail 'Death Road to Canada folder not found.' }
    $game = $dlg.SelectedPath
}
if (Get-Process prog -ErrorAction SilentlyContinue) { Fail 'Please close Death Road to Canada first, then run this again.' }

Write-Host "Game folder: $game"
Write-Host 'Downloading the mod from GitHub...'
$base = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch/release"
$hdr = @{ 'User-Agent' = 'drtc-mp-setup'; 'Cache-Control' = 'no-cache' }
$tmp = Join-Path $env:TEMP 'DRTC-Multiplayer.zip'
try {
    Invoke-WebRequest -UseBasicParsing -Headers $hdr -Uri "$base/DRTC-Multiplayer.zip" -OutFile $tmp
    $ver = (Invoke-WebRequest -UseBasicParsing -Headers $hdr -Uri "$base/version.txt").Content
} catch { Fail "Download failed: $($_.Exception.Message)`n`nCheck your internet connection." }

$pkg = Join-Path $game 'DRTC-Multiplayer'
Remove-Item $pkg -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -Path $tmp -DestinationPath $game -Force
Remove-Item $tmp -Force -ErrorAction SilentlyContinue
# remember where updates come from (used by the launcher's "Update" button)
Set-Content (Join-Path $pkg 'github.cfg') "owner=$Owner`r`nrepo=$Repo`r`nbranch=$Branch" -Encoding ascii

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $pkg 'install.ps1')
if ($LASTEXITCODE -ne 0) { Fail 'Installing the mod failed - see the console window.' }
Write-Host "Installed version: $ver"
Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$(Join-Path $pkg 'launcher.ps1')`""
