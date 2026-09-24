# ForensicBox

> Lightweight setup script for Windows forensic. Installs the essential tools, add shortcuts, configure the directory tree.

## What it installs

- **Binary Analysis** : Ghidra, x64dbg, Detect It Easy, PEStudio, FLOSS, YARA, CFF Explorer
- **Forensic** : Eric Zimmerman Tools suite (dotnet-runtime 6,8,9 & latest are installed), Hayabusa, Chainsaw, FTK Imager, Autopsy, The Sleuth Kit
- **Network Forensic** : Wireshark, tshark, NetworkMiner, Npcap
- **Acquisition** : dd for Windows
- **Utilities** : Python3, Sysinternals Suite, CyberChef, HxD, Everything, VS Code, 7-Zip, Notepad++, git, DB Browser for SQLite
- **Python libraries in C:\Tools\venv** : pefile, yara-x, oletools, python-evtx, malduck, androguard, apkid, scapy, matplotlib

- RunPowershellAdmin.bat and CreateCase.bat. 1st just open powershell as admin and 2nd create a new case folder in C:\Cases with incremental ids.


> [!WARNING]
> Windows Defender **Can be removed** at the end of the installation. The script ask you if you want to. 

> It will use [windows-defender-remover](https://github.com/ionuttbara/windows-defender-remover) : toggling Defender off manually is not enough as it reactivates after reboot.


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
| `-SkipAutopsy` | Skip Autopsy download |
| `-SkipDefender` | Skip Windows Defender remove |
| `-SkipEZTools` | Skip Eric Zimmerman Tools download |
| `-SkipReTools` | Skip binary analysis download |
| `-ToolsDir "D:\Tools"` | Change install directory (default: `C:\Tools`) |

## Post-install

1. Snapshot your VM as a gold image
2. Tools are added to PATH : open a new terminal to use them
3. Shortcuts to installed utilities are in `C:\Tools\Utils\`

## Notes

- The script continues on individual tool failures and reports them in yellow. Check the output and install manually if needed.
- GitHub API is used to fetch latest releases. If you hit rate limits, wait a few minutes and rerun with the appropriate `-Skip` flags for tools already installed.
- Designed for disposable VMs. Not recommended for host installations.
