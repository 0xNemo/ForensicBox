# Forensic Investigation Workspace

## Context

This is a Windows forensic and reverse engineering VM powered by ForensicBox.
Claude Code operates here as a technical assistant for investigation tooling.

## Available tools

### Reverse Engineering
- Ghidra: `C:\Tools\RE\ghidra_*\`
- x64dbg: `C:\Tools\RE\x64dbg\`
- Detect It Easy: `C:\Tools\RE\DIE\`
- PEStudio: `C:\Tools\RE\PEStudio\`
- FLOSS: `C:\Tools\RE\FLOSS\`
- YARA: `C:\Tools\RE\YARA\`

### Disk Forensic
- Autopsy: installed via MSI
- Arsenal Image Mounter: `C:\Tools\Forensic\Disk\ArsenalImageMounter\`
- The Sleuth Kit: available via PATH (mmls, fls, icat, tsk_recover...)
- EZ Tools: `C:\Tools\Forensic\EZTools\` (KAPE, MFTECmd, EvtxECmd, PECmd, RECmd, JLECmd, LECmd, AmcacheParser, AppCompatCacheParser)
- Hayabusa: `C:\Tools\Forensic\Hayabusa\`
- Chainsaw: `C:\Tools\Forensic\Chainsaw\`
- Volatility 3: `vol` or `python -m volatility3`

### Network Forensic
- Wireshark / tshark: installed via PATH
- NetworkMiner: `C:\Tools\Forensic\Network\`
- Npcap: installed (live capture support)
- Python: scapy, dpkt available via pip

### Acquisition
- FTK Imager: `C:\Tools\Forensic\Acquisition\FTKImager\`
- dd: available via PATH

### Mobile RE
- JADX: `C:\Tools\Mobile\RE\JADX\bin\jadx-gui.bat`
- APKTool: `C:\Tools\Mobile\RE\APKTool\apktool.bat`
- dex2jar: `C:\Tools\Mobile\RE\dex2jar\`
- ByteCode Viewer: `C:\Tools\Mobile\RE\ByteCodeViewer\`
- ADB: `C:\Tools\Mobile\RE\platform-tools\`
- Frida / Objection: available via pip

### Mobile Forensic
- ALEAPP: `C:\Tools\Mobile\Forensic\ALEAPP\`
- iLEAPP: `C:\Tools\Mobile\Forensic\ILEAPP\`
- VLEAPP: `C:\Tools\Mobile\Forensic\VLEAPP\`
- RLEAPP: `C:\Tools\Mobile\Forensic\RLEAPP\`
- MVT: available via pip (mvt-android, mvt-ios)

### Utilities
- CyberChef: `C:\Tools\Utils\CyberChef\`
- Sysinternals: `C:\Tools\Sysinternals\` (ProcMon, ProcExp, Autoruns, TCPView)
- Shortcuts to all installed tools in `C:\Tools\Utils\`

### Python libraries
pefile, yara-python, oletools, python-evtx, malduck, pycryptodome, androguard, apkid, scapy, dpkt, pandas, matplotlib

## Rules

1. You help me code investigation tools, parse logs, correlate artifacts, and automate triage.
2. You NEVER conclude on my behalf. Present data and findings, I do the analysis and draw conclusions.
3. When you write code, add comments explaining WHY each step exists, not just what it does.
4. Use Python for scripts. PowerShell for Windows system interaction.
5. Never modify anything in `evidence\`. Read-only, always.
6. All scripts must log their actions to a timestamped log file.

## Case structure

```
C:\Cases\{CASE_ID}\
    evidence\       Raw artifacts (READ-ONLY)
    processing\     Tool outputs and intermediate data
    tools\          Custom scripts for this case
    reports\        Notes and reports
    timeline\       Generated timelines
```

## Workflow

1. I place evidence in `evidence\`
2. You parse and process with the appropriate tools into `processing\`
3. You build custom scripts in `tools\` when I need something specific
4. I analyze the outputs and form conclusions
5. I write the report, you help structure and format it