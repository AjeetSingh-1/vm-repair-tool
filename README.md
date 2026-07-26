# Azure Rescue VM ToolKit

A PowerShell WPF GUI tool for troubleshooting Azure VM no-boot issues from a rescue VM. Also works as a standalone repair utility on any Windows VM.

---

## Prerequisites

- **Windows Server / Windows 10+** (PowerShell 5.1 or later)
- **Run as Administrator** (required for diskpart, DISM, SFC, bcdedit, registry operations)
- For rescue VM scenarios: attach the problematic OS disk to the rescue VM before launching

---

## How to Run

### Option 1: PowerShell Script (Recommended for customer-facing scenarios)

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; .\AzureRescueToolkit.ps1
```

### Option 2: Compiled Executable

Double-click `AzureRescueToolkit.exe` (will prompt for admin elevation).

> **Note:** The .exe may show an "Unknown Publisher" warning. Right-click → Properties → check **Unblock** to suppress it.

---

## Quick Start

1. **Select Disk** — choose the disk number from the dropdown (Disk 0 is usually the rescue VM's own disk)
2. **Read Partitions** — scans the disk, assigns drive letters to partitions that don't have one, auto-detects Windows Volume and System Partition
3. **Verify selections** — confirm the Windows Volume (contains `\Windows`) and System Partition (contains `\boot` or `\EFI`) dropdowns are correct
4. **Run repair actions** as needed

---

## Features

### Repair Actions

| Button | Description |
|--------|-------------|
| **DISM Scan / Repair** | Runs DISM ScanHealth, then prompts for RestoreHealth if corruption is found. Auto-detects Online (local VM) vs Offline (attached disk) mode. |
| **SFC Scan** | Runs System File Checker. Auto-detects Online (`sfc /scannow`) vs Offline (`sfc /scannow /offbootdir /offwindir`) mode. |
| **CHKDSK /f /r** | Checks and repairs filesystem errors on the selected Windows volume. |
| **BCD Rebuild** | Backs up existing BCD to BCD.bak, then rebuilds using `bcdboot`. |
| **Search Filters** | Loads the offline SYSTEM registry hive and scans all device Class GUIDs for UpperFilters and LowerFilters entries. Helps identify third-party filter drivers causing boot failures. |
| **Check Packages** | Lists all installed and staged packages using DISM. Highlights packages in Staged, Install Pending, or Uninstall Pending states. |
| **Remove Package** | Removes a specific package by name from the offline Windows image using DISM. Enter the package identity in the text box. |
| **Disk Offline** | Takes the selected disk offline for safe detach. Checks for errors (e.g., cannot offline the boot disk). |
| **Revert Drive Letters** | Removes only the drive letters that were assigned by this tool during Read Partitions. Pre-existing letters are never touched. |

#### DISM Revert Pending Actions

A checkbox **"Revert Pending Actions (Offline only)"** appears below the repair buttons. This is only enabled when an attached disk (not the local VM) is selected. When checked, the DISM button runs `RevertPendingActions` instead of ScanHealth/RestoreHealth.

### Advanced Boot Options

These modify the offline BCD store to configure next-boot behavior. Each command validates the BCD store is readable before making changes.

| Button | Description |
|--------|-------------|
| **Safe Mode** | Boot with minimal drivers, no networking |
| **Safe Mode + Network** | Boot with networking drivers enabled |
| **Safe Mode + CMD** | Boot to Command Prompt only (no Explorer shell) |
| **Last Known Good (LKGC)** | Sets the Default ControlSet to the LastKnownGood value in the offline SYSTEM hive |
| **DSRM Mode** | Directory Services Restore Mode — only available on Domain Controllers (checks for NTDS service) |
| **Disable Driver Sig** | Disables Driver Signature Enforcement for next boot |
| **Normal Boot** | Removes all boot overrides (safe mode, test signing, etc.) and restores normal boot |

---

## Smart Detection

The tool auto-detects the context and adjusts behavior:

- **Local VM vs Attached Disk** — compares selected drive letter with `$env:SystemDrive`. DISM and SFC automatically switch between Online and Offline modes.
- **System Partition** — auto-detects by scanning for `\boot\BCD`, `\EFI\Microsoft\Boot\BCD`, or `\bootmgr` (uses `-Force` to find hidden/system files).
- **Windows Volume** — auto-detects by scanning for `\Windows` directory.
- **Existing Drive Letters** — Read Partitions checks each partition for an existing letter before assigning. Pre-existing letters are never changed.

---

## Safety Features

- **Guard System** — prevents concurrent command execution. All buttons are disabled while a command is running. A Cancel button appears to abort long-running operations.
- **Registry Hive Safety** — all registry operations (Search Filters, LKGC, DSRM) use try/finally to ensure hives are always unloaded, even on cancel or error.
- **BCD Validation** — before modifying boot configuration, the tool runs `bcdedit /enum {default}` to verify the BCD store is readable. If corrupted, it stops and suggests BCD Rebuild.
- **Input Validation** — package names are validated with regex to prevent command injection.
- **Confirmation Dialogs** — every destructive action shows a confirmation dialog with the exact command that will be executed.
- **Drive Letter Cleanup** — when closing the tool, prompts to remove drive letters that were assigned during the session.
- **Disk Offline Error Handling** — checks diskpart output for errors before reporting success.

---

## Logging

- All operations are logged to the GUI log panel in real-time with live output streaming
- A log file is saved to the current directory: `AzureRescueToolkit_<date>_<time>.log`
- Cleanup operations after window close are written directly to the log file

---

## Files

| File | Description |
|------|-------------|
| `AzureRescueToolkit.ps1` | Main PowerShell source script |
| `AzureRescueToolkit.exe` | Compiled executable (PS2EXE, -NoConsole -RequireAdmin) |
| `AzureRescueToolKit_LLD.docx` | Low Level Design document — detailed code blueprint |
| `AzureRescueToolKit_FixLog.docx` | Change log — all bug fixes and improvements |
| `AzureRescueToolKit_TestChecklist.docx` | Production readiness test checklist (108 test cases) |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Unknown Publisher" warning on .exe | Right-click → Properties → check **Unblock** |
| Tool won't start | Ensure you're running as Administrator |
| "Cannot find BCD store" | Verify the System Partition dropdown is correct. BCD files are hidden — the tool uses `-Force` to detect them. |
| "Cannot index into null array" | Fixed in current version. If still occurring, use the .ps1 instead of .exe. |
| DISM/SFC show no live progress | Fixed in current version — uses event-based output streaming. |
| Drive letters changed after Read Partitions | Fixed — the tool now preserves existing letters and only assigns new ones to partitions without a letter. |
| Black command prompt windows flashing | Fixed — all subprocesses run with `-WindowStyle Hidden`. |

---

## Usage Scenarios

### Rescue VM (attached problematic disk)
1. Attach the problematic OS disk to the rescue VM
2. Launch the tool → select the attached disk number
3. Read Partitions → verify Windows Volume and System Partition
4. Run DISM, SFC, CHKDSK, or configure boot options as needed
5. Disk Offline → detach disk → reattach to original VM

### Standalone VM (local repair)
1. Launch the tool on the VM itself
2. Select the local disk → Read Partitions
3. The tool detects it's the local VM and runs commands in Online mode
4. Use DISM Scan/Repair or SFC Scan for local system file repair
