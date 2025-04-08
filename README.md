# Windows PATH Repair Tool (2025 Edition)

## Overview
The Windows PATH Repair Tool is a comprehensive solution for repairing and optimizing your Windows PATH environment variables. It includes an extensive database of potential PATH directories updated for Windows 11 as of April 2025, ensuring all your command-line tools and applications work correctly.

## Features
- 🔍 **Intelligent Detection**: Automatically detects installed tools and applications
- 🧹 **Clean-up**: Removes duplicates and invalid paths
- 🛡️ **Backup Protection**: Automatically backs up your current PATH variables before making changes
- 🧩 **Comprehensive Database**: Includes all common PATH directories for Windows 11 systems
- 🔄 **Separate User/System Paths**: Properly organizes paths between User and System variables

## Requirements
- Windows 10 or 11
- PowerShell 5.1 or later
- Administrator privileges (to update System PATH)

## Installation
No installation required! Simply download the script and run it with PowerShell.

## Usage
1. Right-click on `Windows-PATH-Repair.ps1` and select "Run with PowerShell" (or open PowerShell as Administrator and navigate to the script)
2. Review the discovered directories
3. Confirm the changes when prompted
4. Restart your terminal/command prompt to use the updated PATH

### Advanced Options
You can run the script with various parameters:

```powershell
.\Windows-PATH-Repair.ps1 -Force                # Skip confirmation prompts
.\Windows-PATH-Repair.ps1 -SkipBackup           # Skip backup of current PATH
.\Windows-PATH-Repair.ps1 -SystemPathOnly       # Only fix System PATH
.\Windows-PATH-Repair.ps1 -UserPathOnly         # Only fix User PATH
.\Windows-PATH-Repair.ps1 -Verbose              # Show detailed information
.\Windows-PATH-Repair.ps1 -ShowFoundTools       # Show list of all found tools
.\Windows-PATH-Repair.ps1 -ThoroughSearch       # More thorough but slower search
```

## Safety Features
- Current PATH variables are backed up to `%USERPROFILE%\PathBackups` before any changes
- The script will ask for confirmation before applying changes
- System PATH changes require Administrator privileges

## What's Fixed
- Missing essential Windows system directories
- Missing development tool directories (Python, Java, Node.js, Git, etc.)
- Duplicate entries
- Invalid/non-existent paths
- Incorrect path separators
- Improperly organized User vs System paths

## Support
For issues or questions, please contact your system administrator or open an issue in the repository.
