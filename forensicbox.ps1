# ============================================================
# ForensicBox - Lightweight Forensic and RE Setup Script
# Usage : PowerShell Admin > .\forensicbox.ps1
# ============================================================

param(
    [string]$ToolsDir = "C:\Tools",
    [switch]$SkipChoco,
    [switch]$SkipEZTools,
    [switch]$SkipGhidra
)

$ErrorActionPreference = "Continue"

function Log-Info    { param($msg) Write-Host "[+] $msg" -ForegroundColor Green }
function Log-Warn    { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Log-Error   { param($msg) Write-Host "[-] $msg" -ForegroundColor Red }
function Log-Section { param($msg) Write-Host "`n========== $msg ==========" -ForegroundColor Cyan }

function New-Shortcut {
    param(
        [string]$Name,
        [string]$TargetPath,
        [string]$ShortcutDir
    )
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut("$ShortcutDir\$Name.lnk")
    $lnk.TargetPath = $TargetPath
    $lnk.Save()
}

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Log-Error "Lance ce script en tant qu administrateur."
    exit 1
}

Log-Section "PREPARATION"
$dirs = @(
    "$ToolsDir",
    "$ToolsDir\RE",
    "$ToolsDir\Forensic",
    "$ToolsDir\Forensic\EZTools",
    "$ToolsDir\Forensic\Disk",
    "$ToolsDir\Forensic\Network",
    "$ToolsDir\Forensic\Acquisition",
    "$ToolsDir\Utils",
    "$ToolsDir\Sysinternals",
    "$ToolsDir\Mobile",
    "$ToolsDir\Mobile\RE",
    "$ToolsDir\Mobile\Forensic",
    "C:\Cases"
)
foreach ($d in $dirs) {
    if (!(Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Log-Info "Cree : $d"
    }
}

# ============================================================
# 1. CHOCOLATEY
# ============================================================
Log-Section "CHOCOLATEY"

if (-not $SkipChoco) {
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Log-Info "Installation de Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path += ";C:\ProgramData\chocolatey\bin"
    } else {
        Log-Info "Chocolatey deja installe"
    }
    choco feature enable -n allowGlobalConfirmation | Out-Null
} else {
    Log-Warn "Chocolatey skippe"
}

# ============================================================
# 2. UTILITAIRES DE BASE
# ============================================================
Log-Section "UTILITAIRES DE BASE"

$chocoPackages = @(
    "python3",
    "git",
    "7zip",
    "notepadplusplus",
    "vscode",
    "everything",
    "wireshark",
    "hxd",
    "openjdk17"
)

foreach ($pkg in $chocoPackages) {
    Log-Info "Installation : $pkg"
    choco install $pkg --limit-output 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Log-Info "$pkg OK"
    } else {
        Log-Warn "$pkg - verifier manuellement"
    }
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# ============================================================
# 3. SYSINTERNALS
# ============================================================
Log-Section "SYSINTERNALS"

try {
    Log-Info "Telechargement Sysinternals Suite..."
    $sysinternalsZip = "$env:TEMP\sysinternals.zip"
    Invoke-WebRequest -Uri "https://download.sysinternals.com/files/SysinternalsSuite.zip" -OutFile $sysinternalsZip -UseBasicParsing
    Expand-Archive -Path $sysinternalsZip -DestinationPath "$ToolsDir\Sysinternals" -Force
    Remove-Item $sysinternalsZip -Force
    Log-Info "Sysinternals OK"
} catch {
    Log-Error "Sysinternals : $($_.Exception.Message)"
}

# ============================================================
# 4. REVERSE ENGINEERING
# ============================================================
Log-Section "REVERSE ENGINEERING"

# --- Ghidra ---
if (-not $SkipGhidra) {
    Log-Info "Telechargement de Ghidra..."
    try {
        $ghidraRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest" -UseBasicParsing
        $ghidraAsset = $ghidraRelease.assets | Where-Object { $_.name -like "ghidra_*_PUBLIC_*.zip" } | Select-Object -First 1
        $ghidraZip = "$env:TEMP\ghidra.zip"
        Invoke-WebRequest -Uri $ghidraAsset.browser_download_url -OutFile $ghidraZip -UseBasicParsing
        Expand-Archive -Path $ghidraZip -DestinationPath "$ToolsDir\RE" -Force
        Remove-Item $ghidraZip -Force
        Log-Info "Ghidra OK"
    } catch {
        Log-Error "Ghidra : $($_.Exception.Message)"
    }
}

# --- x64dbg ---
Log-Info "Telechargement de x64dbg..."
try {
    $x64dbgRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/x64dbg/x64dbg/releases/latest" -UseBasicParsing
    $x64dbgAsset = $x64dbgRelease.assets | Where-Object { $_.name -like "snapshot_*.zip" } | Select-Object -First 1
    $x64dbgZip = "$env:TEMP\x64dbg.zip"
    Invoke-WebRequest -Uri $x64dbgAsset.browser_download_url -OutFile $x64dbgZip -UseBasicParsing
    Expand-Archive -Path $x64dbgZip -DestinationPath "$ToolsDir\RE\x64dbg" -Force
    Remove-Item $x64dbgZip -Force
    Log-Info "x64dbg OK"
} catch {
    Log-Error "x64dbg : $($_.Exception.Message)"
}

# --- Detect It Easy ---
Log-Info "Telechargement de Detect It Easy..."
try {
    $dieRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/horsicq/DIE-engine/releases/latest" -UseBasicParsing
    $dieAsset = $dieRelease.assets | Where-Object { $_.name -like "die_win64_portable_*.zip" } | Select-Object -First 1
    if ($dieAsset) {
        $dieZip = "$env:TEMP\die.zip"
        Invoke-WebRequest -Uri $dieAsset.browser_download_url -OutFile $dieZip -UseBasicParsing
        Expand-Archive -Path $dieZip -DestinationPath "$ToolsDir\RE\DIE" -Force
        Remove-Item $dieZip -Force
        Log-Info "DIE OK"
    } else {
        Log-Warn "DIE - asset non trouve"
    }
} catch {
    Log-Error "DIE : $($_.Exception.Message)"
}

# --- PEStudio ---
Log-Info "Telechargement de PEStudio..."
try {
    $pestudioZip = "$env:TEMP\pestudio.zip"
    Invoke-WebRequest -Uri "https://www.winitor.com/tools/pestudio/current/pestudio.zip" -OutFile $pestudioZip -UseBasicParsing
    Expand-Archive -Path $pestudioZip -DestinationPath "$ToolsDir\RE\PEStudio" -Force
    Remove-Item $pestudioZip -Force
    Log-Info "PEStudio OK"
} catch {
    Log-Error "PEStudio : $($_.Exception.Message)"
}

# --- FLOSS ---
Log-Info "Telechargement de FLOSS..."
try {
    $flossRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/mandiant/flare-floss/releases/latest" -UseBasicParsing
    $flossAsset = $flossRelease.assets | Where-Object { $_.name -like "floss-*-windows.zip" } | Select-Object -First 1
    if ($flossAsset) {
        $flossZip = "$env:TEMP\floss.zip"
        Invoke-WebRequest -Uri $flossAsset.browser_download_url -OutFile $flossZip -UseBasicParsing
        Expand-Archive -Path $flossZip -DestinationPath "$ToolsDir\RE\FLOSS" -Force
        Remove-Item $flossZip -Force
        Log-Info "FLOSS OK"
    } else {
        Log-Warn "FLOSS - asset non trouve"
    }
} catch {
    Log-Error "FLOSS : $($_.Exception.Message)"
}

# --- YARA ---
Log-Info "Telechargement de YARA..."
try {
    $yaraRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/VirusTotal/yara/releases/latest" -UseBasicParsing
    $yaraAsset = $yaraRelease.assets | Where-Object { $_.name -like "yara-*-win64.zip" } | Select-Object -First 1
    if ($yaraAsset) {
        $yaraZip = "$env:TEMP\yara.zip"
        Invoke-WebRequest -Uri $yaraAsset.browser_download_url -OutFile $yaraZip -UseBasicParsing
        Expand-Archive -Path $yaraZip -DestinationPath "$ToolsDir\RE\YARA" -Force
        Remove-Item $yaraZip -Force
        Log-Info "YARA OK"
    } else {
        Log-Warn "YARA - asset non trouve"
    }
} catch {
    Log-Error "YARA : $($_.Exception.Message)"
}

# ============================================================
# 5. FORENSIC TOOLS
# ============================================================
Log-Section "FORENSIC TOOLS"

# --- Eric Zimmerman Tools ---
if (-not $SkipEZTools) {
    Log-Info "Telechargement des Eric Zimmerman Tools..."
    try {
        $ezScript = "$env:TEMP\Get-ZimmermanTools.ps1"
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/EricZimmerman/Get-ZimmermanTools/master/Get-ZimmermanTools.ps1" -OutFile $ezScript -UseBasicParsing
        & $ezScript -Dest "$ToolsDir\Forensic\EZTools"
        Remove-Item $ezScript -Force
        Log-Info "EZ Tools OK"
    } catch {
        Log-Error "EZ Tools : $($_.Exception.Message)"
    }
}

# --- Hayabusa ---
Log-Info "Telechargement de Hayabusa..."
try {
    $hayabusaRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/Yamato-Security/hayabusa/releases/latest" -UseBasicParsing
    $hayabusaAsset = $hayabusaRelease.assets | Where-Object { $_.name -like "hayabusa-*-win-x64.zip" } | Select-Object -First 1
    if ($hayabusaAsset) {
        $hayabusaZip = "$env:TEMP\hayabusa.zip"
        Invoke-WebRequest -Uri $hayabusaAsset.browser_download_url -OutFile $hayabusaZip -UseBasicParsing
        Expand-Archive -Path $hayabusaZip -DestinationPath "$ToolsDir\Forensic\Hayabusa" -Force
        Remove-Item $hayabusaZip -Force
        Log-Info "Hayabusa OK"
    } else {
        Log-Warn "Hayabusa - asset non trouve"
    }
} catch {
    Log-Error "Hayabusa : $($_.Exception.Message)"
}

# --- Chainsaw ---
Log-Info "Telechargement de Chainsaw..."
try {
    $chainsawRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/WithSecureLabs/chainsaw/releases/latest" -UseBasicParsing
    $chainsawAsset = $chainsawRelease.assets | Where-Object { $_.name -like "chainsaw_x86_64-pc-windows-msvc.zip" } | Select-Object -First 1
    if ($chainsawAsset) {
        $chainsawZip = "$env:TEMP\chainsaw.zip"
        Invoke-WebRequest -Uri $chainsawAsset.browser_download_url -OutFile $chainsawZip -UseBasicParsing
        Expand-Archive -Path $chainsawZip -DestinationPath "$ToolsDir\Forensic\Chainsaw" -Force
        Remove-Item $chainsawZip -Force
        Log-Info "Chainsaw OK"
    } else {
        Log-Warn "Chainsaw - asset non trouve"
    }
} catch {
    Log-Error "Chainsaw : $($_.Exception.Message)"
}

# --- Volatility 3 ---
Log-Info "Installation de Volatility 3..."
try {
    pip install volatility3 2>&1 | Out-Null
    Log-Info "Volatility 3 OK"
} catch {
    Log-Error "Volatility 3 : $($_.Exception.Message)"
}

# --- CyberChef ---
Log-Info "Telechargement de CyberChef..."
try {
    $cyberchefRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/gchq/CyberChef/releases/latest" -UseBasicParsing
    $cyberchefAsset = $cyberchefRelease.assets | Where-Object { $_.name -like "CyberChef_*.zip" } | Select-Object -First 1
    if ($cyberchefAsset) {
        $cyberchefZip = "$env:TEMP\cyberchef.zip"
        Invoke-WebRequest -Uri $cyberchefAsset.browser_download_url -OutFile $cyberchefZip -UseBasicParsing
        Expand-Archive -Path $cyberchefZip -DestinationPath "$ToolsDir\Utils\CyberChef" -Force
        Remove-Item $cyberchefZip -Force
        Log-Info "CyberChef OK"
    } else {
        Log-Warn "CyberChef - asset non trouve"
    }
} catch {
    Log-Error "CyberChef : $($_.Exception.Message)"
}

# ============================================================
# 5b. DISK FORENSIC
# ============================================================
Log-Section "DISK FORENSIC"

# --- Autopsy ---
Log-Info "Telechargement de Autopsy..."
try {
    $autopsyRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/sleuthkit/autopsy/releases/latest" -UseBasicParsing
    $autopsyAsset = $autopsyRelease.assets | Where-Object { $_.name -like "autopsy-*.msi" } | Select-Object -First 1
    if ($autopsyAsset) {
        $autopsyMsi = "$ToolsDir\Forensic\Disk\autopsy-installer.msi"
        Invoke-WebRequest -Uri $autopsyAsset.browser_download_url -OutFile $autopsyMsi -UseBasicParsing
        Log-Info "Autopsy MSI telecharge dans Forensic\Disk\ - lance le MSI manuellement"
        Log-Warn "Autopsy necessite une installation manuelle via le MSI"
    } else {
        Log-Warn "Autopsy - asset non trouve - telecharge depuis https://www.autopsy.com/download/"
    }
} catch {
    Log-Error "Autopsy : $($_.Exception.Message)"
    Log-Warn "Telecharge manuellement depuis https://www.autopsy.com/download/"
}

# --- FTK Imager (acquisition) ---
Log-Info "FTK Imager - telechargement manuel requis"
Log-Warn "FTK Imager necessite un compte Exterro :"
Log-Warn "  1. Telecharge depuis https://www.exterro.com/digital-forensics-software/ftk-imager"
Log-Warn "  2. Installe dans $ToolsDir\Forensic\Acquisition\FTKImager\"
New-Item -ItemType Directory -Path "$ToolsDir\Forensic\Acquisition\FTKImager" -Force | Out-Null
$ftkReadme = "Telecharger FTK Imager depuis https://www.exterro.com/digital-forensics-software/ftk-imager et installer ici."
Set-Content -Path "$ToolsDir\Forensic\Acquisition\FTKImager\_INSTALLER_ICI.txt" -Value $ftkReadme -Encoding UTF8

# --- Arsenal Image Mounter (mount forensic images) ---
Log-Info "Arsenal Image Mounter - telechargement manuel requis"
Log-Warn "Arsenal Image Mounter :"
Log-Warn "  1. Telecharge depuis https://arsenalrecon.com/downloads"
Log-Warn "  2. Installe dans $ToolsDir\Forensic\Disk\ArsenalImageMounter\"
New-Item -ItemType Directory -Path "$ToolsDir\Forensic\Disk\ArsenalImageMounter" -Force | Out-Null
$aimReadme = "Telecharger Arsenal Image Mounter depuis https://arsenalrecon.com/downloads et installer ici."
Set-Content -Path "$ToolsDir\Forensic\Disk\ArsenalImageMounter\_INSTALLER_ICI.txt" -Value $aimReadme -Encoding UTF8

# --- dd / dcfldd via Chocolatey ---
Log-Info "Installation de dd pour Windows..."
try {
    choco install yourkit-dd --limit-output 2>&1 | Out-Null
    Log-Info "dd OK"
} catch {
    Log-Warn "dd - installer manuellement si besoin"
}

# --- The Sleuth Kit (disk analysis CLI) ---
Log-Info "Installation de The Sleuth Kit..."
try {
    choco install sleuthkit --limit-output 2>&1 | Out-Null
    Log-Info "The Sleuth Kit OK"
} catch {
    Log-Warn "The Sleuth Kit - installer manuellement si besoin"
}

# ============================================================
# 5c. NETWORK FORENSIC
# ============================================================
Log-Section "NETWORK FORENSIC"

# --- NetworkMiner ---
Log-Info "Telechargement de NetworkMiner Free..."
try {
    $nmZip = "$env:TEMP\networkminer.zip"
    Invoke-WebRequest -Uri "https://www.netresec.com/?download=NetworkMiner" -OutFile $nmZip -UseBasicParsing
    Expand-Archive -Path $nmZip -DestinationPath "$ToolsDir\Forensic\Network" -Force
    Remove-Item $nmZip -Force
    Log-Info "NetworkMiner OK"
} catch {
    Log-Warn "NetworkMiner - telechargement auto echoue"
    Log-Warn "Telecharge manuellement depuis https://www.netresec.com/?page=NetworkMiner"
    New-Item -ItemType Directory -Path "$ToolsDir\Forensic\Network\NetworkMiner" -Force | Out-Null
    $nmReadme = "Telecharger NetworkMiner depuis https://www.netresec.com/?page=NetworkMiner et extraire ici."
    Set-Content -Path "$ToolsDir\Forensic\Network\NetworkMiner\_INSTALLER_ICI.txt" -Value $nmReadme -Encoding UTF8
}

# --- tshark (CLI Wireshark - deja installe via choco wireshark) ---
Log-Info "tshark deja inclus avec Wireshark"

# --- npcap (requis pour capture live) ---
Log-Info "Installation de Npcap..."
try {
    choco install npcap --limit-output 2>&1 | Out-Null
    Log-Info "Npcap OK"
} catch {
    Log-Warn "Npcap - installer manuellement depuis https://npcap.com/"
}

# ============================================================
# 6. MOBILE RE
# ============================================================
Log-Section "MOBILE REVERSE ENGINEERING"

Log-Info "Telechargement de JADX..."
try {
    $jadxRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/skylot/jadx/releases/latest" -UseBasicParsing
    $jadxAsset = $jadxRelease.assets | Where-Object { $_.name -like "jadx-*.zip" -and $_.name -notlike "*no-jre*" } | Select-Object -First 1
    if ($jadxAsset) {
        $jadxZip = "$env:TEMP\jadx.zip"
        Invoke-WebRequest -Uri $jadxAsset.browser_download_url -OutFile $jadxZip -UseBasicParsing
        Expand-Archive -Path $jadxZip -DestinationPath "$ToolsDir\Mobile\RE\JADX" -Force
        Remove-Item $jadxZip -Force
        Log-Info "JADX OK"
    } else {
        Log-Warn "JADX - asset non trouve"
    }
} catch {
    Log-Error "JADX : $($_.Exception.Message)"
}

Log-Info "Telechargement de APKTool..."
try {
    $apktoolRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/iBotPeaches/Apktool/releases/latest" -UseBasicParsing
    $apktoolAsset = $apktoolRelease.assets | Where-Object { $_.name -like "apktool_*.jar" } | Select-Object -First 1
    if ($apktoolAsset) {
        New-Item -ItemType Directory -Path "$ToolsDir\Mobile\RE\APKTool" -Force | Out-Null
        Invoke-WebRequest -Uri $apktoolAsset.browser_download_url -OutFile "$ToolsDir\Mobile\RE\APKTool\apktool.jar" -UseBasicParsing
        $batContent = '@echo off' + "`r`n" + 'java -jar "%~dp0apktool.jar" %*'
        Set-Content -Path "$ToolsDir\Mobile\RE\APKTool\apktool.bat" -Value $batContent -Encoding ASCII
        Log-Info "APKTool OK"
    } else {
        Log-Warn "APKTool - asset non trouve"
    }
} catch {
    Log-Error "APKTool : $($_.Exception.Message)"
}

Log-Info "Telechargement de dex2jar..."
try {
    $dex2jarRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/pxb1988/dex2jar/releases/latest" -UseBasicParsing
    $dex2jarAsset = $dex2jarRelease.assets | Where-Object { $_.name -like "dex-tools-*.zip" } | Select-Object -First 1
    if ($dex2jarAsset) {
        $dex2jarZip = "$env:TEMP\dex2jar.zip"
        Invoke-WebRequest -Uri $dex2jarAsset.browser_download_url -OutFile $dex2jarZip -UseBasicParsing
        Expand-Archive -Path $dex2jarZip -DestinationPath "$ToolsDir\Mobile\RE\dex2jar" -Force
        Remove-Item $dex2jarZip -Force
        Log-Info "dex2jar OK"
    } else {
        Log-Warn "dex2jar - asset non trouve"
    }
} catch {
    Log-Error "dex2jar : $($_.Exception.Message)"
}

Log-Info "Telechargement de ByteCode Viewer..."
try {
    $bcvRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/Konloch/bytecode-viewer/releases/latest" -UseBasicParsing
    $bcvAsset = $bcvRelease.assets | Where-Object { $_.name -like "Bytecode-Viewer-*.jar" } | Select-Object -First 1
    if ($bcvAsset) {
        New-Item -ItemType Directory -Path "$ToolsDir\Mobile\RE\ByteCodeViewer" -Force | Out-Null
        Invoke-WebRequest -Uri $bcvAsset.browser_download_url -OutFile "$ToolsDir\Mobile\RE\ByteCodeViewer\ByteCodeViewer.jar" -UseBasicParsing
        Log-Info "ByteCode Viewer OK"
    } else {
        Log-Warn "ByteCode Viewer - asset non trouve"
    }
} catch {
    Log-Error "ByteCode Viewer : $($_.Exception.Message)"
}

Log-Info "Telechargement de Android Platform Tools..."
try {
    $adbZip = "$env:TEMP\platform-tools.zip"
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $adbZip -UseBasicParsing
    Expand-Archive -Path $adbZip -DestinationPath "$ToolsDir\Mobile\RE" -Force
    Remove-Item $adbZip -Force
    Log-Info ("ADB OK - " + "$ToolsDir\Mobile\RE\platform-tools")
} catch {
    Log-Error "ADB : $($_.Exception.Message)"
}

Log-Info "Installation de Frida..."
try {
    pip install frida-tools 2>&1 | Out-Null
    Log-Info "Frida OK"
} catch {
    Log-Error "Frida : $($_.Exception.Message)"
}

Log-Info "Installation de Objection..."
try {
    pip install objection 2>&1 | Out-Null
    Log-Info "Objection OK"
} catch {
    Log-Error "Objection : $($_.Exception.Message)"
}

# ============================================================
# 7. MOBILE FORENSIC
# ============================================================
Log-Section "MOBILE FORENSIC"

# --- ALEAPP ---
Log-Info "Telechargement de ALEAPP..."
try {
    $aleappZip = "$env:TEMP\aleapp.zip"
    New-Item -ItemType Directory -Path "$ToolsDir\Mobile\Forensic\ALEAPP" -Force | Out-Null
    Invoke-WebRequest -Uri "https://github.com/abrignoni/ALEAPP/archive/refs/heads/main.zip" -OutFile $aleappZip -UseBasicParsing
    Expand-Archive -Path $aleappZip -DestinationPath "$ToolsDir\Mobile\Forensic\ALEAPP" -Force
    Rename-Item "$ToolsDir\Mobile\Forensic\ALEAPP\ALEAPP-main" "$ToolsDir\Mobile\Forensic\ALEAPP\ALEAPP-CLI" -ErrorAction SilentlyContinue
    $reqFile = "$ToolsDir\Mobile\Forensic\ALEAPP\ALEAPP-CLI\requirements.txt"
    if (Test-Path $reqFile) { pip install -r $reqFile 2>&1 | Out-Null }
    Remove-Item $aleappZip -Force
    Log-Info "ALEAPP CLI OK"
} catch {
    Log-Error "ALEAPP : $($_.Exception.Message)"
}
Log-Info "Telechargement de ALEAPP GUI..."
try {
    $aleappRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/abrignoni/ALEAPP/releases/latest" -UseBasicParsing
    $aleappAsset = $aleappRelease.assets | Where-Object { $_.name -like "aleapp-v*-Windows.zip" } | Select-Object -First 1
    if ($aleappAsset) {
        $aleappGui = "$env:TEMP\aleapp-gui.zip"
        Invoke-WebRequest -Uri $aleappAsset.browser_download_url -OutFile $aleappGui -UseBasicParsing
        Expand-Archive -Path $aleappGui -DestinationPath "$ToolsDir\Mobile\Forensic\ALEAPP\" -Force
        Log-Info "ALEAPP GUI OK"
    } else {
        Log-Warn "ALEAPP GUI - asset non trouve"
    }
} catch {
    Log-Error "ALEAPP GUI : $($_.Exception.Message)"
}



# --- iLEAPP ---
Log-Info "Telechargement de iLEAPP..."
try {
    $ileappZip = "$env:TEMP\ileapp.zip"
    New-Item -ItemType Directory -Path "$ToolsDir\Mobile\Forensic\ILEAPP" -Force | Out-Null
    Invoke-WebRequest -Uri "https://github.com/abrignoni/iLEAPP/archive/refs/heads/main.zip" -OutFile $ileappZip -UseBasicParsing
    Expand-Archive -Path $ileappZip -DestinationPath "$ToolsDir\Mobile\Forensic\ILEAPP\" -Force
    Rename-Item "$ToolsDir\Mobile\Forensic\ILEAPP\iLEAPP-main" "$ToolsDir\Mobile\Forensic\ILEAPP\iLEAPP-CLI" -ErrorAction SilentlyContinue
    $reqFile = "$ToolsDir\Mobile\Forensic\ILEAPP\iLEAPP-CLI\requirements.txt"
    if (Test-Path $reqFile) { pip install -r $reqFile 2>&1 | Out-Null }
    Remove-Item $ileappZip -Force
    Log-Info "iLEAPP CLI OK"
} catch {
    Log-Error "iLEAPP : $($_.Exception.Message)"
}
Log-Info "Telechargement de ILEAPP GUI..."
try {
    $ileappRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/abrignoni/ILEAPP/releases/latest" -UseBasicParsing
    $ileappAsset = $ileappRelease.assets | Where-Object { $_.name -like "ileapp-v*-Windows.zip" } | Select-Object -First 1
    if ($ileappAsset) {
        $ileappGui = "$env:TEMP\ileapp-gui.zip"
        Invoke-WebRequest -Uri $ileappAsset.browser_download_url -OutFile $ileappGui -UseBasicParsing
        Expand-Archive -Path $ileappGui -DestinationPath "$ToolsDir\Mobile\Forensic\ILEAPP\" -Force
        Log-Info "ILEAPP GUI OK"
    } else {
        Log-Warn "ILEAPP GUI - asset non trouve"
    }
} catch {
    Log-Error "ILEAPP GUI : $($_.Exception.Message)"
}


# --- VLEAPP ---
Log-Info "Telechargement de VLEAPP..."
try {
    $vleappZip = "$env:TEMP\vleapp.zip"
    Invoke-WebRequest -Uri "https://github.com/abrignoni/VLEAPP/archive/refs/heads/main.zip" -OutFile $vleappZip -UseBasicParsing
    Expand-Archive -Path $vleappZip -DestinationPath "$ToolsDir\Mobile\Forensic" -Force
    Rename-Item "$ToolsDir\Mobile\Forensic\VLEAPP-main" "$ToolsDir\Mobile\Forensic\VLEAPP" -ErrorAction SilentlyContinue
    $reqFile = "$ToolsDir\Mobile\Forensic\VLEAPP\requirements.txt"
    if (Test-Path $reqFile) { pip install -r $reqFile 2>&1 | Out-Null }
    Remove-Item $vleappZip -Force
    Log-Info "VLEAPP OK"
} catch {
    Log-Error "VLEAPP : $($_.Exception.Message)"
}

# --- RLEAPP ---
Log-Info "Telechargement de RLEAPP..."
try {
    $rleappZip = "$env:TEMP\rleapp.zip"
    Invoke-WebRequest -Uri "https://github.com/abrignoni/RLEAPP/archive/refs/heads/main.zip" -OutFile $rleappZip -UseBasicParsing
    Expand-Archive -Path $rleappZip -DestinationPath "$ToolsDir\Mobile\Forensic" -Force
    Rename-Item "$ToolsDir\Mobile\Forensic\RLEAPP-main" "$ToolsDir\Mobile\Forensic\RLEAPP" -ErrorAction SilentlyContinue
    $reqFile = "$ToolsDir\Mobile\Forensic\RLEAPP\requirements.txt"
    if (Test-Path $reqFile) { pip install -r $reqFile 2>&1 | Out-Null }
    Remove-Item $rleappZip -Force
    Log-Info "RLEAPP OK"
} catch {
    Log-Error "RLEAPP : $($_.Exception.Message)"
}

# --- MVT ---
Log-Info "Installation de MVT..."
try {
    pip install mvt 2>&1 | Out-Null
    Log-Info "MVT OK"
} catch {
    Log-Error "MVT : $($_.Exception.Message)"
}

# --- libimobiledevice ---
Log-Info "Installation de libimobiledevice..."
try {
    choco install libimobiledevice --limit-output 2>&1 | Out-Null
    Log-Info "libimobiledevice OK"
} catch {
    Log-Warn "libimobiledevice - installer manuellement si besoin"
}

# ============================================================
# 8. PYTHON FORENSIC LIBS
# ============================================================
Log-Section "PYTHON FORENSIC LIBRARIES"

$pipPackages = @(
    "pefile",
    "yara-python",
    "oletools",
    "python-evtx",
    "malduck",
    "pycryptodome",
    "requests",
    "pandas",
    "matplotlib",
    "androguard",
    "apkid",
    "scapy",
    "dpkt"
)

foreach ($pip in $pipPackages) {
    Log-Info "pip install : $pip"
    pip install $pip 2>&1 | Out-Null
}
Log-Info "Python libs OK"

# ============================================================
# 9. PATH ET RACCOURCIS
# ============================================================
Log-Section "CONFIGURATION PATH ET RACCOURCIS"

$pathsToAdd = @(
    "$ToolsDir\RE\YARA",
    "$ToolsDir\RE\FLOSS",
    "$ToolsDir\Sysinternals",
    "$ToolsDir\Forensic\EZTools\net6",
    "$ToolsDir\Forensic\Hayabusa",
    "$ToolsDir\Forensic\Chainsaw",
    "$ToolsDir\Mobile\RE\JADX\bin",
    "$ToolsDir\Mobile\RE\APKTool",
    "$ToolsDir\Mobile\RE\platform-tools"
)

$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
foreach ($p in $pathsToAdd) {
    if (Test-Path $p) {
        if ($currentPath -notlike "*$p*") {
            $currentPath += ";$p"
            Log-Info "PATH += $p"
        }
    }
}
[Environment]::SetEnvironmentVariable("Path", $currentPath, "Machine")

# --- Raccourcis bureau ---
Log-Info "Creation des raccourcis bureau..."
$shell = New-Object -ComObject WScript.Shell

$shortcut = $shell.CreateShortcut("$env:USERPROFILE\Desktop\Tools.lnk")
$shortcut.TargetPath = $ToolsDir
$shortcut.Save()

$shortcut2 = $shell.CreateShortcut("$env:USERPROFILE\Desktop\Cases.lnk")
$shortcut2.TargetPath = "C:\Cases"
$shortcut2.Save()

# --- Raccourcis utils dans C:\Tools\Utils\ ---
Log-Info "Creation des raccourcis utils..."

# 7-Zip
$sevenZipPath = "C:\Program Files\7-Zip\7zFM.exe"
if (Test-Path $sevenZipPath) {
    New-Shortcut -Name "7-Zip" -TargetPath $sevenZipPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Raccourci 7-Zip OK"
}

# Wireshark
$wiresharkPath = "C:\Program Files\Wireshark\Wireshark.exe"
if (Test-Path $wiresharkPath) {
    New-Shortcut -Name "Wireshark" -TargetPath $wiresharkPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Raccourci Wireshark OK"
}

# HxD
$hxdPath = "C:\Program Files\HxD\HxD.exe"
if (!(Test-Path $hxdPath)) { $hxdPath = "C:\Program Files (x86)\HxD\HxD.exe" }
if (Test-Path $hxdPath) {
    New-Shortcut -Name "HxD" -TargetPath $hxdPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Raccourci HxD OK"
}

# Notepad++
$nppPath = "C:\Program Files\Notepad++\notepad++.exe"
if (!(Test-Path $nppPath)) { $nppPath = "C:\Program Files (x86)\Notepad++\notepad++.exe" }
if (Test-Path $nppPath) {
    New-Shortcut -Name "Notepad++" -TargetPath $nppPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Raccourci Notepad++ OK"
}

# VS Code
$vscodePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
if (!(Test-Path $vscodePath)) { $vscodePath = "C:\Program Files\Microsoft VS Code\Code.exe" }
if (Test-Path $vscodePath) {
    New-Shortcut -Name "VS Code" -TargetPath $vscodePath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Raccourci VS Code OK"
}

# Everything
$everythingPath = "C:\Program Files\Everything\Everything.exe"
if (!(Test-Path $everythingPath)) { $everythingPath = "C:\Program Files (x86)\Everything\Everything.exe" }
if (Test-Path $everythingPath) {
    New-Shortcut -Name "Everything" -TargetPath $everythingPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Raccourci Everything OK"
}

# ProcMon
$procmonPath = "$ToolsDir\Sysinternals\Procmon.exe"
if (Test-Path $procmonPath) {
    New-Shortcut -Name "ProcMon" -TargetPath $procmonPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Raccourci ProcMon OK"
}

# ProcExp
$procexpPath = "$ToolsDir\Sysinternals\procexp.exe"
if (Test-Path $procexpPath) {
    New-Shortcut -Name "Process Explorer" -TargetPath $procexpPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Raccourci Process Explorer OK"
}

# Autoruns
$autorunsPath = "$ToolsDir\Sysinternals\Autoruns.exe"
if (Test-Path $autorunsPath) {
    New-Shortcut -Name "Autoruns" -TargetPath $autorunsPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Raccourci Autoruns OK"
}

# TCPView
$tcpviewPath = "$ToolsDir\Sysinternals\tcpview.exe"
if (Test-Path $tcpviewPath) {
    New-Shortcut -Name "TCPView" -TargetPath $tcpviewPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Raccourci TCPView OK"
}

# CyberChef
$cyberchefHtml = Get-ChildItem "$ToolsDir\Utils\CyberChef" -Filter "CyberChef*.html" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($cyberchefHtml) {
    New-Shortcut -Name "CyberChef" -TargetPath $cyberchefHtml.FullName -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Raccourci CyberChef OK"
}

# ============================================================
# 10. RESUME
# ============================================================
Log-Section "INSTALLATION TERMINEE"

Write-Host ""
Write-Host "  ForensicBox - Resume" -ForegroundColor White
Write-Host "  ====================" -ForegroundColor White
Write-Host ""
Write-Host "  C:\Tools\RE\                  Ghidra x64dbg DIE PEStudio FLOSS YARA" -ForegroundColor White
Write-Host "  C:\Tools\Forensic\            EZ Tools Hayabusa Chainsaw Volatility3" -ForegroundColor White
Write-Host "  C:\Tools\Forensic\Disk\       Autopsy (MSI) Arsenal Image Mounter (manuel)" -ForegroundColor White
Write-Host "  C:\Tools\Forensic\Network\    NetworkMiner" -ForegroundColor White
Write-Host "  C:\Tools\Forensic\Acquisition FTK Imager (manuel)" -ForegroundColor White
Write-Host "  C:\Tools\Mobile\RE\           JADX APKTool dex2jar ByteCodeViewer ADB" -ForegroundColor White
Write-Host "  C:\Tools\Mobile\Forensic\     ALEAPP (CLI + GUI) iLEAPP (CLI + GUI) VLEAPP RLEAPP MVT" -ForegroundColor White
Write-Host "  C:\Tools\Sysinternals\        ProcMon ProcExp Autoruns TCPView" -ForegroundColor White
Write-Host "  C:\Tools\Utils\               CyberChef + raccourcis outils installes" -ForegroundColor White
Write-Host "  C:\Cases\                     Workspace d investigation" -ForegroundColor White
Write-Host ""
Write-Host "  pip: Frida Objection MVT Volatility3 androguard apkid scapy dpkt" -ForegroundColor White
Write-Host "       pefile yara-python oletools python-evtx malduck" -ForegroundColor White
Write-Host ""
Write-Host "  INSTALLATIONS MANUELLES REQUISES :" -ForegroundColor Yellow
Write-Host "    - FTK Imager   : https://www.exterro.com/digital-forensics-software/ftk-imager" -ForegroundColor Yellow
Write-Host "    - Arsenal IM   : https://arsenalrecon.com/downloads" -ForegroundColor Yellow
Write-Host "    - Autopsy      : lancer le MSI dans C:\Tools\Forensic\Disk\" -ForegroundColor Yellow
Write-Host ""
Write-Host "  PROCHAINES ETAPES :" -ForegroundColor Cyan
Write-Host "    1. Installer les outils manuels ci-dessus" -ForegroundColor Cyan
Write-Host "    2. Redemarrer la VM" -ForegroundColor Cyan
Write-Host "    3. Snapshot" -ForegroundColor Cyan
Write-Host "    4. Ajoutez vos autre outils à la main" -ForegroundColor Cyan
Write-Host ""