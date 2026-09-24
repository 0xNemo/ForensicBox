# ============================================================
# ForensicBox - Lightweight Forensic and RE Setup Script
# Usage : PowerShell Admin > .\forensicbox.ps1
# ============================================================

param(
    [string]$ToolsDir = "C:\Tools",
    [switch]$SkipChoco,
    [switch]$SkipFolders,
    [switch]$SkipDefender,
    [switch]$SkipEZTools,
    [switch]$SkipReTools,
    [switch]$SkipGhidra,
    [switch]$SkipAutopsy
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
    Log-Error "Run this script ad administrator !"
    exit 1
}

# ============================================================
#   Create useful folders tree
# ============================================================

if (-not $SkipFolders) {
    Log-Section "PREPARATION"
    $dirs = @(
        "$ToolsDir",
        "$ToolsDir\venv",
        "$ToolsDir\BinaryAnalysis",
        "$ToolsDir\Forensic",
        "$ToolsDir\Forensic\evtx",
        "$ToolsDir\Forensic\Eric Zimmerman",
        "$ToolsDir\Forensic\Disk",
        "$ToolsDir\Forensic\Network",
        "$ToolsDir\Utils",
        "$ToolsDir\Sysinternals",
        "C:\Cases"
    )
    foreach ($d in $dirs) {
        if (!(Test-Path $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
            Log-Info "Directory created : $d"
        }
    }
} else {
    Log-Warn "Skip directories tree"
}

# ============================================================
#   Defender exclusion
# ============================================================

$extractDirectory = [System.IO.Path]::GetTempPath()
$excludePath = "$ToolsDir\"

Write-Host ""
try {
    Add-MpPreference -ExclusionPath $extractDirectory
    Add-MpPreference -ExclusionPath $excludePath -ErrorAction Stop
    Log-Warn "Add Windows defender exclusion : $excludePath"
} catch {
    Log-Warn "Error for Windows defender exclusion : $($_.Exception.Message)"
}

# ============================================================
#   Chocolatey
# ============================================================
Log-Section "CHOCOLATEY"

if (-not $SkipChoco) {
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Log-Info "Install of Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path += ";C:\ProgramData\chocolatey\bin"
    } else {
        Log-Info "Chocolatey already installed"
    }
    choco feature enable -n allowGlobalConfirmation | Out-Null

    # ============================================================
    #   basic tools
    # ============================================================
    Log-Section "BASIC TOOLS"

    $chocoPackages = @(
        "python3",
        "dotnet-desktopruntime",
        "dotnet-6.0-desktopruntime",
        "dotnet-8.0-desktopruntime",
        "dotnet-9.0-desktopruntime",
        "git",
        "7zip",
        "notepadplusplus",
        "vscode",
        "everything",
        "wireshark",
        "hxd",
        "sqlitebrowser"
    )

    foreach ($pkg in $chocoPackages) {
        try{
            Log-Info "Install : $pkg"
            choco install $pkg --limit-output 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Log-Info "$pkg OK"
            } else {
                Log-Warn "$pkg - Check manually"
            }
        } catch {

        }
    }

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
} else {
    Log-Warn "Skip Chocolatey"
}


# ============================================================
#   Sysinternals
# ============================================================
Log-Section "SYSINTERNALS"

try {
    Log-Info "Download Sysinternals ..."
    $sysinternalsZip = "$extractDirectory\sysinternals.zip"
    Invoke-WebRequest -Uri "https://download.sysinternals.com/files/SysinternalsSuite.zip" -OutFile $sysinternalsZip -UseBasicParsing
    Expand-Archive -Path $sysinternalsZip -DestinationPath "$ToolsDir\Sysinternals" -Force
    Remove-Item $sysinternalsZip -Force
    Log-Info "Sysinternals OK"
} catch {
    Log-Error "Sysinternals : $($_.Exception.Message)"
}

# ============================================================
#   Binaries useful tools
# ============================================================
Log-Section "BINARIES USEFUL TOOLS"

if (-not $SkipReTools) {
    # --- Ghidra ---
    if (-not $SkipGhidra) {
        Log-Info "Download Ghidra..."
        try {
            $ghidraRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest" -UseBasicParsing
            $ghidraAsset = $ghidraRelease.assets | Where-Object { $_.name -like "ghidra_*_PUBLIC_*.zip" } | Select-Object -First 1
            $ghidraZip = "$extractDirectory\ghidra.zip"
            Invoke-WebRequest -Uri $ghidraAsset.browser_download_url -OutFile $ghidraZip -UseBasicParsing
            Expand-Archive -Path $ghidraZip -DestinationPath "$ToolsDir\BinaryAnalysis" -Force
            Remove-Item $ghidraZip -Force
            Log-Info "Ghidra OK"
        } catch {
            Log-Error "Ghidra : $($_.Exception.Message)"
        }
    } else {
        Log-Warn "Skip Ghidra"
    }

    # --- x64dbg ---
    Log-Info "Download x64dbg..."
    try {
        $x64dbgRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/x64dbg/x64dbg/releases/latest" -UseBasicParsing
        $x64dbgAsset = $x64dbgRelease.assets | Where-Object { $_.name -like "snapshot_*.zip" } | Select-Object -First 1
        $x64dbgZip = "$extractDirectory\x64dbg.zip"
        Invoke-WebRequest -Uri $x64dbgAsset.browser_download_url -OutFile $x64dbgZip -UseBasicParsing
        Expand-Archive -Path $x64dbgZip -DestinationPath "$ToolsDir\BinaryAnalysis\x64dbg" -Force
        Remove-Item $x64dbgZip -Force
        Log-Info "x64dbg OK"
    } catch {
        Log-Error "x64dbg : $($_.Exception.Message)"
    }

    # --- CFF Explorer ---
    Log-Info "Download CFF Explorer..."
    try {
        $cffExplorerZip = "$extractDirectory\CFF_Explorer.zip"
        Invoke-WebRequest -Uri "https://ntcore.com/files/CFF_Explorer.zip" -OutFile $cffExplorerZip -UseBasicParsing
        Expand-Archive -Path $cffExplorerZip -DestinationPath "$ToolsDir\BinaryAnalysis\" -Force
        Remove-Item $cffExplorerZip -Force
        Log-Info "CFF Explorer OK"
    } catch {
        Log-Error "CFF Explorer : $($_.Exception.Message)"
    }

    # --- DNspy ---
    Log-Info "Download DNspy..."
    try {
        $DNspyZip = "$extractDirectory\CFF_Explorer.zip"
        Invoke-WebRequest -Uri "https://github.com/dnSpy/dnSpy/releases/download/v6.1.8/dnSpy-net-win64.zip" -OutFile $DNspyZip -UseBasicParsing
        Expand-Archive -Path $DNspyZip -DestinationPath "$ToolsDir\BinaryAnalysis\DNspy" -Force
        Remove-Item $DNspyZip -Force
        Log-Info "DNspy OK"
    } catch {
        Log-Error "DNspy : $($_.Exception.Message)"
    }

    # --- Detect It Easy ---
    Log-Info "Download Detect It Easy..."
    try {
        $dieRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/horsicq/DIE-engine/releases/latest" -UseBasicParsing
        $dieAsset = $dieRelease.assets | Where-Object { $_.name -like "die_win64_portable_*.zip" } | Select-Object -First 1
        if ($dieAsset) {
            $dieZip = "$extractDirectory\die.zip"
            Invoke-WebRequest -Uri $dieAsset.browser_download_url -OutFile $dieZip -UseBasicParsing
            Expand-Archive -Path $dieZip -DestinationPath "$ToolsDir\BinaryAnalysis\" -Force
            Remove-Item $dieZip -Force
            Log-Info "DIE OK"
        } else {
            Log-Warn "DIE - asset not found"
        }
    } catch {
        Log-Error "DIE : $($_.Exception.Message)"
    }

    # --- PEStudio ---
    Log-Info "Download PEStudio..."
    try {
        $pestudioZip = "$extractDirectory\pestudio.zip"
        Invoke-WebRequest -Uri "https://www.winitor.com/tools/pestudio/current/pestudio.zip" -OutFile $pestudioZip -UseBasicParsing
        Expand-Archive -Path $pestudioZip -DestinationPath "$ToolsDir\BinaryAnalysis\" -Force
        Remove-Item $pestudioZip -Force
        Log-Info "PEStudio OK"
    } catch {
        Log-Error "PEStudio : $($_.Exception.Message)"
    }

    # --- FLOSS ---
    Log-Info "Download FLOSS..."
    try {
        $flossRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/mandiant/flare-floss/releases/latest" -UseBasicParsing
        $flossAsset = $flossRelease.assets | Where-Object { $_.name -like "floss-*-windows.zip" } | Select-Object -First 1
        if ($flossAsset) {
            $flossZip = "$extractDirectory\floss.zip"
            Invoke-WebRequest -Uri $flossAsset.browser_download_url -OutFile $flossZip -UseBasicParsing
            Expand-Archive -Path $flossZip -DestinationPath "$ToolsDir\BinaryAnalysis\FLOSS" -Force
            Remove-Item $flossZip -Force
            Log-Info "FLOSS OK"
        } else {
            Log-Warn "FLOSS - asset not found"
        }
    } catch {
        Log-Error "FLOSS : $($_.Exception.Message)"
    }

    # --- YARA ---
    Log-Info "Download YARA..."
    try {
        $yaraRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/VirusTotal/yara/releases/latest" -UseBasicParsing
        $yaraAsset = $yaraRelease.assets | Where-Object { $_.name -like "yara-*-win64.zip" } | Select-Object -First 1
        if ($yaraAsset) {
            $yaraZip = "$extractDirectory\yara.zip"
            Invoke-WebRequest -Uri $yaraAsset.browser_download_url -OutFile $yaraZip -UseBasicParsing
            Expand-Archive -Path $yaraZip -DestinationPath "$ToolsDir\BinaryAnalysis\YARA" -Force
            Remove-Item $yaraZip -Force
            Log-Info "YARA OK"
        } else {
            Log-Warn "YARA - asset not found"
        }
    } catch {
        Log-Error "YARA : $($_.Exception.Message)"
    }
}

# ============================================================
#   Forensic tools
# ============================================================
Log-Section "FORENSIC TOOLS"

# --- Eric Zimmerman Tools ---
if (-not $SkipEZTools) {
    Log-Info "Downloads Eric Zimmerman Tools..."
    try {
        $ezScript = "$extractDirectory\Get-ZimmermanTools.ps1"
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/EricZimmerman/Get-ZimmermanTools/master/Get-ZimmermanTools.ps1" -OutFile $ezScript -UseBasicParsing
        & $ezScript -Dest "$ToolsDir\Forensic\Eric Zimmerman"
        Remove-Item $ezScript -Force
        Log-Info "EZ Tools OK"
    } catch {
        Log-Error "EZ Tools : $($_.Exception.Message)"
    }
}

# --- ChromeCache viewer ---
Log-Info "Download ChromeCache viewer..."
try {
    $chromeViewerZip = "$extractDirectory\ChromeCacheViewer.zip"
    Invoke-WebRequest -Uri "https://www.nirsoft.net/utils/chromecacheview.zip" -OutFile $chromeViewerZip -UseBasicParsing
    Expand-Archive -Path $chromeViewerZip -DestinationPath "$ToolsDir\Forensic\ChromeCacheViewer" -Force
    Remove-Item $chromeViewerZip -Force
    Log-Info "ChromeCacheViewer OK"
} catch {
    Log-Error "ChromeCacheViewer : $($_.Exception.Message)"
}

# --- Hayabusa ---
Log-Info "Download Hayabusa..."
try {
    $hayabusaRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/Yamato-Security/hayabusa/releases/latest" -UseBasicParsing
    $hayabusaAsset = $hayabusaRelease.assets | Where-Object { $_.name -like "hayabusa-*-win-x64.zip" } | Select-Object -First 1
    if ($hayabusaAsset) {
        $hayabusaZip = "$extractDirectory\hayabusa.zip"
        Invoke-WebRequest -Uri $hayabusaAsset.browser_download_url -OutFile $hayabusaZip -UseBasicParsing
        Expand-Archive -Path $hayabusaZip -DestinationPath "$ToolsDir\Forensic\evtx\Hayabusa" -Force
        Remove-Item $hayabusaZip -Force
        Log-Info "Hayabusa OK"
    } else {
        Log-Warn "Hayabusa - asset not found"
    }
} catch {
    Log-Error "Hayabusa : $($_.Exception.Message)"
}

# --- Chainsaw ---
Log-Info "Download Chainsaw..."
try {
    $chainsawRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/WithSecureLabs/chainsaw/releases/latest" -UseBasicParsing
    $chainsawAsset = $chainsawRelease.assets | Where-Object { $_.name -like "chainsaw_x86_64-pc-windows-msvc.zip" } | Select-Object -First 1
    if ($chainsawAsset) {
        $chainsawZip = "$extractDirectory\chainsaw.zip"
        Invoke-WebRequest -Uri $chainsawAsset.browser_download_url -OutFile $chainsawZip -UseBasicParsing
        Expand-Archive -Path $chainsawZip -DestinationPath "$ToolsDir\Forensic\evtx\" -Force
        Remove-Item $chainsawZip -Force
        Log-Info "Chainsaw OK"
    } else {
        Log-Warn "Chainsaw - asset not found"
    }
} catch {
    Log-Error "Chainsaw : $($_.Exception.Message)"
}

# --- CyberChef ---
Log-Info "Download CyberChef..."
try {
    $cyberchefRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/gchq/CyberChef/releases/latest" -UseBasicParsing
    $cyberchefAsset = $cyberchefRelease.assets | Where-Object { $_.name -like "CyberChef_*.zip" } | Select-Object -First 1
    if ($cyberchefAsset) {
        $cyberchefZip = "$extractDirectory\cyberchef.zip"
        Invoke-WebRequest -Uri $cyberchefAsset.browser_download_url -OutFile $cyberchefZip -UseBasicParsing
        Expand-Archive -Path $cyberchefZip -DestinationPath "$ToolsDir\Utils\CyberChef" -Force
        Remove-Item $cyberchefZip -Force
        Log-Info "CyberChef OK"
    } else {
        Log-Warn "CyberChef - asset not found"
    }
} catch {
    Log-Error "CyberChef : $($_.Exception.Message)"
}

# ============================================================
#   Disk forensic
# ============================================================
Log-Section "DISK FORENSIC"

# --- Autopsy ---
if (-not $SkipAutopsy) {
    Log-Info "Download Autopsy..."
    try {
        $autopsyRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/sleuthkit/autopsy/releases/latest" -UseBasicParsing
        $autopsyAsset = $autopsyRelease.assets | Where-Object { $_.name -like "autopsy-*.msi" } | Select-Object -First 1
        if ($autopsyAsset) {
            $autopsyMsi = "$ToolsDir\Forensic\Disk\autopsy-installer.msi"
            Invoke-WebRequest -Uri $autopsyAsset.browser_download_url -OutFile $autopsyMsi -UseBasicParsing
            # Log-Info "Autopsy MSI telecharge dans $ToolsDir\Forensic\Disk\ - lance le MSI manuellement"
            try{
                $process = Start-Process -FilePath $autopsyMsi
            } catch {
                Log-Warn "Autopsy need to be installed manualy with the MSI"
            }
        } else {
            Log-Warn "Autopsy - asset not found - downloaded from https://www.autopsy.com/download/"
        }
    } catch {
        Log-Error "Autopsy : $($_.Exception.Message)"
        Log-Warn "Download it manualy from https://www.autopsy.com/download/"
    }
} else {
    Log-Warn "Skip Autopsy"
}

# # --- FTK Imager ---
# Log-Info "FTK Imager - telechargement manuel requis"
# Log-Warn "FTK Imager necessite un compte Exterro :"
# Log-Warn "  1. Telecharge depuis https://www.exterro.com/digital-forensics-software/ftk-imager"
# Log-Warn "  2. Installe dans $ToolsDir\Forensic\Acquisition\FTKImager\"
# New-Item -ItemType Directory -Path "$ToolsDir\Forensic\Acquisition\FTKImager" -Force | Out-Null
# $ftkReadme = "Telecharger FTK Imager depuis https://www.exterro.com/digital-forensics-software/ftk-imager et installer ici."
# Set-Content -Path "$ToolsDir\Forensic\Acquisition\FTKImager\_INSTALLER_ICI.txt" -Value $ftkReadme -Encoding UTF8

# --- FTK Imager ---
Log-Info "Download FTKimager..."
try {
    $FTKimagerZip = "$extractDirectory\FTKimager.zip"
    Invoke-WebRequest -Uri "https://d1kpmuwb7gvu1i.cloudfront.net/8.3/Imager/FTK%20Imager%208.3.0.27.zip" -OutFile $FTKimagerZip -UseBasicParsing
    Expand-Archive -Path $FTKimagerZip -DestinationPath "$ToolsDir\Forensic\Disk\FTKimager" -Force
    Remove-Item $FTKimagerZip -Force
    Log-Info "FTKimager OK"
    try{
        $process = Start-Process -FilePath "$ToolsDir\Forensic\Disk\FTKimager\Exterro*.exe"
    } catch {
        Log-Warn "FTK Imager need to be installed manualy with the MSI"
    }    
} catch {
    Log-Error "FTKimager : $($_.Exception.Message)"
    Log-Warn "FTK Imager - Download it manualy : https://www.exterro.com/ftk-downloads/ftk-imager-8-3"
}

# --- dd / dcfldd via Chocolatey ---
Log-Info "Install of dd for Windows..."
try {
    choco install yourkit-dd --limit-output 2>&1 | Out-Null
    Log-Info "dd OK"
} catch {
    Log-Warn "dd - Download it manualy"
}

# --- The Sleuth Kit (disk analysis CLI) ---
Log-Info "Install of The Sleuth Kit..."
try {
    choco install sleuthkit --limit-output 2>&1 | Out-Null
    Log-Info "The Sleuth Kit OK"
} catch {
    Log-Warn "The Sleuth Kit - Download it manualy"
}

# ============================================================
#   network forensic
# ============================================================
Log-Section "NETWORK FORENSIC"

# --- NetworkMiner ---
Log-Info "Download NetworkMiner Free..."
try {
    $nmZip = "$extractDirectory\networkminer.zip"
    Invoke-WebRequest -Uri "https://www.netresec.com/?download=NetworkMiner" -OutFile $nmZip -UseBasicParsing
    Expand-Archive -Path $nmZip -DestinationPath "$ToolsDir\Forensic\Network" -Force
    Remove-Item $nmZip -Force
    Log-Info "NetworkMiner OK"
} catch {
    Log-Warn "NetworkMiner - Download failed"
    Log-Warn "Download it manualy from https://www.netresec.com/?page=NetworkMiner"
}

# --- tshark (CLI Wireshark - deja installe via choco wireshark) ---
Log-Info "tshark already satisfied with Wireshark installation"

# --- npcap (requis pour capture live) ---
Log-Info "Install Npcap..."
try {
    choco install npcap --limit-output 2>&1 | Out-Null
    Log-Info "Npcap OK"
} catch {
    Log-Warn "Npcap - Download it manualy from https://npcap.com/"
}

# ============================================================
#   Python libs
# ============================================================
Log-Section "PYTHON FORENSIC LIBRARIES"

$venvPath   = "$ToolsDir\venv"
$venvPython = Join-Path $venvPath "Scripts\python.exe"

$pipPackages = @(
    "pefile",
    "yara-x",
    "oletools",
    "python-evtx",
    "malduck",
    "pycryptodome",
    "requests",
    "matplotlib",
    "androguard",
    "apkid",
    "scapy",
    "pyshark"
)

if (-not (Test-Path $venvPython)) {
    Log-Info "Creating the venv : $venvPath"
    New-Item -ItemType Directory -Path (Split-Path $venvPath) -Force | Out-Null
    python -m venv $venvPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $venvPython)) {
        throw "Error when creating the venv : $venvPath"
    }
} else {
    Log-Info "Venv already created : $venvPath"
}

& $venvPython -m pip install --upgrade pip setuptools wheel 2>&1 | Out-Null

$failed = @()
foreach ($pkg in $pipPackages) {
    Log-Info "pip install (venv) : $pkg"
    & $venvPython -m pip install --disable-pip-version-check $pkg 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { $failed += $pkg }
}

if ($failed.Count -gt 0) {
    Write-Warning "Failed install : $($failed -join ', ')"
} else {
    Log-Info "Python libs OK (venv : $venvPath)"
}

# $pipPackages = @(
#     "pefile",
#     "yara-x",
#     "oletools",
#     "python-evtx",
#     "malduck",
#     "pycryptodome",
#     "requests",
#     "matplotlib",
#     "androguard",
#     "apkid",
#     "scapy",
#     "pyshark"
# )

# foreach ($pip in $pipPackages) {
#     Log-Info "pip install : $pip"
#     pip install $pip 2>&1 | Out-Null
# }
# Log-Info "Python libs OK"

# ============================================================
#   PATH & SHORTCUTS
# ============================================================
Log-Section "PATH & SHORTCUTS"

$desktop = [Environment]::GetFolderPath("Desktop")
Get-ChildItem -Path $desktop -Filter "*.lnk" | Remove-Item -Force
Get-ChildItem -Path "C:\Users\Public\Desktop" -Filter "*.lnk" | Remove-Item -Force

$pathsToAdd = @(
    "$ToolsDir\BinaryAnalysis\YARA",
    "$ToolsDir\BinaryAnalysis\FLOSS",
    "$ToolsDir\Sysinternals",
    "$ToolsDir\Forensic\Eric Zimmerman\net9",
    "$ToolsDir\Forensic\evtx\Hayabusa",
    "$ToolsDir\Forensic\evtx\Chainsaw",
    "$ToolsDir\Forensic\ChromeCacheViewer"
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


# --- Shortcuts desktop ---
Log-Info "Shortcuts creation on desktop..."
$WshShell = New-Object -ComObject WScript.Shell

$Shortcuts = @(
    @{ Nom = "Tools"; Cible = "$ToolsDir" }
    @{ Nom = "Cases"; Cible = "C:\Cases" }
    @{ Nom = "Z";     Cible = "Z:\" }
)

foreach ($r in $Shortcuts) {
    $shortcut = $WshShell.CreateShortcut("$desktop\$($r.Nom).lnk")
    $shortcut.TargetPath = $r.Cible
    $shortcut.Save()
    Log-Info "Shortcut created : $($r.Nom) -> $($r.Cible)"
}

# --- Shortcuts utils in C:\Tools\Utils\ ---
Log-Info "Shortcuts creation of utils..."

# 7-Zip
$sevenZipPath = "C:\Program Files\7-Zip\7zFM.exe"
if (Test-Path $sevenZipPath) {
    New-Shortcut -Name "7-Zip" -TargetPath $sevenZipPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Shortcut 7-Zip OK"
}

# dbBrowser
$dbBrowserPath = "C:\Program Files\DB Browser for SQLite\DB Browser for SQLite.exe"
if (Test-Path $sevenZipPath) {
    New-Shortcut -Name "DB Browser (SQLite)" -TargetPath $dbBrowserPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Shortcut DB Browser OK"
}

# Wireshark
$wiresharkPath = "C:\Program Files\Wireshark\Wireshark.exe"
if (Test-Path $wiresharkPath) {
    New-Shortcut -Name "Wireshark" -TargetPath $wiresharkPath -ShortcutDir "$ToolsDir\Forensic\Network"
    Log-Info "Shortcut Wireshark OK"
}

# HxD
$hxdPath = "C:\Program Files\HxD\HxD.exe"
if (!(Test-Path $hxdPath)) { $hxdPath = "C:\Program Files (x86)\HxD\HxD.exe" }
if (Test-Path $hxdPath) {
    New-Shortcut -Name "HxD" -TargetPath $hxdPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Shortcut HxD OK"
}

# Notepad++
$nppPath = "C:\Program Files\Notepad++\notepad++.exe"
if (!(Test-Path $nppPath)) { $nppPath = "C:\Program Files (x86)\Notepad++\notepad++.exe" }
if (Test-Path $nppPath) {
    New-Shortcut -Name "Notepad++" -TargetPath $nppPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Shortcut Notepad++ OK"
}

# VS Code
$vscodePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
if (!(Test-Path $vscodePath)) { $vscodePath = "C:\Program Files\Microsoft VS Code\Code.exe" }
if (Test-Path $vscodePath) {
    New-Shortcut -Name "VS Code" -TargetPath $vscodePath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Shortcut VS Code OK"
}

# Everything
$everythingPath = "C:\Program Files\Everything\Everything.exe"
if (!(Test-Path $everythingPath)) { $everythingPath = "C:\Program Files (x86)\Everything\Everything.exe" }
if (Test-Path $everythingPath) {
    New-Shortcut -Name "Everything" -TargetPath $everythingPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Shortcut Everything OK"
}

# ProcMon
$procmonPath = "$ToolsDir\Sysinternals\Procmon.exe"
if (Test-Path $procmonPath) {
    New-Shortcut -Name "ProcMon" -TargetPath $procmonPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Shortcut ProcMon OK"
}

# ProcExp
$procexpPath = "$ToolsDir\Sysinternals\procexp.exe"
if (Test-Path $procexpPath) {
    New-Shortcut -Name "Process Explorer" -TargetPath $procexpPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Shortcut Process Explorer OK"
}

# Autoruns
$autorunsPath = "$ToolsDir\Sysinternals\Autoruns.exe"
if (Test-Path $autorunsPath) {
    New-Shortcut -Name "Autoruns" -TargetPath $autorunsPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Shortcut Autoruns OK"
}

# TCPView
$tcpviewPath = "$ToolsDir\Sysinternals\tcpview.exe"
if (Test-Path $tcpviewPath) {
    New-Shortcut -Name "TCPView" -TargetPath $tcpviewPath -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Shortcut TCPView OK"
}

# CyberChef
$cyberchefHtml = Get-ChildItem "$ToolsDir\Utils\CyberChef" -Filter "CyberChef*.html" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($cyberchefHtml) {
    New-Shortcut -Name "CyberChef" -TargetPath $cyberchefHtml.FullName -ShortcutDir "$ToolsDir\Utils"
    Log-Info "Shortcut CyberChef OK"
}

# ============================================================
#   usefull .bat
# ============================================================
Log-Section "SCRIPTS .BAT"


# --- LancerPowershellAdmin.bat ---
$batPath = "$desktop\RunPowershellAdmin.bat"
$batContent = @'
@echo off
powershell -Command "Start-Process powershell -Verb RunAs"
'@
Set-Content -Path $batPath -Value $batContent -Encoding ASCII
Log-Info "Created .bat : $batPath"


# --- CreerCase.bat ---
$folderPath = "C:\Cases"
$ps1Path = Join-Path $folderPath "CreateCase.ps1"
$batPath  = Join-Path $folderPath "CreateCase.bat"

$ps1Content = @'
Add-Type -AssemblyName Microsoft.VisualBasic

$casesRoot = "C:\Cases"

$nomCase = [Microsoft.VisualBasic.Interaction]::InputBox("Nom de la case :", "Nouvelle Case", "")

if ([string]::IsNullOrWhiteSpace($nomCase)) {
    [System.Windows.Forms.MessageBox]::Show("Nom invalide, annulation.", "Erreur", "OK", "Error") | Out-Null
    exit
}

# Nettoyage des caractères interdits dans un nom de dossier
$nomCase = $nomCase -replace '[\\/:*?"<>|]', '_'

$dossiers = Get-ChildItem -Path $casesRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(\d+)-' }

$maxId = 0
foreach ($d in $dossiers) {
    $id = [int]($d.Name -split '-')[0]
    if ($id -gt $maxId) { $maxId = $id }
}

$nouvelId = $maxId + 1
$nomDossier = "$nouvelId-$nomCase"
$cheminComplet = Join-Path $casesRoot $nomDossier

$sousDossiers = @('evidence', 'processing', 'tools', 'reports', 'timeline')

New-Item -Path $cheminComplet -ItemType Directory | Out-Null
foreach ($s in $sousDossiers) {
    New-Item -Path (Join-Path $cheminComplet $s) -ItemType Directory | Out-Null
}

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show("Dossier cree : $cheminComplet", "Succes", "OK", "Information") | Out-Null
'@

Set-Content -Path $ps1Path -Value $ps1Content -Encoding UTF8

$batContent = @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$ps1Path"
"@

Set-Content -Path $batPath -Value $batContent -Encoding ASCII

Log-Info "Created files :"
Log-Info "  - $ps1Path"
Log-Info "  - $batPath"

# ============================================================
#   RESUME
# ============================================================
Log-Section "INSTALLATION DONE"
Write-Host ""
Write-Host "  Defender removed"
Write-Host ""
Write-Host "  ForensicBox - Resume" -ForegroundColor White
Write-Host "  ====================" -ForegroundColor White
Write-Host ""
Write-Host "  $ToolsDir\BinaryAnalysis\      Ghidra CFFexplorer DNspy x64dbg DIE PEStudio FLOSS YARA" -ForegroundColor White
Write-Host "  $ToolsDir\Forensic\            EZ Tools ChromeCacheViewer" -ForegroundColor White
Write-Host "  $ToolsDir\Forensic\evtx        Hayabusa Chainsaw" -ForegroundColor White
Write-Host "  $ToolsDir\Forensic\Disk\       Autopsy (MSI) FTK Imager (MSI)" -ForegroundColor White
Write-Host "  $ToolsDir\Forensic\Network\    NetworkMiner" -ForegroundColor White
Write-Host "  $ToolsDir\Sysinternals\        Suite Sysinternals" -ForegroundColor White
Write-Host "  $ToolsDir\Utils\               CyberChef + shortcuts" -ForegroundColor White
Write-Host "  $ToolsDir\venv\                Venv python with installed libs" -ForegroundColor White
Write-Host "  C:\Cases\                      Workspace of investigation" -ForegroundColor White
Write-Host ""
Write-Host "  Choco installed packages" -ForegroundColor White
Write-Host "  ====================" -ForegroundColor White
Write-Host ""
Write-Host "  - python3" -ForegroundColor White
Write-Host "  - dotnet-runtime" -ForegroundColor White #Essentiel pour les outils zimmerman
Write-Host "  - git" -ForegroundColor White
Write-Host "  - 7zip" -ForegroundColor White
Write-Host "  - notepad++" -ForegroundColor White
Write-Host "  - vscode" -ForegroundColor White
Write-Host "  - everything" -ForegroundColor White
Write-Host "  - wireshark" -ForegroundColor White
Write-Host "  - hxd" -ForegroundColor White
Write-Host "  - sqlitebrowser" -ForegroundColor White
Write-Host "  - dd" -ForegroundColor White
Write-Host "  - SleuthKit" -ForegroundColor White
Write-Host "  - Npcap" -ForegroundColor White
Write-Host ""
Write-Host "  Pip installed packages" -ForegroundColor White
Write-Host "  ====================" -ForegroundColor White
Write-Host ""
Write-Host "  - pefile" -ForegroundColor White
Write-Host "  - yara-x" -ForegroundColor White #Essentiel pour les outils zimmerman
Write-Host "  - oletools" -ForegroundColor White
Write-Host "  - python-evtx" -ForegroundColor White
Write-Host "  - malduck" -ForegroundColor White
Write-Host "  - pycryptodome" -ForegroundColor White
Write-Host "  - requests" -ForegroundColor White
Write-Host "  - matplotlib" -ForegroundColor White
Write-Host "  - androguard" -ForegroundColor White
Write-Host "  - apkid" -ForegroundColor White
Write-Host "  - scapy" -ForegroundColor White
Write-Host "  - pyshark" -ForegroundColor White
Write-Host ""
Write-Host ""
Write-Host "  NEXT STEPS :" -ForegroundColor Cyan
Write-Host "    1. Reboot VM" -ForegroundColor Cyan
Write-Host "    2. Snapshot" -ForegroundColor Cyan
Write-Host "    3. Add other tools manualy" -ForegroundColor Cyan
Write-Host "    4. Shortcuts to installed utilities are in C:\Tools\Utils\" -ForegroundColor Cyan
Write-Host ""


# ============================================================
#   Remove Windows Defender
# ============================================================
Write-Host "`n========== Remove Windows Defender ==========" -ForegroundColor Red
Write-Host ""
Log-Warn "Remove Windows Defender step"
Log-Warn "This is a tool from https://github.com/ionuttbara/windows-defender-remover"

if (-not $SkipDefender) {
    do {
        $reponse = Read-Host "Do you want to remove Windows Defender ? (Y/N)"
    } while ($reponse -notmatch "^[YyNn]$")

    if ($reponse -match "^[Yy]$") {
        Write-Host "Exec of windows-defender-remover ..."
        $repoName = "ionuttbara/windows-defender-remover"
        $assetPattern = "Defender.Remover*.exe"
        
            try{
                $releasesUri = "https://api.github.com/repos/$repoName/releases/latest"
                $asset = (Invoke-WebRequest $releasesUri | ConvertFrom-Json).assets | Where-Object name -like $assetPattern
                $downloadUri = $asset.browser_download_url

                $extractPath = [System.IO.Path]::Combine($extractDirectory, $asset.name)
                Invoke-WebRequest -Uri $downloadUri -Out $extractPath

                $process = Start-Process -FilePath $extractPath -Wait -PassThru

                if ($process.ExitCode -eq 0) {
                    Log-Info "Successful installation, continue..."
                } else {
                    throw "Execution error (code $($process.ExitCode))"
                }
            } catch {
                Log-Error "Error : $_" -ForegroundColor Red
            }
        
    } else {
        Log-Warn "Ok Don't install windows-defender-remover"
    }
} else {
        Log-Warn "Skip Remove Defender"
}