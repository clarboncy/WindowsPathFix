<#
.SYNOPSIS
    Windows PATH Environment Variable Repair Tool (2025 Edition)

.DESCRIPTION
    Comprehensive repair tool for Windows PATH environment variables by:
    1. Backing up current PATH settings
    2. Adding essential Windows system directories
    3. Finding and including directories for development tools
    4. Removing duplicates and invalid paths
    5. Properly setting both System and User PATH variables
    
    This tool includes a complete list of possible PATH directories
    as of April 2025 for Windows 11.

.NOTES
    Author: Clarboncy
    Version: 1.0
    Date: 2025-04-08
    Requirements: Windows 10/11, PowerShell 5.1 or later
    Run with Administrator privileges to update System PATH
#>

[CmdletBinding()]
param (
    [switch]$Force,             # Skip confirmation prompts
    [switch]$SkipBackup,        # Skip backup of current PATH
    [switch]$SystemPathOnly,    # Only fix System PATH (not User PATH)
    [switch]$UserPathOnly,      # Only fix User PATH (not System PATH)
    [switch]$ShowFoundTools,    # Show list of all found tools
    [int]$MaxSearchDepth = 4,   # Max folder depth to search
    [switch]$IgnoreAccessErrors,# Ignore access denied errors
    [switch]$ThoroughSearch     # More thorough but slower search
)

# Create backup directory
$backupDir = "$env:USERPROFILE\PathBackups"
if (-not (Test-Path -Path $backupDir)) {
    New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    Write-Host "Created backup directory: $backupDir" -ForegroundColor Green
}

# Get current PATH variables
$currentSystemPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")

# Backup current paths
if (-not $SkipBackup) {
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $systemPathBackupFile = Join-Path -Path $backupDir -ChildPath "SystemPath_$timestamp.txt"
    $userPathBackupFile = Join-Path -Path $backupDir -ChildPath "UserPath_$timestamp.txt"
    
    $currentSystemPath | Out-File -FilePath $systemPathBackupFile -Encoding UTF8 -Force
    $currentUserPath | Out-File -FilePath $userPathBackupFile -Encoding UTF8 -Force
    
    Write-Host "PATH variables backed up:" -ForegroundColor Green
    Write-Host "  System PATH: $systemPathBackupFile" -ForegroundColor Green
    Write-Host "  User PATH: $userPathBackupFile" -ForegroundColor Green
}

# Create a variable to help with detailed output
$VerboseOutput = $VerbosePreference -eq 'Continue'

# Define essential PATH directories

# 1. Critical system directories – must always be present on Windows
$criticalSystemDirs = @(
    "$env:SystemRoot\System32",                          # Core system binaries
    "$env:SystemRoot",                                   # Windows root (e.g. explorer.exe)
    "$env:SystemRoot\System32\Wbem",                     # WMI (Windows Management Instrumentation)
    "$env:SystemRoot\System32\WindowsPowerShell\v1.0",   # Windows PowerShell (default)
    "$env:SystemRoot\SysWOW64\WindowsPowerShell\v1.0",   # 32-bit PowerShell (on 64-bit systems)
    "$env:SystemRoot\System32\OpenSSH"                   # OpenSSH (if installed)
)

# 2. Common system directories – often added by Microsoft products and essential frameworks
$commonSystemDirs = @(
    "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319",   # .NET Framework (64-bit)
    "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319",     # .NET Framework (32-bit)
    "$env:ProgramFiles\Microsoft\Azure CLI",                # Azure CLI (default installation)
    "$env:ProgramFiles\PowerShell\7",                       # PowerShell 7+
    "$env:ProgramFiles\dotnet",                             # .NET Core SDK & Runtime
    # Add Chocolatey bin (commonly installed to ProgramData)
    "$env:ProgramData\chocolatey\bin"
)

# 3. Application directories – include language runtimes, development tool executables, editors, and database tools
$applicationDirs = @(
    # Programming languages and runtimes:
    "$env:ProgramFiles\Python*",                           # Python installations (64-bit)
    "$env:ProgramFiles\Python*\Scripts",                   # Python scripts (64-bit)
    "${env:ProgramFiles(x86)}\Python*",                    # Python installations (32-bit)
    "${env:ProgramFiles(x86)}\Python*\Scripts",            # Python scripts (32-bit)
    "$env:ProgramFiles\Ruby*\bin",                         # Ruby executables
    "$env:ProgramFiles\PHP*",                              # PHP
    "$env:ProgramFiles\Rust\bin",                          # Rust toolchain (rustc, cargo)
    "$env:ProgramFiles\Perl*\bin",                         # Perl
    "$env:ProgramFiles\nodejs",                            # Node.js core executables
    "$env:ProgramFiles\nodejs\node_modules\npm\bin",        # NPM CLI tools
    "$env:ProgramFiles\Go\bin",                            # Go language
    # Editors/IDEs:
    "$env:ProgramFiles\Microsoft VS Code\bin",             # Visual Studio Code (system install)
    "$env:ProgramFiles\JetBrains\*\bin",                   # JetBrains IDEs (varies by product)
    # Database and related tools:
    "$env:ProgramFiles\PostgreSQL\*\bin",                  # PostgreSQL
    "$env:ProgramFiles\MySQL\MySQL*\bin",                  # MySQL
    "$env:ProgramFiles\MongoDB\Server\*\bin",              # MongoDB
    "$env:ProgramFiles\Redis\*",                           # Redis (if installed)
    # Utility and archiving tools:
    "$env:ProgramFiles\cURL\bin",                          # cURL
    "$env:ProgramFiles\7-Zip",                             # 7-Zip (CLI executable typically in this folder)
    "$env:ProgramFiles\Git\cmd",                           # Git CLI commands
    "$env:ProgramFiles\Git\mingw64\bin",                   # Git's MinGW tools
    "$env:ProgramFiles\Git\usr\bin",                       # Git's Unix tools
    # Virtualization, container, and infrastructure tools:
    "$env:ProgramFiles\Oracle\VirtualBox",                 # VirtualBox
    "$env:ProgramFiles\VMware\*\bin",                      # VMware tools (if installed)
    "$env:ProgramFiles\HashiCorp\Vagrant\bin",             # Vagrant
    "$env:ProgramFiles\terraform",                         # Terraform (if installed)
    "$env:ProgramFiles\kubernetes\*\bin",                  # Kubernetes CLI tools (if installed)
    # Additional Git LFS folder, if installed:
    "$env:ProgramFiles\Git LFS"
)

# 4. Java directories – accounts for multiple vendors and installation types
$javaDirs = @(
    "$env:ProgramFiles\Java\jdk*\bin",                # Oracle JDK (64-bit)
    "$env:ProgramFiles\Java\jre*\bin",                # Oracle JRE (64-bit)
    "${env:ProgramFiles(x86)}\Java\jdk*\bin",         # Oracle JDK (32-bit)
    "${env:ProgramFiles(x86)}\Java\jre*\bin",         # Oracle JRE (32-bit)
    "$env:ProgramFiles\AdoptOpenJDK\*\bin",           # AdoptOpenJDK/Adoptium (64-bit)
    "$env:ProgramFiles\Eclipse Adoptium\*\bin",       # Eclipse Adoptium/Temurin
    "$env:ProgramFiles\OpenJDK\*\bin",                # OpenJDK (if installed)
    "$env:ProgramFiles\Amazon Corretto\*\bin",        # Amazon Corretto
    "$env:ProgramFiles\Microsoft\jdk-*\bin",          # Microsoft OpenJDK
    # Common Oracle javapath locations:
    "$env:ProgramData\Oracle\Java\javapath",          # Oracle-provided symlink path
    "$env:ProgramFiles\Common Files\Oracle\Java\javapath",
    "$env:JAVA_HOME\bin"                              # Fallback if JAVA_HOME is set
)

# 5. User-specific directories – for user-level tool installations, shims, and global packages
$userSpecificDirs = @(
    "$env:USERPROFILE\.dotnet\tools",                # .NET Core global tools installed via dotnet tool install
    "$env:USERPROFILE\AppData\Roaming\npm",          # Global NPM packages (scripts)
    "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps",  # Windows Store apps
    "$env:USERPROFILE\.cargo\bin",                   # Rust (Cargo) binaries
    "$env:USERPROFILE\go\bin",                       # Go user-installed packages
    "$env:USERPROFILE\.deno\bin",                    # Deno (if installed)
    "$env:USERPROFILE\AppData\Local\Yarn\bin",       # Yarn global binaries
    "$env:USERPROFILE\AppData\Local\Programs\Python\Python*\Scripts", # Python user install scripts
    "$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code\bin", # VS Code user install
    # Scoop package manager shims (if using Scoop):
    "$env:USERPROFILE\scoop\shims"
)

# Function to check if a directory exists and expand wildcards if needed
Function Get-ExistingDirectories {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$DirectoryPatterns
    )
    
    $existingDirs = @()
    
    foreach ($pattern in $DirectoryPatterns) {
        # If the pattern has a wildcard character
        if ($pattern -match '\*') {
            # Resolve the parent path before the wildcard
            $parentPath = Split-Path -Path $pattern -Parent
            $childPattern = Split-Path -Path $pattern -Leaf
            
            if (Test-Path -Path $parentPath -PathType Container) {
                try {
                    # Find all matching child directories
                    $matchingDirs = Get-ChildItem -Path $parentPath -Directory -ErrorAction SilentlyContinue | 
                                    Where-Object { $_.Name -like $childPattern } |
                                    ForEach-Object { $_.FullName }
                    
                    if ($matchingDirs) {
                        $existingDirs += $matchingDirs
                        if ($VerboseOutput) {
                            Write-Host "  Found matching directories for $pattern" -ForegroundColor Green
                            $matchingDirs | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
                        }
                    }
                }
                catch {
                    # Print error only if verbose and not ignoring access errors
                    if ($VerboseOutput -and -not $IgnoreAccessErrors) {
                        $errorMessage = $_.Exception.Message
                        Write-Host "  Error processing pattern $pattern" -ForegroundColor Red
                        Write-Host "  $errorMessage" -ForegroundColor Red
                    }
                }
            }
        }
        # If it's a direct path without wildcards
        else {
            if (Test-Path -Path $pattern -PathType Container) {
                $existingDirs += $pattern
                if ($VerboseOutput) {
                    Write-Host "  Found directory: $pattern" -ForegroundColor Green
                }
            }
        }
    }
    
    return $existingDirs
}

# Function to search for tools and get their directory locations
Function Find-ExecutableTools {
    param (
        [switch]$ThoroughSearch,
        [int]$MaxDepth = 3,
        [switch]$IgnoreAccessErrors
    )
    
    $toolLocations = @{}
    $searchRoots = @(
        "$env:ProgramFiles",
        "${env:ProgramFiles(x86)}",
        "$env:ProgramData",
        "$env:SystemDrive\"
    )
    
    $executablesToFind = @(
        # Containerization & Orchestration Tools
        "docker.exe", "kubectl.exe", "minikube.exe", "kind.exe", "skaffold.exe",
        "helm.exe", "istioctl.exe",
    
        # Infrastructure as Code & Provisioning
        "terraform.exe", "ansible.exe", "vagrant.exe",
    
        # Static Site & Documentation Tools
        "composer.bat", "hugo.exe",
    
        # Cloud CLI Tools
        "aws.exe", "az.cmd", "gcloud.cmd", "ibmcloud.exe", "cf.exe", "heroku.exe",
    
        # Build Tools & Package Managers
        "mvn.cmd", "gradle.bat", "npm.cmd", "yarn.cmd", "tsc.cmd", "dotnet.exe",
        "msbuild.exe", "devenv.exe", "vstest.console.exe", "nuget.exe",
        "scoop.exe", "winget.exe", "choco.exe",
    
        # Language Runtimes/Compilers/Interpreters
        "java.exe", "javac.exe", "python.exe", "pip.exe", "ruby.exe", "perl.exe",
        "php.exe", "node.exe", "flutter.bat", "dart.exe", "go.exe",
        "rustc.exe", "cargo.exe", "gcc.exe", "clang.exe", "scala.exe", "kotlinc.exe",
    
        # C/C++ Build Systems & Compilers (from MSVC)
        "cmake.exe", "make.exe", "nmake.exe", "cl.exe",
    
        # Version Control Utilities
        "git.exe", "svn.exe", "hg.exe",
    
        # Database & CLI Utilities
        "mongo.exe", "psql.exe", "mysql.exe", "sqlite3.exe", "redis-cli.exe",
    
        # Shell & Terminal Utilities
        "powershell.exe", "pwsh.exe", "adb.exe",
    
        # Additional System/Utility Tools
        "7z.exe", "curl.exe", "wget.exe", "vswhere.exe"
    )

    
    foreach ($root in $searchRoots) {
        if ($VerboseOutput) {
            Write-Host "Searching for tools in $root..." -ForegroundColor Yellow
        }
        
        foreach ($exeName in $executablesToFind) {
            $searchParams = @{
                Path = $root
                Filter = $exeName
                File = $true
                Recurse = $true
                ErrorAction = "SilentlyContinue"
            }
            
            # Limit depth for performance reasons unless thorough search is requested
            if (-not $ThoroughSearch) {
                $searchParams.Depth = $MaxDepth
            }
            
            try {
                $foundFiles = Get-ChildItem @searchParams
                
                foreach ($file in $foundFiles) {
                    $dir = Split-Path -Path $file.FullName -Parent
                    $name = $file.Name -replace '\.exe|\.cmd|\.bat$', ''
                    
                    if (-not $toolLocations.ContainsKey($name)) {
                        $toolLocations[$name] = $dir
                        
                        if ($VerboseOutput) {
                            Write-Host "  Found $name at: $dir" -ForegroundColor Green
                        }
                    }
                }
            }
            catch {
                if ($VerboseOutput -and -not $IgnoreAccessErrors) {
                    $errorMessage = $_.Exception.Message
                    # Print error message separately to avoid interpolation issues
                    Write-Host "  Error encountered: " -NoNewline -ForegroundColor Red
                    Write-Host $errorMessage -ForegroundColor Red
                }
            }
        }
    }
    
    return $toolLocations
}

# Function to build a clean PATH string from a list of directories
Function Build-CleanPath {
    param (
        [string[]]$Directories
    )
    
    # Remove duplicates while preserving order
    $uniqueDirs = @()
    $seen = @{}
    
    foreach ($dir in $Directories) {
        # Skip empty entries
        if ([string]::IsNullOrWhiteSpace($dir)) { continue }
        
        # Normalize path (remove trailing backslash)
        $normalizedDir = $dir.TrimEnd('\')
        
        # Only add if we haven't seen it before and it exists
        if (-not $seen.ContainsKey($normalizedDir) -and (Test-Path -Path $normalizedDir -PathType Container)) {
            $uniqueDirs += $normalizedDir
            $seen[$normalizedDir] = $true
        }
    }
    
    # Join with semicolons to form a valid PATH string
    return ($uniqueDirs -join ';')
}

# Parse current PATH variables
$currentSystemPathDirs = @()
if ($currentSystemPath) {
    $currentSystemPathDirs = $currentSystemPath -split ';' | Where-Object { $_ -ne '' }
}

$currentUserPathDirs = @()
if ($currentUserPath) {
    $currentUserPathDirs = $currentUserPath -split ';' | Where-Object { $_ -ne '' }
}

# Filter out invalid directories
$validSystemPathDirs = $currentSystemPathDirs | Where-Object { Test-Path -Path $_ -PathType Container }
$validUserPathDirs = $currentUserPathDirs | Where-Object { Test-Path -Path $_ -PathType Container }

Write-Host "Current PATH status:" -ForegroundColor Cyan
Write-Host "  System PATH: $($validSystemPathDirs.Count) valid of $($currentSystemPathDirs.Count) entries" -ForegroundColor White
Write-Host "  User PATH: $($validUserPathDirs.Count) valid of $($currentUserPathDirs.Count) entries" -ForegroundColor White

#-------------------------------------------------
# DISCOVER ESSENTIAL DIRECTORIES 
#-------------------------------------------------

# Get critical system directories that actually exist (these always have highest priority)
Write-Host "Discovering critical system directories..." -ForegroundColor Cyan
$existingCriticalDirs = Get-ExistingDirectories -DirectoryPatterns $criticalSystemDirs
Write-Host "Found $($existingCriticalDirs.Count) critical system directories" -ForegroundColor Green

# Get common system directories that exist
Write-Host "Discovering common system directories..." -ForegroundColor Cyan
$existingCommonDirs = Get-ExistingDirectories -DirectoryPatterns $commonSystemDirs
Write-Host "Found $($existingCommonDirs.Count) common system directories" -ForegroundColor Green

# Get application directories that exist
Write-Host "Discovering application directories..." -ForegroundColor Cyan
$existingAppDirs = Get-ExistingDirectories -DirectoryPatterns $applicationDirs
Write-Host "Found $($existingAppDirs.Count) application directories" -ForegroundColor Green

# Get Java directories that exist
Write-Host "Discovering Java directories..." -ForegroundColor Cyan
$existingJavaDirs = Get-ExistingDirectories -DirectoryPatterns $javaDirs
Write-Host "Found $($existingJavaDirs.Count) Java directories" -ForegroundColor Green

# Get user-specific directories that exist
Write-Host "Discovering user-specific tool directories..." -ForegroundColor Cyan
$existingUserDirs = Get-ExistingDirectories -DirectoryPatterns $userSpecificDirs
Write-Host "Found $($existingUserDirs.Count) user tool directories" -ForegroundColor Green

# Search for executable tools and their directories
Write-Host "Searching for development tools..." -ForegroundColor Cyan
$toolDirectories = Find-ExecutableTools -ThoroughSearch:$ThoroughSearch -MaxDepth $MaxSearchDepth -IgnoreAccessErrors:$IgnoreAccessErrors
Write-Host "Found $($toolDirectories.Count) additional tool directories" -ForegroundColor Green

# Extract just the directories from the tools dictionary
$additionalDirs = $toolDirectories.Values | Select-Object -Unique

# Display found tools if requested
if ($ShowFoundTools) {
    Write-Host "`nDevelopment tools found:" -ForegroundColor Yellow
    $toolDirectories.GetEnumerator() | Sort-Object -Property Key | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor White
    }
}

#-------------------------------------------------
# BUILD OPTIMIZED PATH VARIABLES
#-------------------------------------------------

# Build the System PATH
Write-Host "Building optimized System PATH..." -ForegroundColor Cyan

# Start with existing critical directories and common directories
$newSystemPathDirs = @()
$newSystemPathDirs += $existingCriticalDirs     # Critical system directories first
$newSystemPathDirs += $validSystemPathDirs      # Add existing valid system directories
$newSystemPathDirs += $existingCommonDirs       # Add common system directories
$newSystemPathDirs += $existingAppDirs          # Then application directories

# Add Java directories that are not in the user profile
$newSystemPathDirs += $existingJavaDirs | Where-Object { $_ -notlike "$env:USERPROFILE*" }

# Add discovered tool directories that should be system-wide (not in user profile)
$newSystemPathDirs += $additionalDirs | Where-Object { $_ -notlike "$env:USERPROFILE*" }

# Build the User PATH
Write-Host "Building optimized User PATH..." -ForegroundColor Cyan

# Start with user tool directories
$newUserPathDirs = @()
$newUserPathDirs += $existingUserDirs
$newUserPathDirs += $validUserPathDirs        # Add existing valid user directories

# Add Java directories that are in the user profile
$newUserPathDirs += $existingJavaDirs | Where-Object { $_ -like "$env:USERPROFILE*" }

# Add discovered tool directories that are in the user profile
$newUserPathDirs += $additionalDirs | Where-Object { $_ -like "$env:USERPROFILE*" }

# Clean up paths by removing duplicates and invalid entries
$newSystemPath = Build-CleanPath -Directories $newSystemPathDirs
$newUserPath = Build-CleanPath -Directories $newUserPathDirs

# Show summary
Write-Host "`nPATH Repair Summary:" -ForegroundColor Yellow
Write-Host "  Original System PATH entries: $($currentSystemPathDirs.Count)" -ForegroundColor White
Write-Host "  Original User PATH entries: $($currentUserPathDirs.Count)" -ForegroundColor White
Write-Host "  New System PATH entries: $(($newSystemPath -split ';').Count)" -ForegroundColor Green
Write-Host "  New User PATH entries: $(($newUserPath -split ';').Count)" -ForegroundColor Green

# Prompt for confirmation unless Force is specified
if (-not $Force) {
    Write-Host "`nReady to update PATH variables. This requires administrator privileges for the System PATH." -ForegroundColor Yellow
    $confirmation = Read-Host "Do you want to continue? (Y/N)"
    if ($confirmation -ne "Y" -and $confirmation -ne "y") {
        Write-Host "Operation cancelled by user. No changes were made." -ForegroundColor Red
        exit
    }
}

# Apply the changes based on user options
if (-not $UserPathOnly) {
    try {
        [Environment]::SetEnvironmentVariable("Path", $newSystemPath, "Machine")
        Write-Host "System PATH updated successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to update System PATH: $_" -ForegroundColor Red
        Write-Host "Make sure you're running this script with Administrator privileges." -ForegroundColor Red
    }
}

if (-not $SystemPathOnly) {
    try {
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
        Write-Host "User PATH updated successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to update User PATH: $_" -ForegroundColor Red
    }
}

# Save the final PATH configuration for reference
$configTime = Get-Date -Format "yyyyMMdd-HHmmss"
$systemConfigFile = Join-Path -Path $backupDir -ChildPath "SystemPath-Config-$configTime.txt"
$userConfigFile = Join-Path -Path $backupDir -ChildPath "UserPath-Config-$configTime.txt"

$newSystemPath -split ';' | Out-File -FilePath $systemConfigFile -Encoding utf8
$newUserPath -split ';' | Out-File -FilePath $userConfigFile -Encoding utf8

Write-Host "`nPATH configuration saved to: '$backupDir'" -ForegroundColor Cyan
Write-Host "`nIMPORTANT: Please restart your terminal or command prompt to use the updated PATH." -ForegroundColor Yellow
Write-Host "To verify the changes, open a new PowerShell window and run: `$env:Path -split ';'" -ForegroundColor Yellow
