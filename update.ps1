<#
.SYNOPSIS
    This script updates a comprehensive set of development tools and packages on a Windows system.
    It provides command-line switches to skip specific update sections.

.DESCRIPTION
    The script automates the process of updating:
    - PowerShell Modules
    - Scoop packages
    - Winget packages (using the 'winget upgrade --all' command)
    - Visual Studio Code extensions
    - Miniconda (base and 'ocr-azure' environments)
    - TeX Live
    - WSL (Windows Subsystem for Linux)

    The script is designed to be flexible. You can skip any section by providing its corresponding
    '--No<Section>' parameter when you run the script. Failed operations are automatically retried
    up to 2 times before being marked as failed.

.PARAMETER Help
    A switch to display this detailed help message and exit. Aliases: -h, -?

.PARAMETER NoPowerShell
    A switch to skip updating PowerShell Modules.

.PARAMETER NoScoop
    A switch to skip updating Scoop and its packages.

.PARAMETER NoWinget
    A switch to skip updating Winget and Microsoft Store apps.

.PARAMETER NoVsCode
    A switch to skip updating Visual Studio Code extensions.

.PARAMETER NoConda
    A switch to skip updating Miniconda and its environments.

.PARAMETER NoTex
    A switch to skip updating TeX Live.

.PARAMETER NoWsl
    A switch to skip updating the Windows Subsystem for Linux (WSL).

.PARAMETER NoNpm
    A switch to skip updating npm packages.

.PARAMETER OnlyWsl
    A switch to only update WSL and skip other sections.

.PARAMETER OnlyWslPackages
    A switch to only update WSL packages (apt-get) and skip other sections including WSL kernel.

.PARAMETER EnableVerbose
    A switch to enable verbose output.

.PARAMETER LogFile
    Path to the log file. Default is 'update.log'.

.EXAMPLE
    .\update.ps1

    Runs all update tasks.

.EXAMPLE
    .\update.ps1 -NoTex -NoConda

    Runs all update tasks EXCEPT for TeX Live and Miniconda/Conda.

.EXAMPLE
    .\update.ps1 -h

    Displays this help message without running any updates.

.EXAMPLE
    Get-Help .\update.ps1 -Full

    Displays this help message using the built-in PowerShell help system.

.EXAMPLE
    .\update.ps1 -EnableVerbose -LogFile "myupdate.log"

    Runs updates with verbose output and logs to 'myupdate.log'.

.EXAMPLE
    .\update.ps1 -OnlyWslPackages

    Updates only the WSL packages (apt-get), skipping WSL kernel and other sections.

.NOTES
    Author: Your Name
    Date: 2025-01-20
    Version: 9.7 (Cleanup: hashtable refactor, retry style, return→exit; Add: winget source update, scoop cleanup, npm self-update, log rotation, structured logging; Bug: npm exit code + JSON parsing)
#>

param(
    [Parameter(HelpMessage = "Display this help message.")]
    [Alias('h', '?')]
    [switch]$Help,

    [switch]$NoPowerShell,
    [switch]$NoScoop,
    [switch]$NoWinget,
    [switch]$NoVsCode,
    [switch]$NoConda,
    [switch]$NoTex,
    [switch]$NoWsl,
    [switch]$NoNpm,
    [switch]$OnlyWsl,
    [switch]$OnlyWslPackages,

    [Parameter(HelpMessage = "Enable verbose output.")]
    [switch]$EnableVerbose,

    [Parameter(HelpMessage = "Path to log file.")]
    [string]$LogFile = "update.log"
)

# Function to display a formatted section header
function Write-SectionHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Title
    )
    $width = 60
    $padding = $width - $Title.Length - 4
    if ($padding -lt 2) { $padding = 2 }
    $leftPad = [math]::Floor($padding / 2)
    $rightPad = [math]::Ceiling($padding / 2)

    Write-Host ""
    Write-Host ("+" + ("-" * ($width - 2)) + "+") -ForegroundColor DarkCyan
    Write-Host ("|" + (" " * $leftPad) + $Title + (" " * $rightPad) + "|") -ForegroundColor Cyan
    Write-Host ("+" + ("-" * ($width - 2)) + "+") -ForegroundColor DarkCyan
    Write-Host ""
}

# Function to display a status message with a consistent prefix
function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error", "Skip", "Action")]
        [string]$Type = "Info"
    )
    switch ($Type) {
        "Info"    { Write-Host "  [.]  $Message" -ForegroundColor Gray }
        "Success" { Write-Host "  [+]  $Message" -ForegroundColor Green }
        "Warning" { Write-Host "  [!]  $Message" -ForegroundColor Yellow }
        "Error"   { Write-Host "  [X]  $Message" -ForegroundColor Red }
        "Skip"    { Write-Host "  [-]  $Message" -ForegroundColor DarkGray }
        "Action"  { Write-Host "  [>]  $Message" -ForegroundColor White }
    }
}

# Function to write log messages
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    if ($EnableVerbose -or $Level -ne "INFO") {
        Write-Host $logMessage
    }
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logMessage
    }
}

# Function to handle common update section logic
function Update-Section {
    param(
        [string]$SectionName,
        [bool]$SkipCondition,
        [scriptblock]$ToolCheck,
        [scriptblock]$UpdateAction
    )

    if ($SkipCondition) {
        Write-Status "Skipping $SectionName" -Type Skip
        Write-Log "Skipping $SectionName updates."
        $script:skippedSections += $SectionName
        return
    }

    Write-SectionHeader "Updating $SectionName"
    Write-Log "Starting $SectionName updates."

    if (-not (& $ToolCheck)) {
        Write-Status "$SectionName not found on this system" -Type Skip
        Write-Log "$SectionName not found."
        $script:skippedSections += "$SectionName (not installed)"
        return
    }

    $sectionStart = Get-Date
    try {
        & $UpdateAction
        $elapsed = (Get-Date) - $sectionStart
        Write-Status "$SectionName completed in $($elapsed.ToString('hh\:mm\:ss'))" -Type Success
        Write-Log "$SectionName updates completed."
    } catch {
        $elapsed = (Get-Date) - $sectionStart
        Write-Status "$SectionName failed after $($elapsed.ToString('hh\:mm\:ss')): $_" -Type Error
        Write-Log "Error during $SectionName updates: $_" -Level "ERROR"
    }
}

# Function to execute a command with retry logic
function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,
        [Parameter(Mandatory = $true)]
        [string]$ActionName,
        [int]$MaxRetries = 2,
        [int]$DelaySeconds = 5
    )
    $attempt = 0
    $maxAttempts = $MaxRetries + 1
    do {
        $attempt++
        Write-Log "Executing $ActionName (attempt $attempt of $maxAttempts)" -Level "DEBUG"
        try {
            & $Action
            if ($LASTEXITCODE -eq 0) {
                Write-Log "$ActionName succeeded." -Level "INFO"
                return $true
            } else {
                Write-Log "$ActionName failed with exit code $LASTEXITCODE (attempt $attempt)" -Level "WARN"
            }
        } catch {
            Write-Log "$ActionName threw exception (attempt $attempt): $_" -Level "WARN"
        }
        if ($attempt -lt $maxAttempts) {
            Write-Status "Retrying $ActionName (attempt $($attempt + 1) of $maxAttempts)..." -Type Warning
            Start-Sleep -Seconds $DelaySeconds
        }
    } while ($attempt -lt $maxAttempts)
    Write-Log "$ActionName failed after $maxAttempts attempts." -Level "ERROR"
    return $false
}

# Initialize logging and display startup banner
$scriptStartTime = Get-Date
Write-Host ""
Write-Host "  Windows Update Script v9.7" -ForegroundColor Cyan
Write-Host "  Started: $($scriptStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor DarkGray
Write-Host ""

# PowerShell version check (5.0+ required for Get-InstalledModule, Update-Module, etc.)
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "  [X]  PowerShell 5.0+ required (found $($PSVersionTable.PSVersion))" -ForegroundColor Red
    exit 1
}

# Disk space warning
$freeGB = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
if ($freeGB -lt 2) {
    Write-Status "Low disk space: ${freeGB} GB free on C: — updates may fail" -Type Warning
}

Write-Log "Starting update script."
Write-Log "OS: $([System.Environment]::OSVersion.VersionString)"
Write-Log "PowerShell: $($PSVersionTable.PSVersion)"
Write-Log "User: $([System.Environment]::UserName)"
Write-Log "Free disk (C:): ${freeGB} GB"
if ($PSBoundParameters.Count -gt 0) {
    Write-Log "Parameters: $($PSBoundParameters.Keys -join ', ')"
}

# Set error action preference for consistent error handling
$ErrorActionPreference = 'Continue'

# --- Administrator Elevation Check ---
# If Winget or WSL updates are planned, the script needs to run as an administrator.
# This block checks for the necessary permissions and re-launches the script with elevation if required.
if (-not $NoWinget -or -not $NoWsl -or $OnlyWsl -or $OnlyWslPackages) {
    $myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID)
    $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

    if (-not $myWindowsPrincipal.IsInRole($adminRole)) {
        # Build argument array from bound parameters
        $argArray = @()
        foreach ($key in $PSBoundParameters.Keys) {
            if ($PSBoundParameters[$key] -is [switch]) {
                if ($PSBoundParameters[$key]) {
                    $argArray += "-$key"
                }
            } else {
                $argArray += "-$key"
                $argArray += $PSBoundParameters[$key]
            }
        }

        # Not running as admin, so attempt to re-launch with elevation.
        # Use the current PowerShell executable (pwsh.exe for PS7, powershell.exe for PS5)
        # so the elevated process runs the same version.
        $psExe = (Get-Process -Id $PID).MainModule.FileName
        $sudoExists = Get-Command sudo -ErrorAction SilentlyContinue
        if ($sudoExists) {
            # Use the new Windows 'sudo' to re-launch.
            Write-Host "Administrator privileges are required. Re-launching with 'sudo'..." -ForegroundColor Yellow
            & sudo $psExe -ExecutionPolicy Bypass -File $MyInvocation.MyCommand.Definition @argArray
            exit
        } else {
            # Fallback to the traditional self-elevation method.
            Write-Host "Administrator privileges are required. Re-launching as administrator..." -ForegroundColor Yellow
            $argStr = if ($argArray.Count -gt 0) { $argArray -join ' ' } else { '' }
            $newProcess = New-Object System.Diagnostics.ProcessStartInfo $psExe
            $newProcess.Arguments = "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`" $argStr"
            $newProcess.Verb = "runas"
            [System.Diagnostics.Process]::Start($newProcess)
            exit
        }
    }
}

# Security: Require script to be run from the directory where it's located
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
# Resolve log file to absolute path now that $ScriptPath is known
if (-not $PSBoundParameters.ContainsKey('LogFile')) {
    $LogFile = Join-Path $ScriptPath "update.log"
}

# Log rotation: rename existing log with timestamp, keep last 5 archives
if (Test-Path $LogFile) {
    $stamp       = $scriptStartTime.ToString('yyyy-MM-dd_HHmmss')
    $logBase     = [System.IO.Path]::GetFileNameWithoutExtension($LogFile)
    $logDir      = Split-Path $LogFile -Parent
    $archivePath = Join-Path $logDir "$logBase-$stamp.log"
    Rename-Item -Path $LogFile -NewName $archivePath -ErrorAction SilentlyContinue
    Get-ChildItem -Path $logDir -Filter "$logBase-*.log" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 5 |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
if ((Get-Location).Path -ne $ScriptPath) {
    Write-Warning "Script should be run from its directory: $ScriptPath"
    Write-Host "Changing to script directory..." -ForegroundColor Yellow
    Set-Location $ScriptPath
}

# If -Help, -h, or -? is used, show the help for this script and exit.
if ($Help) {
    # Use the built-in Get-Help command to display the comment-based help block from the top of this script.
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}


# Initialize hashtables to store results for the final summary
$sectionKeys = "PowerShell Modules", "Scoop", "Winget", "VS Code Extensions", "Conda", "TeX Live", "WSL", "npm"
$updatedItems = @{}
$failedItems  = @{}
foreach ($k in $sectionKeys) {
    $updatedItems[$k] = @()
    $failedItems[$k]  = @()
}
$skippedSections = @()

# --- Update PowerShell Modules ---
Update-Section "PowerShell Modules" ($NoPowerShell -or $OnlyWsl -or $OnlyWslPackages) { $true } {
    Write-Status "Retrieving installed modules..." -Type Action
    Write-Log "Retrieving installed modules."
    $installedModules = Get-InstalledModule
    Write-Status "Found $($installedModules.Count) modules to check" -Type Info
    $progress = 0
    foreach ($module in $installedModules) {
        Write-Progress -Activity "Updating PowerShell Modules" -Status "Updating $($module.Name)" -PercentComplete (($progress / $installedModules.Count) * 100)
        try {
            Write-Log "Updating module: $($module.Name)"
            Update-Module -Name $module.Name -Force -ErrorAction Stop
            $updatedItems["PowerShell Modules"] += $module.Name
            Write-Log "Successfully updated module: $($module.Name)"
        } catch {
            Write-Status "Failed: $($module.Name) - $_" -Type Error
            Write-Log "Failed to update module: $($module.Name). Error: $_" -Level "ERROR"
            $failedItems["PowerShell Modules"] += "$($module.Name) - $($_.Exception.Message)"
        }
        $progress++
    }
    Write-Progress -Activity "Updating PowerShell Modules" -Completed
}

# --- Update Scoop ---
Update-Section "Scoop and its packages" ($NoScoop -or $OnlyWsl -or $OnlyWslPackages) { Get-Command scoop -ErrorAction SilentlyContinue } {
    Write-Status "Checking for outdated packages..." -Type Action
    $scoopStatus = & scoop status
    if ($LASTEXITCODE -ne 0) {
        Write-Status "scoop status failed (exit code $LASTEXITCODE)" -Type Error
        $failedItems["Scoop"] += "scoop status (Exit Code: $LASTEXITCODE)"
    } else {
        $outdatedApps = @()
        foreach ($line in ($scoopStatus -split [System.Environment]::NewLine)) {
            if ($line -like '*outdated*') {
                $appName = ($line.Trim() -split '\s+')[0]
                if (-not [string]::IsNullOrWhiteSpace($appName) -and $appName -match '^[a-zA-Z0-9._-]+$') {
                    $outdatedApps += $appName
                }
            }
        }

        if ($outdatedApps.Count -gt 0) {
            Write-Status "Found $($outdatedApps.Count) outdated: $($outdatedApps -join ', ')" -Type Info
            $updatedItems["Scoop"] += $outdatedApps
        } else {
            Write-Status "All packages up-to-date" -Type Success
        }

        Write-Status "Updating Scoop itself..." -Type Action
        if (-not (Invoke-WithRetry -Action { & scoop update } -ActionName "scoop update")) {
            Write-Status "scoop update failed after retries" -Type Error
            $failedItems["Scoop"] += "scoop update (failed after retries)"
        }

        Write-Status "Updating all installed packages..." -Type Action
        # No retry — scoop returns non-zero if ANY package fails.
        # Retrying would re-run ALL updates unnecessarily.
        & scoop update *
        if ($LASTEXITCODE -ne 0) {
            Write-Status "Some packages may have failed (exit code $LASTEXITCODE)" -Type Warning
            Write-Log "scoop update * exited with code $LASTEXITCODE" -Level "WARN"
        }

        Write-Status "Removing old package versions..." -Type Action
        & scoop cleanup *
    }
}

# --- Update Winget & Microsoft Store Apps ---
Update-Section "Winget & Microsoft Store apps" ($NoWinget -or $OnlyWsl -or $OnlyWslPackages) { Get-Command winget -ErrorAction SilentlyContinue } {
    Write-Status "Checking for outdated packages..." -Type Action
    # We run 'winget upgrade' to get the list of upgradable packages.
    $wingetUpgradeOutput = & winget upgrade --include-unknown
    if ($LASTEXITCODE -ne 0) {
        Write-Status "winget upgrade check failed (exit code $LASTEXITCODE)" -Type Error
        $failedItems["Winget"] += "winget upgrade (check) (Exit Code: $LASTEXITCODE)"
    } else {
        $upgradablePackages = @()

        if ($wingetUpgradeOutput -and $wingetUpgradeOutput.Length -gt 2) {
            $lines = $wingetUpgradeOutput -split [System.Environment]::NewLine
            # The first line is the header, which we can use to find column positions.
            $headerLine = $lines[0]
            $idColIndex = $headerLine.IndexOf('Id')
            $versionColIndex = $headerLine.IndexOf('Version')

            if ($idColIndex -ge 0 -and $versionColIndex -gt $idColIndex) {
                # Start processing from the third line (index 2) to skip header and separator.
                for ($i = 2; $i -lt $lines.Length; $i++) {
                    $line = $lines[$i]
                    if ($line.Trim().Length -gt 0) {
                        $packageId = $line.Substring($idColIndex, $versionColIndex - $idColIndex).Trim()
                        if (-not [string]::IsNullOrWhiteSpace($packageId)) {
                            $upgradablePackages += $packageId
                        }
                    }
                }
            }
        }

        if ($upgradablePackages.Count -gt 0) {
            Write-Status "Found $($upgradablePackages.Count) upgradable packages" -Type Info
            $updatedItems["Winget"] += $upgradablePackages
        } else {
            Write-Status "All packages up-to-date" -Type Success
        }

        Write-Status "Refreshing winget sources..." -Type Action
        & winget source update

        Write-Status "Upgrading all packages..." -Type Action
        # No retry — winget returns non-zero if ANY package fails (e.g. Office).
        # Retrying would re-run ALL upgrades unnecessarily.
        & winget upgrade --all --accept-source-agreements --accept-package-agreements --include-pinned --include-unknown
        if ($LASTEXITCODE -ne 0) {
            Write-Status "Some packages may have failed, e.g. Office (exit code $LASTEXITCODE)" -Type Warning
            Write-Log "winget upgrade --all exited with code $LASTEXITCODE" -Level "WARN"
        }
    }
}


# --- Update Visual Studio Code Extensions ---
Update-Section "Visual Studio Code Extensions" ($NoVsCode -or $OnlyWsl -or $OnlyWslPackages) { Get-Command code -ErrorAction SilentlyContinue } {
    Write-Status "Listing installed extensions..." -Type Action
    $installedExtensions = & code --list-extensions
    if ($LASTEXITCODE -ne 0) {
        Write-Status "code --list-extensions failed (exit code $LASTEXITCODE)" -Type Error
        $failedItems["VS Code Extensions"] += "code --list-extensions (Exit Code: $LASTEXITCODE)"
    } else {
        $validExtensions = $installedExtensions | Where-Object {
            $_.Trim().Length -gt 0 -and $_ -match '^[a-zA-Z0-9._-]+\.[a-zA-Z0-9._-]+$'
        }
        Write-Status "Checking $($validExtensions.Count) extensions for updates..." -Type Info
        $actuallyUpdated = @()
        $progress = 0

        foreach ($extensionId in $validExtensions) {
            $progress++
            Write-Progress -Activity "Checking VS Code Extensions" -Status "$extensionId ($progress/$($validExtensions.Count))" -PercentComplete (($progress / $validExtensions.Count) * 100)
            # The '--force' flag ensures that the extension is updated if it's already installed.
            $updateOutput = & code --install-extension $extensionId --force 2>&1

            if ($LASTEXITCODE -ne 0) {
                Write-Status "Failed: $extensionId" -Type Error
                $failedItems["VS Code Extensions"] += "$extensionId (Exit Code: $LASTEXITCODE)"
            } elseif ($updateOutput -join ' ' -like '*successfully installed*') {
                Write-Status "Updated: $extensionId" -Type Success
                $actuallyUpdated += $extensionId
            }
        }
        Write-Progress -Activity "Checking VS Code Extensions" -Completed

        if ($actuallyUpdated.Count -gt 0) {
            Write-Status "$($actuallyUpdated.Count) extensions updated" -Type Success
            $updatedItems["VS Code Extensions"] += $actuallyUpdated
        } else {
            Write-Status "All extensions already up-to-date" -Type Success
        }
    }
}

# --- Update Miniconda ---
Update-Section "Miniconda and 'ocr-azure' environment" ($NoConda -or $OnlyWsl -or $OnlyWslPackages) { Get-Command conda -ErrorAction SilentlyContinue } {
    Write-Status "Updating base environment..." -Type Action
    if (Invoke-WithRetry -Action { & conda update -n base -c defaults conda -y } -ActionName "conda update -n base") {
        $updatedItems["Conda"] += "Miniconda (base)"
    } else {
        Write-Status "conda update -n base failed after retries" -Type Error
        $failedItems["Conda"] += "conda update -n base (failed after retries)"
    }

    # Check if 'ocr-azure' environment exists
    $condaEnvs = & conda env list
    if ($LASTEXITCODE -eq 0 -and ($condaEnvs | Where-Object { $_ -match '(?:^|\s)ocr-azure(?:\s|$)' })) {
        Write-Status "Updating 'ocr-azure' environment..." -Type Action
        if (Invoke-WithRetry -Action { & conda update -n ocr-azure --all -y } -ActionName "conda update -n ocr-azure") {
            $updatedItems["Conda"] += "Conda environment (ocr-azure)"
        } else {
            Write-Status "conda update -n ocr-azure failed after retries" -Type Error
            $failedItems["Conda"] += "conda update -n ocr-azure (failed after retries)"
        }
    } else {
        Write-Status "'ocr-azure' environment not found" -Type Skip
        if ($LASTEXITCODE -ne 0) {
            $failedItems["Conda"] += "conda env list (Exit Code: $LASTEXITCODE)"
        }
    }
}

# --- Update TeX Live ---
Update-Section "TeX Live" ($NoTex -or $OnlyWsl -or $OnlyWslPackages) { Get-Command tlmgr -ErrorAction SilentlyContinue } {
    Write-Status "Updating tlmgr and all packages..." -Type Action
    if (Invoke-WithRetry -Action { & tlmgr update --self --all } -ActionName "tlmgr update --self --all") {
        $updatedItems["TeX Live"] += "All packages"
    } else {
        Write-Status "tlmgr update failed after retries (admin required?)" -Type Error
        $failedItems["TeX Live"] += "tlmgr update (failed after retries)"
    }
}

# --- Update WSL ---
Update-Section "Windows Subsystem for Linux (WSL)" ($NoWsl -and !$OnlyWsl -and !$OnlyWslPackages) { Get-Command wsl -ErrorAction SilentlyContinue } {
    Write-Log "Starting WSL updates."
    # Since elevation is handled at the start, we can proceed directly.
    if (-not $OnlyWslPackages) {
        Write-Status "Updating WSL kernel..." -Type Action
        Write-Log "Updating WSL kernel."
        if (Invoke-WithRetry -Action { & wsl --update --web-download } -ActionName "wsl --update" -MaxRetries 2) {
            $updatedItems["WSL"] += "WSL Kernel"
        } else {
            Write-Status "wsl --update failed after retries" -Type Error
            $failedItems["WSL"] += "wsl --update (failed after retries)"
        }

        Write-Status "Shutting down WSL to apply updates..." -Type Action
        Write-Log "Shutting down WSL."
        Invoke-WithRetry -Action { & wsl --shutdown } -ActionName "wsl --shutdown" -MaxRetries 0 | Out-Null
    } else {
        Write-Log "Skipping WSL kernel update as requested."
    }

    Write-Status "Updating packages in default WSL distro..." -Type Action
    # Check for passwordless sudo access by checking the exit code of an external command.
    & wsl.exe sudo -n true 2>$null

    if ($LASTEXITCODE -eq 0) {
        Write-Status "Passwordless sudo confirmed" -Type Success
        & wsl.exe sudo apt-get update
        & wsl.exe sudo apt-get upgrade -y
        $updatedItems["WSL"] += "Updated packages in default WSL distro"
    } else {
        Write-Status "Passwordless sudo not configured" -Type Error
        Write-Host ""
        Write-Host "  To fix: run 'wsl', then 'sudo visudo' and add:" -ForegroundColor DarkYellow
        Write-Host "  your_username ALL=(ALL) NOPASSWD: /usr/bin/apt-get" -ForegroundColor DarkYellow
        Write-Host ""
        $failedItems["WSL"] += "Package update failed (sudo configuration needed)"
    }
}

# --- Update npm Packages ---
Update-Section "npm (Node Package Manager) Packages" ($NoNpm -or $OnlyWsl -or $OnlyWslPackages) { Get-Command npm -ErrorAction SilentlyContinue } {
    Write-Status "Checking for outdated global packages..." -Type Action
    $outdatedNpmJson = & npm outdated -g --json 2>&1
    # npm outdated exits 1 when packages ARE outdated (by design) — not an error condition.
    # We parse JSON regardless of exit code.
    $npmOutdated = $null
    try { $npmOutdated = $outdatedNpmJson | ConvertFrom-Json -ErrorAction Stop } catch {}
    $npmToUpdate = if ($npmOutdated) { @($npmOutdated.PSObject.Properties.Name) } else { @() }

    if ($npmToUpdate.Count -gt 0) {
        Write-Status "Found $($npmToUpdate.Count) outdated: $($npmToUpdate -join ', ')" -Type Info
        $updatedItems["npm"] += $npmToUpdate
    } else {
        Write-Status "All global packages up-to-date" -Type Success
    }

    Write-Status "Updating npm itself..." -Type Action
    if (-not (Invoke-WithRetry -Action { & npm install -g npm } -ActionName "npm install -g npm")) {
        Write-Status "npm self-update failed" -Type Warning
    }

    Write-Status "Updating all global packages..." -Type Action
    if (-not (Invoke-WithRetry -Action { & npm update -g } -ActionName "npm update -g")) {
        Write-Status "npm update -g failed after retries" -Type Error
        $failedItems["npm"] += "npm update -g (failed after retries)"
    }
}


# --- Final Summary ---
$totalElapsed = (Get-Date) - $scriptStartTime
Write-SectionHeader "Update Summary"

$hasUpdates = $false
foreach ($key in $updatedItems.Keys) {
    if ($updatedItems[$key].Count -gt 0) {
        $hasUpdates = $true
        Write-Host "  $key" -ForegroundColor Green
        $updatedItems[$key] | ForEach-Object { Write-Host "    - $_" -ForegroundColor Gray }
        Write-Host ""
    }
}

if (-not $hasUpdates) {
    Write-Status "Nothing was updated" -Type Info
    Write-Host ""
}

$hasFailures = $false
foreach ($key in $failedItems.Keys) {
    if ($failedItems[$key].Count -gt 0) {
        $hasFailures = $true
        Write-Host "  FAILED: $key" -ForegroundColor Red
        $failedItems[$key] | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkRed }
        Write-Host ""
    }
}

if (-not $hasFailures) {
    Write-Status "No failures" -Type Success
}

if ($skippedSections.Count -gt 0) {
    Write-Host ""
    Write-Host "  Skipped" -ForegroundColor DarkGray
    $skippedSections | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkGray }
}

Write-Host ""
Write-Host "  Total time: $($totalElapsed.ToString('hh\:mm\:ss'))" -ForegroundColor DarkGray
Write-Host ""

# Write structured summary to log
Write-Log "=== RUN SUMMARY ==="
foreach ($key in $updatedItems.Keys) {
    if ($updatedItems[$key].Count -gt 0) {
        Write-Log "  Updated [$key]: $($updatedItems[$key] -join ', ')"
    }
}
foreach ($key in $failedItems.Keys) {
    if ($failedItems[$key].Count -gt 0) {
        Write-Log "  Failed  [$key]: $($failedItems[$key] -join ', ')" -Level "ERROR"
    }
}
if ($skippedSections.Count -gt 0) {
    Write-Log "  Skipped: $($skippedSections -join ', ')"
}
Write-Log "Total time: $($totalElapsed.ToString('hh\:mm\:ss'))"
Write-Log "==================="

# Exit with appropriate code based on failures
if ($hasFailures) {
    Write-Log "Script completed with failures." -Level "ERROR"
    exit 1
}
Write-Log "Script completed successfully."
exit 0
