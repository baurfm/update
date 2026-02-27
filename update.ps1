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

.PARAMETER NoPipx
    A switch to skip updating pipx packages.

.PARAMETER NoRust
    A switch to skip updating the Rust toolchain via rustup.

.PARAMETER NoGem
    A switch to skip updating Ruby Gems.

.PARAMETER NoChoco
    A switch to skip updating Chocolatey packages.

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
    Version: 10.0 (Add: pipx/rustup/gem/choco update sections, -NoPipx/-NoRust/-NoGem/-NoChoco params; Fix: WSL circular sudo bug (wsl -u root instead of wsl sudo), unconditional apt-get success tracking, re-verify sudo after auto-config; Refactor: WSL sudo logic into Set-WslPasswordlessSudo helper; previous 9.9: WSL sudo auto-config, -SkipWslSudoConfig; 9.8: winget pinned ignore, conda base --all, logs/ folder)
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
    [switch]$NoPipx,
    [switch]$NoRust,
    [switch]$NoGem,
    [switch]$NoChoco,
    [switch]$OnlyWsl,
    [switch]$OnlyWslPackages,

    [Parameter(HelpMessage = "Enable verbose output.")]
    [switch]$EnableVerbose,

    [Parameter(HelpMessage = "If set, skip any automatic configuration of WSL sudo (passwordless apt-get).")]
    [switch]$SkipWslSudoConfig,

    [Parameter(HelpMessage = "Path to log file. Defaults to 'logs/update.log' under script directory.")]
    [string]$LogFile = "update.log"
)

# Helper: format a TimeSpan as "4m 12s" / "38s" / "1h 2m"
function Format-Elapsed {
    param([TimeSpan]$ts)
    if ($ts.TotalHours -ge 1)   { return "$([int]$ts.TotalHours)h $($ts.Minutes)m" }
    if ($ts.TotalMinutes -ge 1) { return "$([int]$ts.TotalMinutes)m $($ts.Seconds)s" }
    return "$([int]$ts.TotalSeconds)s"
}

# Function to display a formatted section header
function Write-SectionHeader {
    param([string]$Title)
    $line = ([char]0x2500).ToString() * 58   # ──────────
    Write-Host ""
    Write-Host "  $line" -ForegroundColor DarkGray
    Write-Host "  $([char]0x25B6)  $Title" -ForegroundColor Cyan   # ▶  Title
    Write-Host "  $line" -ForegroundColor DarkGray
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
        "Info"    { Write-Host "  $([char]0x00B7)  $Message" -ForegroundColor Gray }      # ·
        "Success" { Write-Host "  $([char]0x2713)  $Message" -ForegroundColor Green }     # ✓
        "Warning" { Write-Host "  $([char]0x26A0)  $Message" -ForegroundColor Yellow }    # ⚠
        "Error"   { Write-Host "  $([char]0x2717)  $Message" -ForegroundColor Red }       # ✗
        "Skip"    { Write-Host "  $([char]0x25CB)  $Message" -ForegroundColor DarkGray }  # ○
        "Action"  { Write-Host "  $([char]0x2192)  $Message" -ForegroundColor White }     # →
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
    # Always write to file
    if ($LogFile) { Add-Content -Path $LogFile -Value $logMessage }
    # Terminal: raw log lines only in verbose mode; WARN/ERROR shown via Write-Status otherwise
    if ($EnableVerbose) {
        Write-Host $logMessage -ForegroundColor DarkGray
    } elseif ($Level -eq "WARN") {
        Write-Status $Message -Type Warning
    } elseif ($Level -eq "ERROR") {
        Write-Status $Message -Type Error
    }
    # INFO and DEBUG are silent in terminal unless -EnableVerbose
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
        Write-Status "Done  $(Format-Elapsed $elapsed)" -Type Success
        Write-Log "$SectionName updates completed."
    } catch {
        $elapsed = (Get-Date) - $sectionStart
        Write-Status "Failed after $(Format-Elapsed $elapsed): $_" -Type Error
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

# Helper: non-elevated pre-check — returns $true if winget reports any non-pinned upgradable
# packages. On any parse error or winget failure, returns $true (safe default: assume updates).
function Test-WingetHasUpdates {
    # Refresh sources first — stale cache can show phantom updates that disappear after refresh.
    & winget source update 2>$null | Out-Null

    # Omit --include-unknown: "unknown-version" packages appear upgradeable but winget upgrade
    # --all cannot actually install them ("No installed package found matching input criteria").
    # NOTE: winget exits non-zero (0x8A150014) when there are NO updates — do NOT gate on
    # $LASTEXITCODE here. We rely entirely on the output text and table content.
    $output = & winget upgrade 2>$null
    if (-not $output) { return $false }

    # When nothing needs updating winget prints this message with no table.
    if (($output -join "`n") -match 'No applicable upgrades were found') { return $false }

    $lines = $output -split [System.Environment]::NewLine

    # Winget sometimes emits a progress line before the table header; find the real
    # header by locating the first line that contains both 'Id' and 'Version' columns.
    $header = $lines | Where-Object { $_ -match '\bId\b' -and $_ -match '\bVersion\b' } |
                       Select-Object -First 1
    # No table → winget showed nothing upgradeable. The common case is "all upgradeable
    # packages are pinned" which prints a pins message with no table. No table = no action.
    if (-not $header) { return $false }

    $idCol  = $header.IndexOf('Id')
    $verCol = $header.IndexOf('Version')
    # Malformed header = can't parse = treat as no updates (avoid false elevation)
    if ($idCol -lt 0 -or $verCol -le $idCol) { return $false }

    $headerIdx = [Array]::IndexOf($lines, $header)
    for ($i = $headerIdx + 2; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line.Trim().Length -eq 0)      { continue }   # blank
        if ($line -match '\bPinned\b')       { continue }   # user-pinned — skip
        if ($line -match '^\s*-+\s*$')       { continue }   # separator row
        if ($line.Length -le $idCol)         { continue }
        $pkg = $line.Substring($idCol, [Math]::Min($verCol - $idCol, $line.Length - $idCol)).Trim()
        # Skip summary lines like "2 upgrades available."
        if ($pkg.Length -gt 0 -and $pkg -notmatch '^\d') { return $true }
    }
    return $false
}

# Helper: non-elevated WSL version check — returns $true if a newer WSL kernel is available
# on GitHub. Returns $false (skip elevation) on network errors rather than prompting blindly.
function Test-WslHasUpdates {
    $verOutput = & wsl --version 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $verOutput) { return $false }

    $currentLine = $verOutput | Where-Object { $_ -match '^\s*WSL version:' } | Select-Object -First 1
    if (-not $currentLine) { return $false }
    $current = ($currentLine -replace '.*:\s*', '').Trim()    # e.g. "2.3.26.0"

    try {
        $rel    = Invoke-RestMethod 'https://api.github.com/repos/microsoft/WSL/releases/latest' `
                      -TimeoutSec 5 -ErrorAction Stop
        $latest = $rel.tag_name -replace '^v', ''             # e.g. "2.3.26"
        if (-not $latest) { return $false }
        # Normalise to Major.Minor.Patch (drop 4th segment if present)
        $cur3 = ($current -split '\.' | Select-Object -First 3) -join '.'
        $lat3 = ($latest  -split '\.' | Select-Object -First 3) -join '.'
        if ($cur3 -ne $lat3) {
            Write-Status "WSL update available: $cur3 → $lat3" -Type Info
            return $true
        }
        Write-Status "WSL kernel current: $cur3" -Type Success
        return $false
    } catch {
        Write-Status "WSL version check failed (offline?) — skipping WSL elevation" -Type Warning
        return $false
    }
}

# Helper: write a NOPASSWD sudoers entry for apt-get via wsl -u root, then verify sudo works.
# Returns $true if passwordless sudo is confirmed after the operation.
function Set-WslPasswordlessSudo {
    param([string]$LinuxUser)
    $cmd = "echo '$LinuxUser ALL=(ALL) NOPASSWD: /usr/bin/apt-get' > /etc/sudoers.d/update-apt-get && chmod 0440 /etc/sudoers.d/update-apt-get"
    & wsl.exe -u root sh -c $cmd | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    # Verify by running the exact allowed command — sudo -n true would fail because
    # the sudoers rule only covers /usr/bin/apt-get, not /usr/bin/true.
    & wsl.exe sudo -n apt-get --version 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

# Initialize logging and display startup banner
$scriptStartTime = Get-Date
$_banner_line = ([char]0x2500).ToString() * 36
Write-Host ""
Write-Host "  $_banner_line" -ForegroundColor DarkGray
Write-Host "  $([char]0x25C6)  Windows Update Script  " -NoNewline -ForegroundColor DarkGray
Write-Host "v10.0" -ForegroundColor Cyan
Write-Host "  $([char]0x25C6)  $($scriptStartTime.ToString('yyyy-MM-dd  HH:mm:ss'))" -ForegroundColor DarkGray
Write-Host "  $_banner_line" -ForegroundColor DarkGray
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
# Both winget upgrade --all and wsl --update need admin. We pre-check each without
# elevation so the UAC/sudo prompt is skipped entirely when nothing needs updating.
$wingetNeedsElevation = $false
if (-not $NoWinget -and (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Status "Pre-checking winget for available updates..." -Type Action
    $wingetNeedsElevation = Test-WingetHasUpdates
    if (-not $wingetNeedsElevation) {
        Write-Status "Winget: all packages up-to-date — no elevation needed" -Type Success
    }
}

$wslNeedsElevation = $false
# Only wsl --update needs elevation; apt-get does not.
# Skip when -NoWsl or -OnlyWslPackages is set (wsl --update won't run anyway).
if (-not $NoWsl -and -not $OnlyWslPackages -and (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Status "Pre-checking WSL for available kernel updates..." -Type Action
    $wslNeedsElevation = Test-WslHasUpdates
    if (-not $wslNeedsElevation) {
        Write-Status "WSL kernel already up-to-date — no elevation needed for WSL" -Type Success
    }
}

# Compute admin status once; used later by the WSL section to gate wsl --update.
$myWindowsID        = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole          = [System.Security.Principal.WindowsBuiltInRole]::Administrator
$script:isAdmin     = $myWindowsPrincipal.IsInRole($adminRole)

if ($wingetNeedsElevation -or $wslNeedsElevation) {
    if (-not $script:isAdmin) {
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

# Ensure a dedicated log directory exists and adjust the default log file path
$LogDir = Join-Path $ScriptPath "logs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

# Move any existing log files from the script directory into the dedicated log folder
Get-ChildItem -Path $ScriptPath -Filter "update*.log" -File -ErrorAction SilentlyContinue |
    ForEach-Object {
        $dest = Join-Path $LogDir $_.Name
        if (-not (Test-Path $dest)) {
            Move-Item -Path $_.FullName -Destination $dest -Force
        } else {
            $ts = Get-Date -Format "yyyy-MM-dd_HHmmss"
            $newName = "${($_.BaseName)}-$ts$($_.Extension)"
            Move-Item -Path $_.FullName -Destination (Join-Path $LogDir $newName) -Force
        }
    }

# Resolve log file to absolute path now that $ScriptPath is known
if (-not $PSBoundParameters.ContainsKey('LogFile')) {
    $LogFile = Join-Path $LogDir "update.log"
} else {
    # if user provided a relative path, make it absolute relative to script path
    if (-not ([System.IO.Path]::IsPathRooted($LogFile))) {
        $LogFile = Join-Path $ScriptPath $LogFile
    }
}

# Log rotation: rename existing log with timestamp, keep last 5 archives
if (Test-Path $LogFile) {
    $stamp  = $scriptStartTime.ToString('yyyy-MM-dd_HHmmss')
    # basename may sometimes be empty (e.g. malformed path); fall back to 'update'
    $logBase = [System.IO.Path]::GetFileNameWithoutExtension($LogFile)
    if ([string]::IsNullOrWhiteSpace($logBase)) { $logBase = 'update' }
    $logDir = Split-Path $LogFile -Parent
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
$sectionKeys = "PowerShell Modules", "Scoop", "Winget", "VS Code Extensions", "Conda", "TeX Live", "WSL", "npm", "pipx", "Rust", "Ruby Gems", "Chocolatey"
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
                        # skip any line that indicates the package is pinned (last column)
                        if ($line -match '\bPinned\b') { continue }
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
        # Pinned packages are excluded by default; we deliberately do not pass
        # --include-pinned so user pins are preserved.
        & winget upgrade --all --accept-source-agreements --accept-package-agreements --include-unknown
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

    # After upgrading conda itself, update all packages in the base environment
    Write-Status "Updating all packages in base environment..." -Type Action
    if (Invoke-WithRetry -Action { & conda update -n base --all -y } -ActionName "conda update -n base --all") {
        $updatedItems["Conda"] += "Conda packages (base)"
    } else {
        Write-Status "conda update -n base --all failed after retries" -Type Error
        $failedItems["Conda"] += "conda update -n base --all (failed after retries)"
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

    # Ensure base environment activates automatically in new shells so tools
    # installed there (e.g. pipx) are available on PATH without manual activation.
    Write-Status "Ensuring auto_activate_base is enabled..." -Type Action
    & conda config --set auto_activate_base true
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
        if ($script:isAdmin) {
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
            Write-Status "WSL kernel update skipped (not running as admin)" -Type Skip
            Write-Log "Skipping WSL kernel update — not elevated."
        }
    } else {
        Write-Log "Skipping WSL kernel update as requested."
    }

    Write-Status "Updating packages in default WSL distro..." -Type Action
    # Use the exact allowed command for the passwordless-sudo check (not 'true',
    # which isn't in the sudoers rule and would always require a password).
    & wsl.exe sudo -n apt-get --version 2>$null | Out-Null
    $sudoOk = ($LASTEXITCODE -eq 0)

    if (-not $sudoOk) {
        Write-Status "Passwordless sudo not configured" -Type Error
        if ($SkipWslSudoConfig) {
            Write-Status "Skipping automatic sudo configuration as requested" -Type Skip
            $failedItems["WSL"] += "Package update skipped (passwordless sudo not configured)"
        } else {
            Write-Status "Attempting automatic sudo configuration..." -Type Action
            $linuxUser = & wsl.exe whoami 2>$null | ForEach-Object { $_.Trim() }
            if (-not $linuxUser) {
                Write-Status "Could not determine WSL username" -Type Error
                $failedItems["WSL"] += "Unable to configure sudo (username unknown)"
            } elseif (Set-WslPasswordlessSudo -LinuxUser $linuxUser) {
                Write-Status "Passwordless sudo configured for $linuxUser" -Type Success
                $sudoOk = $true
            } else {
                Write-Status "Failed to configure passwordless sudo" -Type Error
                $failedItems["WSL"] += "sudoers configuration failed"
            }
        }
    }

    if ($sudoOk) {
        Write-Status "Running apt-get update and upgrade..." -Type Action
        Write-Log "Running apt-get update and upgrade."
        & wsl.exe sudo apt-get update
        & wsl.exe sudo apt-get upgrade -y
        if ($LASTEXITCODE -eq 0) {
            $updatedItems["WSL"] += "Updated packages in default WSL distro"
        } else {
            Write-Status "apt-get upgrade failed" -Type Error
            $failedItems["WSL"] += "apt-get upgrade failed"
        }
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

# --- Update pipx packages ---
Update-Section "pipx packages" ($NoPipx -or $OnlyWsl -or $OnlyWslPackages) {
    # pipx may live in conda base even when auto_activate_base is off; accept either
    (Get-Command pipx -ErrorAction SilentlyContinue) -or (Get-Command conda -ErrorAction SilentlyContinue)
} {
    Write-Status "Upgrading all pipx packages..." -Type Action
    Write-Log "Upgrading pipx packages."
    # Force Python UTF-8 mode so pipx can print emoji in its output without crashing
    # on Windows consoles with cp1252 or other narrow code pages.
    $env:PYTHONUTF8 = '1'
    # Prefer direct pipx; fall back to conda run -n base if pipx is only in conda base
    $pipxAction = if (Get-Command pipx -ErrorAction SilentlyContinue) {
        { & pipx upgrade-all }
    } else {
        Write-Status "pipx not on PATH — running via conda base" -Type Info
        { & conda run -n base pipx upgrade-all }
    }
    if (Invoke-WithRetry -Action $pipxAction -ActionName "pipx upgrade-all") {
        $updatedItems["pipx"] += "All pipx packages"
    } else {
        Write-Status "pipx upgrade-all failed after retries" -Type Error
        $failedItems["pipx"] += "pipx upgrade-all (failed after retries)"
    }
}

# --- Update Rust toolchain ---
Update-Section "Rust (rustup)" ($NoRust -or $OnlyWsl -or $OnlyWslPackages) { Get-Command rustup -ErrorAction SilentlyContinue } {
    Write-Status "Updating Rust toolchain..." -Type Action
    Write-Log "Updating Rust toolchain via rustup."
    if (Invoke-WithRetry -Action { & rustup update } -ActionName "rustup update") {
        $updatedItems["Rust"] += "Rust toolchain"
    } else {
        Write-Status "rustup update failed after retries" -Type Error
        $failedItems["Rust"] += "rustup update (failed after retries)"
    }
}

# --- Update Ruby Gems ---
Update-Section "Ruby Gems" ($NoGem -or $OnlyWsl -or $OnlyWslPackages) { Get-Command gem -ErrorAction SilentlyContinue } {
    Write-Status "Updating RubyGems system..." -Type Action
    Write-Log "Updating Ruby Gems."
    if (-not (Invoke-WithRetry -Action { & gem update --system } -ActionName "gem update --system")) {
        Write-Status "gem update --system failed after retries" -Type Warning
    }
    Write-Status "Updating all gems..." -Type Action
    if (Invoke-WithRetry -Action { & gem update } -ActionName "gem update") {
        $updatedItems["Ruby Gems"] += "All gems"
    } else {
        Write-Status "gem update failed after retries" -Type Error
        $failedItems["Ruby Gems"] += "gem update (failed after retries)"
    }
}

# --- Update Chocolatey packages ---
Update-Section "Chocolatey packages" ($NoChoco -or $OnlyWsl -or $OnlyWslPackages) { Get-Command choco -ErrorAction SilentlyContinue } {
    Write-Status "Upgrading all Chocolatey packages..." -Type Action
    Write-Log "Upgrading Chocolatey packages."
    if (Invoke-WithRetry -Action { & choco upgrade all -y } -ActionName "choco upgrade all") {
        $updatedItems["Chocolatey"] += "All Chocolatey packages"
    } else {
        Write-Status "choco upgrade failed after retries" -Type Error
        $failedItems["Chocolatey"] += "choco upgrade all (failed after retries)"
    }
}


# --- Final Summary ---
$totalElapsed = (Get-Date) - $scriptStartTime
Write-SectionHeader "Update Summary"

$hasUpdates = $false
foreach ($key in $updatedItems.Keys) {
    if ($updatedItems[$key].Count -gt 0) {
        $hasUpdates = $true
        Write-Host "  $([char]0x2713)  $key" -ForegroundColor Green
        $updatedItems[$key] | ForEach-Object { Write-Host "       $([char]0x2022) $_" -ForegroundColor Gray }
        Write-Host ""
    }
}

if (-not $hasUpdates) {
    Write-Status "Everything already up-to-date" -Type Info
    Write-Host ""
}

$hasFailures = $false
foreach ($key in $failedItems.Keys) {
    if ($failedItems[$key].Count -gt 0) {
        $hasFailures = $true
        Write-Host "  $([char]0x2717)  $key" -ForegroundColor Red
        $failedItems[$key] | ForEach-Object { Write-Host "       $([char]0x2022) $_" -ForegroundColor DarkRed }
        Write-Host ""
    }
}

if (-not $hasFailures) {
    Write-Status "No failures" -Type Success
}

if ($skippedSections.Count -gt 0) {
    Write-Host ""
    Write-Host "  $([char]0x25CB)  Skipped" -ForegroundColor DarkGray
    $skippedSections | ForEach-Object { Write-Host "       $([char]0x2022) $_" -ForegroundColor DarkGray }
}

Write-Host ""
Write-Host "  $([char]0x25C6)  Total time: $(Format-Elapsed $totalElapsed)" -ForegroundColor DarkGray
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
Write-Log "Total time: $(Format-Elapsed $totalElapsed)"
Write-Log "==================="

# Exit with appropriate code based on failures
if ($hasFailures) {
    Write-Log "Script completed with failures." -Level "ERROR"
    exit 1
}
Write-Log "Script completed successfully."
exit 0
