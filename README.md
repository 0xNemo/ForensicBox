# ForensicBox

Lightweight setup script for Windows forensic and reverse engineering VMs. Installs the essential tools without the overhead of full distributions like FLARE-VM.

## What it installs

**Reverse Engineering** — Ghidra, x64dbg, Detect It Easy, PEStudio, FLOSS, YARA

**Disk Forensic** — Eric Zimmerman Tools (KAPE, MFTECmd, EvtxECmd, PECmd, RECmd...), Hayabusa, Chainsaw, Volatility 3, Autopsy, The Sleuth Kit

**Network Forensic** — Wireshark, tshark, NetworkMiner, Npcap

**Acquisition** — dd for Windows

**Mobile RE** — JADX, APKTool, dex2jar, ByteCode Viewer, ADB Platform Tools, Frida, Objection

**Mobile Forensic** — ALEAPP (CLI + GUI), iLEAPP (CLI + GUI), VLEAPP, RLEAPP, MVT

**Utilities** — Sysinternals Suite, CyberChef, HxD, Everything, VS Code, 7-Zip, Notepad++

**Python libraries** — pefile, yara-python, oletools, python-evtx, malduck, androguard, apkid, scapy, dpkt, pandas, matplotlib

## Manual installs

The following tools require manual download due to licensing or registration:

| Tool | Download | Install to |
|------|----------|------------|
| FTK Imager | https://www.exterro.com/digital-forensics-software/ftk-imager | `C:\Tools\Forensic\Acquisition\FTKImager\` |
| Arsenal Image Mounter | https://arsenalrecon.com/downloads | `C:\Tools\Forensic\Disk\ArsenalImageMounter\` |
| Autopsy | MSI downloaded to `C:\Tools\Forensic\Disk\` | Run the MSI |

## Prerequisites

- Windows 10 or 11 (tested on Windows 10 Home)
- PowerShell 5.1+
- Internet connection
- Windows Defender **must be removed** before running the script. Use [windows-defender-remover](https://github.com/ionuttbara/windows-defender-remover) — toggling Defender off manually is not enough as it reactivates after reboot.

## Usage

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\forensicbox.ps1
```

### Options

| Flag | Effect |
|------|--------|
| `-SkipChoco` | Skip Chocolatey installation and all choco packages |
| `-SkipGhidra` | Skip Ghidra download |
| `-SkipEZTools` | Skip Eric Zimmerman Tools download |
| `-ToolsDir "D:\Tools"` | Change install directory (default: `C:\Tools`) |

## Directory structure

```
C:\Tools\
├── RE\                     Ghidra, x64dbg, DIE, PEStudio, FLOSS, YARA
├── Forensic\
│   ├── EZTools\            KAPE, MFTECmd, EvtxECmd, PECmd, RECmd...
│   ├── Hayabusa\
│   ├── Chainsaw\
│   ├── Disk\               Autopsy, Arsenal Image Mounter
│   ├── Network\            NetworkMiner
│   └── Acquisition\        FTK Imager, dd
├── Mobile\
│   ├── RE\                 JADX, APKTool, dex2jar, ByteCodeViewer, ADB
│   └── Forensic\           ALEAPP (GUI), iLEAPP (GUI), VLEAPP, RLEAPP
├── Sysinternals\           ProcMon, ProcExp, Autoruns, TCPView...
└── Utils\                  CyberChef + shortcuts to installed tools

C:\Cases\                   Investigation workspace
```

## Post-install

1. Install the manual tools listed above
2. Reboot the VM
3. Snapshot your VM as a gold image
4. Tools are added to PATH — open a new terminal to use them
5. Shortcuts to installed utilities (7-Zip, Wireshark, HxD, VS Code, Everything, ProcMon, ProcExp, Autoruns, TCPView, CyberChef) are in `C:\Tools\Utils\`

### Working with Claude

Place `CLAUDE.md` in `C:\Cases\` — You can use it to work with claude code or desktop and guide him for investigations.

## Notes

- The script continues on individual tool failures and reports them in yellow. Check the output and install manually if needed.
- GitHub API is used to fetch latest releases. If you hit rate limits, wait a few minutes and rerun with the appropriate `-Skip` flags for tools already installed.
- Designed for disposable VMs. Not recommended for host installations.