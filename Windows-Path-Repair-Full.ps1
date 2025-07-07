<#
.SYNOPSIS
    Windows PATH Environment Variable Repair Tool (2025 Edition) - Enhanced

.DESCRIPTION
    Comprehensive repair tool for Windows PATH environment variables by:
    1. Backing up current PATH settings
    2. Adding essential Windows system directories
    3. Finding and including directories for common development tools (including npm and Chocolatey)
    4. Removing duplicates and invalid paths
    5. Properly setting both System and User PATH variables
    
    This enhanced tool includes a more complete list of possible PATH directories
    for Windows 10/11 and popular development tools as of mid-2025, with
    specific attention to npm and Chocolatey installations.

.NOTES
    Author: Clarboncy (Original), Gemini (Enhancements)
    Version: 2.3
    Date: 2025-07-07
    Requirements: Windows 10/11, PowerShell 5.1 or later
    Run with Administrator privileges to update System PATH
#>

[CmdletBinding(DefaultParameterSetName='Default')]
param (
    [switch]$Force,             # Skip confirmation prompts
    [switch]$SkipBackup,        # Skip backup of current PATH
    [switch]$SystemPathOnly,    # Only fix System PATH (not User PATH)
    [switch]$UserPathOnly,      # Only fix User PATH (not System PATH)
    [switch]$ShowFoundTools,    # Show list of all found tools
    [int]$MaxSearchDepth = 4,   # Max folder depth to search for tool binaries
    [switch]$IgnoreAccessErrors, # Ignore access denied errors during directory search
    [switch]$ThoroughSearch,    # More thorough but slower search for tools
    [switch]$DryRun,             # Preview changes without applying them
    [switch]$ShowSearchDetails  # Show detailed search results for each directory
)

# --- Configuration and Setup ---

# Create backup directory
$backupDir = "$env:USERPROFILE\Path_Backups"
try {
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Write-Host "Backup directory created: '$backupDir'" -ForegroundColor Cyan
    }
}
catch {
    Write-Host "ERROR: Failed to create backup directory '$backupDir': $_" -ForegroundColor Red
    Write-Host "Please ensure you have write permissions." -ForegroundColor Red
    exit 1
}

# Define essential Windows system paths (order matters for some, e.g., System32 before SystemRoot)
# These are paths that are almost always required for Windows to function correctly.
$essentialSystemPaths = @(
    "$env:SystemRoot\system32"
    "$env:SystemRoot\system32\cmd" # Explicitly include cmd for clarity, though often covered by system32
    "$env:SystemRoot"
    "$env:SystemRoot\System32\Wbem"
    "$env:SystemRoot\System32\WindowsPowerShell\v1.0\"
    "$env:SystemRoot\System32\OpenSSH\"
    "$env:SystemRoot\System32\drivers\etc" # For hosts file, etc.
    "$env:ProgramFiles\WindowsPowerShell\Scripts" # For PowerShell modules/scripts
    "$env:ProgramFiles\PowerShell\" # For PowerShell Core/7+
    "$env:ProgramFiles\Common Files\Microsoft Shared\WindowsApps" # Common for UWP apps
    "$env:ProgramFiles\Git\cmd" # Git Bash
    "$env:ProgramFiles\Git\bin" # Git core binaries
    "$env:ProgramFiles\Git\usr\bin" # Git utilities
    "$env:ProgramFiles\Git\mingw64\bin" # MinGW binaries for Git
    "$env:ProgramFiles\Docker\Docker\resources\bin" # Docker Desktop CLI
    "$env:ProgramFiles\nodejs\" # Node.js default
    "$env:ProgramFiles\Microsoft VS Code\bin" # VS Code CLI
    "$env:ProgramFiles(x86)\Git\cmd" # 32-bit Git Bash
    "$env:ProgramFiles(x86)\Git\bin" # 32-bit Git core binaries
    "$env:ProgramFiles(x86)\Git\usr\bin" # 32-bit Git utilities
    "$env:ProgramFiles(x86)\Git\mingw64\bin" # 32-bit MinGW binaries for Git
    "$env:ProgramFiles(x86)\nodejs\" # 32-bit Node.js
    "$env:ProgramFiles(x86)\Microsoft VS Code\bin" # 32-bit VS Code CLI
    "C:\ProgramData\chocolatey\bin" # Explicitly added for Chocolatey
) | Select-Object -Unique

# Define essential Windows user paths
# These are paths typically found in the user's PATH variable.
$essentialUserPaths = @(
    "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps"
    "$env:USERPROFILE\AppData\Roaming\npm" # Node Package Manager global installs
    "$env:USERPROFILE\.dotnet\tools" # .NET Core global tools
    "$env:USERPROFILE\.cargo\bin" # Rust Cargo binaries
    "$env:USERPROFILE\go\bin" # Go language binaries
    "$env:USERPROFILE\scoop\shims" # Scoop package manager shims
    "$env:USERPROFILE\AppData\Local\Programs\Python\Python3x\Scripts" # Generic Python scripts, will be refined by search
    "$env:USERPROFILE\AppData\Local\Programs\Python\Python3x" # Generic Python root, will be refined by search
    "$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code\bin" # VS Code for user installs
) | Select-Object -Unique

# Common root directories to search for development tools
$toolSearchPaths = @(
    "C:\Program Files"
    "C:\Program Files (x86)"
    "C:\Users\$env:USERNAME\AppData\Local\Programs"
    "C:\Users\$env:USERNAME\AppData\Roaming"
    "C:\Users\$env:USERNAME\Documents" # For some dev tools that might install here
    "C:\Users\$env:USERNAME" # For tools like .git, .ssh, etc.
    "C:\Dev" # Common custom development folder
    "C:\Tools" # Another common custom tools folder
    "C:\MinGW" # MinGW specific install
    "C:\cygwin64" # Cygwin specific install
    "C:\Python" # Common Python install location
    "C:\Ruby" # Common Ruby install location
    "C:\Go" # Common Go install location
    "C:\Rust" # Common Rust install location
) | Select-Object -Unique

# Known binary names or subdirectories to look for within tool search paths
# This list helps the script identify common executable locations for various tools.
$knownToolBinaries = @(
    "bin", "cmd", "sbin", "Scripts", "tools", "cli", "sdk", "runtime",
    "python.exe", "node.exe", "npm.cmd", "git.exe", "docker.exe", "code.cmd",
    "java.exe", "javac.exe", "mvn.cmd", "gradle.cmd", "go.exe", "cargo.exe",
    "ruby.exe", "php.exe", "composer.phar", "mingw32\bin", "wsl.exe",
    "choco.exe", "scoop.cmd", "dotnet.exe", "az.cmd", "aws.exe", "kubectl.exe",
    "terraform.exe", "ansible-playbook.exe", "vagrant.exe", "virtualbox.exe",
    "yarn.cmd", "pnpm.cmd", "nvm.exe", "py.exe", "pip.exe", "conda.exe",
    "flutter\bin", "dart\bin", "android-sdk\platform-tools", "android-sdk\tools\bin"
) | Select-Object -Unique

# --- Helper Functions ---

function Get-CurrentPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Scope # "Machine" or "User"
    )
    try {
        $pathValue = [Environment]::GetEnvironmentVariable("Path", $Scope)
        if ([string]::IsNullOrEmpty($pathValue)) {
            Write-Verbose "No PATH variable found for scope '$Scope'."
            return @()
        }
        # Split by semicolon, filter out empty entries, and trim whitespace
        return @(($pathValue -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }) | Select-Object -Unique)
    }
    catch {
        Write-Error "Failed to retrieve PATH for scope '$Scope': $($_.Exception.Message)"
        return @()
    }
}

function Set-NewPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Scope, # "Machine" or "User" # Added comma here
        [Parameter(Mandatory=$true)]
        [string[]]$NewPathEntries
    )
    $newPathString = ($NewPathEntries | Select-Object -Unique) -join ';'
    
    if ($DryRun) {
        Write-Host "DRY RUN: Would set '$Scope' PATH to:" -ForegroundColor DarkYellow
        $newPathString -split ';' | ForEach-Object { Write-Host "  $_" }
        return $true
    }

    try {
        [Environment]::SetEnvironmentVariable("Path", $newPathString, $Scope)
        Write-Host "SUCCESS: '$Scope' PATH updated successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to update '$Scope' PATH: $($_.Exception.Message)"
        Write-Host "Make sure you're running this script with Administrator privileges if updating System PATH." -ForegroundColor Red
        return $false
    }
}

function Find-AndAddToolPaths {
    [CmdletBinding()]
    param (
        [string[]]$SearchRoots,
        [string[]]$KnownBinaries,
        [int]$MaxDepth,
        [switch]$Thorough,
        [switch]$IgnoreErrors,
        [switch]$ShowTools,
        [switch]$ShowSearchDetails
    )

    $foundPaths = New-Object System.Collections.Generic.HashSet[string]
    $foundTools = New-Object System.Collections.Generic.List[string]

    Write-Host "Searching for common development tool binaries..." -ForegroundColor Yellow
    Write-Verbose "Search Depth: $MaxDepth"
    Write-Verbose "Thorough Search: $Thorough"
    Write-Verbose "Ignore Access Errors: $IgnoreErrors"

    foreach ($root in $SearchRoots) {
        if (-not (Test-Path $root)) {
            Write-Verbose "Skipping non-existent search root: '$root'"
            continue
        }

        Write-Verbose "Searching in root: '$root'"
        $gciParams = @{
            Path = $root
            Directory = $true
            ErrorAction = 'SilentlyContinue'
            Recurse = $true
            Depth = $MaxDepth
        }
        if ($IgnoreErrors) {
            $gciParams.ErrorAction = 'SilentlyContinue'
        } else {
            $gciParams.ErrorAction = 'Continue'
        }

        try {
            $directories = Get-ChildItem @gciParams | Where-Object { $_.PSIsContainer }
            $dirCount = ($directories | Measure-Object).Count
            $i = 0
            foreach ($dir in $directories) {
                $i++
                $status = 'Scanning directory {0} of {1}: {2}' -f $i, $dirCount, $dir.FullName
                Write-Progress -Activity "Searching in $root" -Status $status -PercentComplete (($i / $dirCount) * 100)

                if ($ShowSearchDetails) {
                    $foundBinariesInDir = @()
                    foreach ($binary in $KnownBinaries) {
                        $fullPath = Join-Path $dir.FullName $binary
                        if (Test-Path $fullPath -PathType Leaf -ErrorAction SilentlyContinue) {
                            $foundBinariesInDir += $binary
                        } elseif (Test-Path $fullPath -PathType Container -ErrorAction SilentlyContinue) {
                            $foundBinariesInDir += "$binary (dir)"
                        }
                    }
                    if ($foundBinariesInDir.Count -gt 0) {
                        Write-Host "  Found in $($dir.FullName): $($foundBinariesInDir -join ', ')" -ForegroundColor DarkGreen
                    }
                }

                foreach ($binary in $KnownBinaries) {
                    $fullPath = Join-Path $dir.FullName $binary
                    if (Test-Path $fullPath -PathType Leaf -ErrorAction SilentlyContinue) {
                        # If it's a file, add its parent directory
                        $foundPaths.Add($dir.FullName) | Out-Null
                        $foundTools.Add("$($dir.FullName)\$binary") | Out-Null
                        Write-Verbose "Found tool binary '$binary' in '$dir.FullName'"
                    } elseif (Test-Path $fullPath -PathType Container -ErrorAction SilentlyContinue) {
                        # If it's a directory (like 'bin' or 'Scripts'), add it directly
                        $foundPaths.Add($fullPath) | Out-Null
                        $foundTools.Add($fullPath) | Out-Null
                        Write-Verbose "Found tool directory '$binary' in '$fullPath'" # Corrected here
                    }
                }
            }
        }
        catch {
            Write-Warning "Error searching in '$root': $($_.Exception.Message)"
        }
    }

    Write-Progress -Activity "Searching for Tools" -Completed

    if ($ShowTools) {
        Write-Host "`n--- Found Tools ---" -ForegroundColor Yellow
        if ($foundTools.Count -gt 0) {
            $foundTools | Sort-Object | ForEach-Object { Write-Host "  $_" }
        } else {
            Write-Host "  No additional tools found based on search criteria." -ForegroundColor DarkYellow
        }
        Write-Host "-------------------`n" -ForegroundColor Yellow
    }

    return $foundPaths.ToArray()
}

# --- Main Script Logic ---

Write-Host "`n--- Windows PATH Environment Variable Repair Tool ---" -ForegroundColor Green

# 1. Backup current PATH settings
if (-not $SkipBackup) {
    $configTime = Get-Date -Format "yyyyMMdd-HHmmss"
    $currentSystemPath = Get-CurrentPath -Scope "Machine"
    $currentUserPath = Get-CurrentPath -Scope "User"

    $systemBackupFile = Join-Path -Path $backupDir -ChildPath "SystemPath-Backup-$configTime.txt"
    $userBackupFile = Join-Path -Path $backupDir -ChildPath "UserPath-Backup-$configTime.txt"

    try {
        $currentSystemPath -join ';' | Out-File -FilePath $systemBackupFile -Encoding utf8
        Write-Host "System PATH backed up to: '$systemBackupFile'" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to backup System PATH: $($_.Exception.Message)"
    }

    try {
        $currentUserPath -join ';' | Out-File -FilePath $userBackupFile -Encoding utf8
        Write-Host "User PATH backed up to: '$userBackupFile'" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to backup User PATH: $($_.Exception.Message)"
    }
}

# Get current PATHs for modification
$currentSystemPathEntries = Get-CurrentPath -Scope "Machine"
$currentUserPathEntries = Get-CurrentPath -Scope "User"

# Initialize new PATH lists with essential paths
$newSystemPathEntries = New-Object System.Collections.Generic.HashSet[string]
$newUserPathEntries = New-Object System.Collections.Generic.HashSet[string]

# Add essential system paths
foreach ($path in $essentialSystemPaths) {
    if (Test-Path $path -PathType Container -ErrorAction SilentlyContinue) {
        $newSystemPathEntries.Add($path) | Out-Null
    }
}

# Add essential user paths
foreach ($path in $essentialUserPaths) {
    if (Test-Path $path -PathType Container -ErrorAction SilentlyContinue) {
        $newUserPathEntries.Add($path) | Out-Null
    }
}

# Find and add tool paths
$foundToolPaths = Find-AndAddToolPaths -SearchRoots $toolSearchPaths `
                                     -KnownBinaries $knownToolBinaries `
                                     -MaxDepth $MaxSearchDepth `
                                     -Thorough:$ThoroughSearch.IsPresent `
                                     -IgnoreErrors:$IgnoreAccessErrors.IsPresent `
                                     -ShowTools:$ShowFoundTools.IsPresent `
                                     -ShowSearchDetails:$ShowSearchDetails.IsPresent

# Add found tool paths to both system and user path candidates (let user decide later if needed)
# For simplicity, we'll add them to the user path first, as it's less restrictive.
# System PATH additions should be more carefully considered by an admin.
foreach ($path in $foundToolPaths) {
    # Add to user path candidates
    $newUserPathEntries.Add($path) | Out-Null
    # If it's a common system-wide tool, also add to system path candidates
    if ($path.StartsWith($env:ProgramFiles) -or $path.StartsWith($env:ProgramFilesX86) -or $path.StartsWith("C:\ProgramData\chocolatey")) { # Added Chocolatey ProgramData check
        $newSystemPathEntries.Add($path) | Out-Null
    }
}

# Combine and clean up paths
function Clean-PathEntries {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$PathEntries
    )
    $cleanedPaths = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $invalidPaths = New-Object System.Collections.Generic.List[string]

    foreach ($path in $PathEntries) {
        $path = $path.Trim()
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue # Skip empty entries
        }
        if (Test-Path $path -PathType Container -ErrorAction SilentlyContinue) {
            $cleanedPaths.Add($path) | Out-Null
        } else {
            $invalidPaths.Add($path) | Out-Null
            Write-Verbose "Identified invalid or non-existent path: '$path'"
        }
    }
    
    # Sort for consistent order
    return ($cleanedPaths.ToArray() | Sort-Object), $invalidPaths.ToArray()
}

Write-Host "`n--- Processing System PATH ---" -ForegroundColor Yellow
# Combine old and new paths robustly
$systemPathCandidates = @()
$systemPathCandidates += $currentSystemPathEntries
$systemPathCandidates += $newSystemPathEntries
$systemPathCandidates = $systemPathCandidates | Select-Object -Unique
$cleanedSystemPaths, $removedSystemPaths = Clean-PathEntries -PathEntries $systemPathCandidates

Write-Host "`n--- Processing User PATH ---" -ForegroundColor Yellow
# Combine old and new paths robustly
$userPathCandidates = @()
$userPathCandidates += $currentUserPathEntries
$userPathCandidates += $newUserPathEntries
$userPathCandidates = $userPathCandidates | Select-Object -Unique
$cleanedUserPaths, $removedUserPaths = Clean-PathEntries -PathEntries $userPathCandidates

# --- Display Proposed Changes ---
Write-Host "`n--- Proposed PATH Changes ---" -ForegroundColor Cyan

# System PATH Changes
$systemPathsAdded = ($cleanedSystemPaths | Where-Object { $currentSystemPathEntries -notcontains $_ }) | Sort-Object
$systemPathsRemoved = ($currentSystemPathEntries | Where-Object { $cleanedSystemPaths -notcontains $_ }) | Sort-Object
$systemDuplicatesRemoved = ($systemPathCandidates | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name) | Sort-Object

Write-Host "`nSystem PATH:" -ForegroundColor White
Write-Host "  Paths to be Added: $($systemPathsAdded.Count)" -ForegroundColor Cyan
if ($systemPathsAdded.Count -gt 0) { $systemPathsAdded | ForEach-Object { Write-Host "    + $_" -ForegroundColor Green } }
Write-Host "  Paths to be Removed (Invalid/Duplicates): $($removedSystemPaths.Count + $systemDuplicatesRemoved.Count)" -ForegroundColor Cyan
if ($removedSystemPaths.Count -gt 0) { $removedSystemPaths | ForEach-Object { Write-Host "    - $_ (Invalid)" -ForegroundColor Red } }
if ($systemDuplicatesRemoved.Count -gt 0) { $systemDuplicatesRemoved | ForEach-Object { Write-Host "    - $_ (Duplicate)" -ForegroundColor Red } }


# User PATH Changes
$userPathsAdded = ($cleanedUserPaths | Where-Object { $currentUserPathEntries -notcontains $_ }) | Sort-Object
$userPathsRemoved = ($currentUserPathEntries | Where-Object { $cleanedUserPaths -notcontains $_ }) | Sort-Object
$userDuplicatesRemoved = ($userPathCandidates | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name) | Sort-Object

Write-Host "`nUser PATH:" -ForegroundColor White
Write-Host "  Paths to be Added: $($userPathsAdded.Count)" -ForegroundColor Cyan
if ($userPathsAdded.Count -gt 0) { $userPathsAdded | ForEach-Object { Write-Host "    + $_" -ForegroundColor Green } }
Write-Host "  Paths to be Removed (Invalid/Duplicates): $($removedUserPaths.Count + $userDuplicatesRemoved.Count)" -ForegroundColor Cyan
if ($removedUserPaths.Count -gt 0) { $removedUserPaths | ForEach-Object { Write-Host "    - $_ (Invalid)" -ForegroundColor Red } }
if ($userDuplicatesRemoved.Count -gt 0) { $userDuplicatesRemoved | ForEach-Object { Write-Host "    - $_ (Duplicate)" -ForegroundColor Red } }

# --- Confirmation and Application ---

if ($DryRun) {
    Write-Host "`nDRY RUN completed. No changes were applied." -ForegroundColor DarkYellow
    Write-Host "Review the proposed changes above." -ForegroundColor DarkYellow
    exit 0
}

if (-not $Force) {
    $confirm = Read-Host "`nDo you want to apply these PATH changes? (Y/N)"
    if ($confirm -ne 'Y' -and $confirm -ne 'y') {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
        exit 0
    }
}

# Apply changes to System PATH
if (-not $UserPathOnly) {
    if (Set-NewPath -Scope "Machine" -NewPathEntries $cleanedSystemPaths) {
        # Save the final System PATH configuration for reference
        $configTime = Get-Date -Format "yyyyMMdd-HHmmss"
        $systemConfigFile = Join-Path -Path $backupDir -ChildPath "SystemPath-Config-$configTime.txt"
        try {
            $cleanedSystemPaths -join ';' | Out-File -FilePath $systemConfigFile -Encoding utf8
            Write-Host "Final System PATH configuration saved to: '$systemConfigFile'" -ForegroundColor Cyan
        }
        catch {
            Write-Error "Failed to save final System PATH configuration: $($_.Exception.Message)"
        }
    }
}

# Apply changes to User PATH
if (-not $SystemPathOnly) {
    if (Set-NewPath -Scope "User" -NewPathEntries $cleanedUserPaths) {
        # Save the final User PATH configuration for reference
        $configTime = Get-Date -Format "yyyyMMdd-HHmmss"
        $userConfigFile = Join-Path -Path $backupDir -ChildPath "UserPath-Config-$configTime.txt"
        try {
            $cleanedUserPaths -join ';' | Out-File -FilePath $userConfigFile -Encoding utf8
            Write-Host "Final User PATH configuration saved to: '$userConfigFile'" -ForegroundColor Cyan
        }
        catch {
            Write-Error "Failed to save final User PATH configuration: $($_.Exception.Message)"
        }
    }
}

Write-Host "`nIMPORTANT: Please restart your terminal or command prompt to use the updated PATH." -ForegroundColor Yellow
Write-Host "To verify the changes, open a NEW terminal and type: 'Get-ChildItem Env:Path'" -ForegroundColor Yellow
Write-Host "`n--- Operation Complete ---" -ForegroundColor Green
