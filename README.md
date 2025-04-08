Could not find this anywhere online after goofing up my PATH variables so here is the fix for those of you with the issue :)

# Windows PATH Repair Tool (2025 Edition)

A comprehensive repair tool for Windows PATH environment variables that automatically finds and fixes issues with your system and user PATH.

## 🔍 Problem

The Windows PATH environment variable is critical for accessing command-line tools and applications, but it often becomes cluttered, contains invalid entries, or is missing essential directories. This can lead to "command not found" errors and other frustrating issues that affect productivity.

## ✨ Solution

This PowerShell script automates the process of repairing and optimizing your Windows PATH variables by:

1. **Backing up** your current PATH settings before making any changes
2. **Adding essential Windows system directories** that should always be in your PATH
3. **Finding and including directories** for development tools installed on your system
4. **Removing duplicates and invalid paths** that slow down command resolution
5. **Properly setting both System and User PATH variables** to respect Windows best practices

## 🚀 Features

- **Comprehensive Directory Discovery**: Automatically finds common directories for programming languages, developer tools, and utilities
- **Smart Path Detection**: Uses wildcard patterns to find directories across different versions of the same software
- **Automatic Tool Detection**: Searches for 50+ common developer tools and adds their locations to your PATH
- **Backup and Restore**: Creates timestamped backups of your PATH settings before making changes
- **User/System Separation**: Properly organizes directories between User and System PATH variables

## 🗂️ Supported Tools and Directories

The tool automatically detects and adds directories for:

- **Programming Languages**: Python, Node.js, Java (all JDK variants), .NET, Go, Ruby, PHP, Rust, Perl, Dart, etc.
- **Developer Tools**: Git, Docker, Kubernetes, Terraform, VS Code, PowerShell, etc.
- **Build Tools**: Maven, Gradle, npm, yarn, pip, etc.
- **Database Tools**: PostgreSQL, MySQL, MongoDB, SQLite, Redis, etc.
- **Virtualization**: VirtualBox, VMware, Vagrant, etc.
- **And many more!**

## 🔧 Usage

### Option 1: Run with Administrator Privileges (Recommended)

Double-click the `Run-PATH-Repair-Admin.bat` file to launch the script with administrator privileges (required to modify the System PATH).

### Option 2: Run Manually from PowerShell

1. Open a PowerShell prompt as Administrator
2. Navigate to the script directory
3. Run: `.\Windows-PATH-Repair.ps1`

### Advanced Options

The script supports several command-line parameters:

```powershell
.\Windows-PATH-Repair.ps1 [-Force] [-SkipBackup] [-SystemPathOnly] [-UserPathOnly] [-ShowFoundTools] [-Verbose] [-ThoroughSearch] [-IgnoreAccessErrors] [-MaxSearchDepth <depth>]
```

- `-Force`: Skip confirmation prompts
- `-SkipBackup`: Don't create backup files
- `-SystemPathOnly`: Only fix the System PATH (not User PATH)
- `-UserPathOnly`: Only fix the User PATH (not System PATH)
- `-ShowFoundTools`: Display a list of all development tools found
- `-Verbose`: Show detailed information during execution
- `-ThoroughSearch`: Perform a more thorough but slower search
- `-IgnoreAccessErrors`: Ignore access denied errors during searches
- `-MaxSearchDepth <depth>`: Maximum folder depth to search (default: 4)

## ⚠️ Important Notes

- The script must be run with Administrator privileges to update the System PATH
- Always restart your terminal or command prompt after running the script to use the updated PATH
- Backups are stored in `%USERPROFILE%\PathBackups`

## 📋 Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or later

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
