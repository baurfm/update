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

.PARAMETER NoAndroid
    A switch to skip updating Android SDK components via sdkmanager.

.PARAMETER NoSelfUpdate
    A switch to skip the GitHub self-update check at startup.

.PARAMETER Sudo
    Re-launch the script as administrator immediately, bypassing the pre-checks that normally
    trigger elevation. Useful when you know elevation is needed (e.g. after a long gap since
    the last run) and want to skip the pre-check overhead.

.PARAMETER OnlyWsl
    A switch to only update WSL and skip other sections.

.PARAMETER OnlyWslPackages
    A switch to only update WSL packages (apt-get) and skip other sections including WSL kernel.

.PARAMETER EnableVerbose
    A switch to enable verbose output.

.PARAMETER LogFile
    Path to the log file. Default is 'update.log'.

.PARAMETER DryRun
    Show which tools are installed and would be updated, without executing any updates.
    Pre-checks and elevation are skipped; all sections show "dry run" in the output.

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
    Version: 10.19
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
    [switch]$NoGCloud,
    [switch]$NoGhExt,
    [switch]$NoDotnet,
    [switch]$NoAndroid,
    [switch]$NoSelfUpdate,
    [switch]$Sudo,          # Re-launch as administrator immediately, skipping pre-checks
    [switch]$NoOhMyPosh,    # Skip Oh My Posh upgrade
    [switch]$NoUv,          # Skip uv self-update
    [switch]$NoPnpm,        # Skip pnpm self-update
    [switch]$NoBun,         # Skip Bun upgrade
    [switch]$NoDeno,        # Skip Deno upgrade
    [switch]$NoHelm,        # Skip Helm plugin updates
    [switch]$NoPoetry,      # Skip Poetry self-update
    [switch]$NoRye,         # Skip Rye self-update
    [switch]$NoComposer,    # Skip Composer self-update
    [switch]$NoKrew,        # Skip krew (kubectl plugin manager) upgrade
    [switch]$DryRun,        # Show what would be updated without running updates
    [switch]$OnlyWsl,
    [switch]$OnlyWslPackages,

    [Parameter(HelpMessage = "Enable verbose output.")]
    [switch]$EnableVerbose,

    [Parameter(HelpMessage = "If set, skip any automatic configuration of WSL sudo (passwordless apt-get).")]
    [switch]$SkipWslSudoConfig,

    [Parameter(HelpMessage = "Path to log file. Defaults to 'logs/update.log' under script directory.")]
    [string]$LogFile = "update.log"
)

# ── Configurable constants ─────────────────────────────────────────────────
$script:TexLiveTimeoutSec  = 1800   # max seconds to wait for tlmgr (30 min)
$script:TexLiveLogAgeMins  = 10     # minutes back to scan for TeX Live log files
$script:DownloadTimeoutSec = 120    # seconds for Invoke-WebRequest calls
$script:DiskSpaceWarnGB    = 2      # GB free on C: below which to warn
$script:LogArchiveCount    = 5      # number of archived log files to keep
# ───────────────────────────────────────────────────────────────────────────

# Helper: format a TimeSpan as "4m 12s" / "38s" / "1h 2m"
function Format-Elapsed {
    param([TimeSpan]$ts)
    if ($ts.TotalHours -ge 1)   { return "$([int]$ts.TotalHours)h $($ts.Minutes)m" }
    if ($ts.TotalMinutes -ge 1) { return "$([int]$ts.TotalMinutes)m $($ts.Seconds)s" }
    return "$([int]$ts.TotalSeconds)s"
}

# Function to display a formatted section header (secondary level — within a group)
function Write-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "  $([char]0x25B6)  " -NoNewline -ForegroundColor DarkCyan   # ▶
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ""
}

# Function to display a group header (primary level — separates logical categories)
function Write-GroupHeader {
    param([string]$Title)
    $maxLen = 54   # 58-char rule minus 4 for the ▪ prefix — truncate if longer
    if ($Title.Length -gt $maxLen) { $Title = $Title.Substring(0, $maxLen - 3) + '...' }
    $line = ([char]0x2550).ToString() * 58   # ══════════ (double rule — visually heavier)
    Write-Host ""
    Write-Host "  $line" -ForegroundColor DarkGray
    Write-Host "  $([char]0x25AA) " -NoNewline -ForegroundColor DarkYellow   # ▪
    Write-Host $Title -ForegroundColor Yellow
}

# Function to display a status message with a consistent prefix
function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error", "Skip", "Action")]
        [string]$Type = "Info"
    )
    switch ($Type) {
        "Info"    { Write-Host "  $([char]0x00B7)  $Message" -ForegroundColor DarkGray }  # ·
        "Success" { Write-Host "  $([char]0x2713)  $Message" -ForegroundColor Green }     # ✓
        "Warning" { Write-Host "  $([char]0x26A0)  $Message" -ForegroundColor Yellow }    # ⚠
        "Error"   { Write-Host "  $([char]0x2717)  $Message" -ForegroundColor Red }       # ✗
        "Skip"    { Write-Host "  $([char]0x25CB)  $Message" -ForegroundColor DarkGray }  # ○
        "Action"  {
            Write-Host "  $([char]0x2192)  " -NoNewline -ForegroundColor DarkCyan         # →
            Write-Host $Message -ForegroundColor White
        }
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
        Write-Status "$SectionName — skipped" -Type Skip
        Write-Log "Skipping $SectionName updates."
        $script:skippedSections += $SectionName
        return
    }

    if (-not (& $ToolCheck)) {
        Write-Status "$SectionName — not installed" -Type Skip
        Write-Log "$SectionName not found."
        $script:skippedSections += "$SectionName (not installed)"
        return
    }

    if ($DryRun) {
        Write-Status "$SectionName — installed (dry run, skipping)" -Type Skip
        $script:skippedSections += "$SectionName (dry run)"
        return
    }

    Write-SectionHeader "Updating $SectionName"
    Write-Log "Starting $SectionName updates."

    $sectionStart = Get-Date
    try {
        & $UpdateAction
        $elapsed = (Get-Date) - $sectionStart
        $script:sectionTimings[$SectionName] = $elapsed
        Write-Status "Done  $(Format-Elapsed $elapsed)" -Type Success
        Write-Log "$SectionName updates completed in $(Format-Elapsed $elapsed)."
    } catch {
        $elapsed = (Get-Date) - $sectionStart
        $script:sectionTimings[$SectionName] = $elapsed
        Write-Status "Failed after $(Format-Elapsed $elapsed): $_" -Type Error
        Write-Log "Error during $SectionName updates: $_ [$(Format-Elapsed $elapsed)]" -Level "ERROR"
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
            $sleepSec = $DelaySeconds * $attempt   # exponential: 5s, 10s, 15s …
            Write-Status "Retrying $ActionName in ${sleepSec}s (attempt $($attempt + 1) of $maxAttempts)..." -Type Warning
            Start-Sleep -Seconds $sleepSec
        }
    } while ($attempt -lt $maxAttempts)
    Write-Log "$ActionName failed after $maxAttempts attempts." -Level "ERROR"
    return $false
}

# Helper: standard "tool self-update" — wraps Invoke-WithRetry and records into result hashtables.
# Write-Status for the action line is intentionally inside callers so the message can be customised.
function Invoke-SelfUpdate {
    param(
        [Parameter(Mandatory)]
        [string]$ToolName,
        [Parameter(Mandatory)]
        [string]$Key,
        [Parameter(Mandatory)]
        [scriptblock]$Action,
        [string]$ActionName
    )
    if (-not $ActionName) { $ActionName = "$ToolName self-update" }
    Write-Status "Updating $ToolName..." -Type Action
    if (Invoke-WithRetry -Action $Action -ActionName $ActionName) {
        $updatedItems[$Key] += $ToolName
    } else {
        Write-Status "$ToolName self-update failed" -Type Error
        $failedItems[$Key] += "$ToolName self-update (failed)"
    }
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

# Helper: find TeX Live log files modified recently and append them to our update log.
# Called after any tlmgr or update-tlmgr-latest.exe operation for full diagnostics.
function Write-TexLiveLog {
    param([int]$AgeMinutes = $script:TexLiveLogAgeMins)
    $logs = Get-ChildItem "C:\texlive\*\temp\*.log" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-$AgeMinutes) } |
            Sort-Object LastWriteTime -Descending
    foreach ($log in $logs) {
        Write-Log "--- TeX Live log: $($log.FullName) ---" -Level "INFO"
        Get-Content $log.FullName -ErrorAction SilentlyContinue |
            ForEach-Object { Write-Log "  $_" -Level "INFO" }
    }
}

# Runs 'tlmgr update --self --all' in a background job with a 30-minute timeout.
# Returns [PSCustomObject]@{ Lines=[string[]]; ExitCode=[int] }  (ExitCode -2 = timed out)
function Invoke-TlMgrUpdate {
    param([int]$TimeoutSeconds = $script:TexLiveTimeoutSec)
    $envPath = $env:PATH
    $job = Start-Job -ScriptBlock {
        $env:PATH = $using:envPath
        $out = tlmgr update --self --all 2>&1
        [PSCustomObject]@{ Lines = $out; ExitCode = $LASTEXITCODE }
    }
    $completed = $job | Wait-Job -Timeout $TimeoutSeconds
    if ($null -eq $completed) {
        $job | Stop-Job
        $job | Remove-Job -Force
        $mins = [Math]::Round($TimeoutSeconds / 60)
        return [PSCustomObject]@{ Lines = @("TIMEOUT: tlmgr killed after $mins minutes"); ExitCode = -2 }
    }
    $result = $job | Receive-Job
    $job | Remove-Job -Force
    return $result
}

# --- Early log initialization ---
# Must happen before the banner, self-update, and pre-checks so that all Write-Log
# calls land in logs/update.log rather than a relative-path file that gets archived.
$scriptStartTime = Get-Date
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $ScriptPath "logs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}
if (-not $PSBoundParameters.ContainsKey('LogFile')) {
    $LogFile = Join-Path $LogDir "update.log"
} elseif (-not ([System.IO.Path]::IsPathRooted($LogFile))) {
    $LogFile = Join-Path $ScriptPath $LogFile
}
# Log rotation: rename existing log with timestamp, keep last 5 archives
if (Test-Path $LogFile) {
    $stamp   = $scriptStartTime.ToString('yyyy-MM-dd_HHmmss')
    $logBase = [System.IO.Path]::GetFileNameWithoutExtension($LogFile)
    if ([string]::IsNullOrWhiteSpace($logBase)) { $logBase = 'update' }
    $archivePath = Join-Path $LogDir "$logBase-$stamp.log"
    Rename-Item -Path $LogFile -NewName $archivePath -ErrorAction SilentlyContinue
    Get-ChildItem -Path $LogDir -Filter "$logBase-*.log" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $script:LogArchiveCount |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# Display startup banner
$_bw      = 40
$_bTop    = "  $([char]0x256D)$(([char]0x2500).ToString() * $_bw)$([char]0x256E)"
$_bBot    = "  $([char]0x2570)$(([char]0x2500).ToString() * $_bw)$([char]0x256F)"
$_bBar    = [char]0x2502
$_gem     = [char]0x25C6
$_title   = "  $_gem  Windows Update Script  "
$_version = "v10.19"
$_dateStr = "  $_gem  $($scriptStartTime.ToString('yyyy-MM-dd  HH:mm:ss'))"
Write-Host ""
Write-Host $_bTop -ForegroundColor DarkGray
Write-Host "  $_bBar" -NoNewline -ForegroundColor DarkGray
Write-Host $_title -NoNewline -ForegroundColor DarkGray
Write-Host $_version -NoNewline -ForegroundColor Cyan
Write-Host (" " * [Math]::Max(0, $_bw - $_title.Length - $_version.Length)) -NoNewline
Write-Host "$_bBar" -ForegroundColor DarkGray
Write-Host "  $_bBar" -NoNewline -ForegroundColor DarkGray
Write-Host $_dateStr -NoNewline -ForegroundColor DarkGray
Write-Host (" " * [Math]::Max(0, $_bw - $_dateStr.Length)) -NoNewline
Write-Host "$_bBar" -ForegroundColor DarkGray
Write-Host $_bBot -ForegroundColor DarkGray
Write-Host ""

# --- Self-update via git pull ---
if (-not $NoSelfUpdate) {
    $scriptDir = Split-Path $PSCommandPath -Parent
    if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $scriptDir ".git"))) {
        Write-Status "Checking for script updates (git pull)..." -Type Action
        try {
            $pullOut = & git -C $scriptDir pull 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Status "git pull failed: $($pullOut -join ' ')" -Type Warning
                Write-Log "Self-update: git pull failed (exit $LASTEXITCODE): $($pullOut -join ' ')" -Level "WARN"
            } elseif (($pullOut -join ' ') -match 'Already up[ -]to[ -]date') {
                Write-Status "Script is up to date ($_version)" -Type Success
                Write-Log "Self-update: already up to date ($_version)" -Level "INFO"
            } else {
                # Repo changed — check if the script file itself was updated
                $newVerMatch = Select-String '^\$_version\s*=\s*"(v[\d.]+)"' $PSCommandPath
                $newVer = if ($newVerMatch) { $newVerMatch.Matches[0].Groups[1].Value } else { $null }
                if ($newVer -and $newVer -ne $_version) {
                    Write-Status "Script updated: $_version → $newVer. Re-running..." -Type Success
                    Write-Log "Self-update: script updated $_version → $newVer, re-running." -Level "INFO"
                    & $PSCommandPath @PSBoundParameters -NoSelfUpdate
                    exit $LASTEXITCODE
                } else {
                    Write-Status "Repo updated (non-script files only)" -Type Info
                    Write-Log "Self-update: repo updated (non-script files only)" -Level "INFO"
                }
            }
        } catch {
            Write-Status "git pull failed: $($_.Exception.Message)" -Type Warning
            Write-Log "Self-update: git pull exception: $($_.Exception.Message)" -Level "WARN"
        }
    }
}

# PowerShell version check (5.0+ required for Get-InstalledModule, Update-Module, etc.)
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "  [X]  PowerShell 5.0+ required (found $($PSVersionTable.PSVersion))" -ForegroundColor Red
    exit 1
}

# Disk space warning
$freeGB = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
if ($freeGB -lt $script:DiskSpaceWarnGB) {
    Write-Status "Low disk space: ${freeGB} GB free on C: — updates may fail (threshold: $($script:DiskSpaceWarnGB) GB)" -Type Warning
    Write-Log "WARNING: Low disk space: ${freeGB} GB free on C: (threshold: $($script:DiskSpaceWarnGB) GB)" -Level "WARN"
}

Write-Log "Starting update script."
Write-Log "OS: $([System.Environment]::OSVersion.VersionString)"
Write-Log "PowerShell: $($PSVersionTable.PSVersion)"
Write-Log "User: $([System.Environment]::UserName)"
Write-Log "Free disk (C:): ${freeGB} GB"
if ($PSBoundParameters.Count -gt 0) {
    $paramStr = ($PSBoundParameters.GetEnumerator() | ForEach-Object {
        if ($_.Value -is [switch]) { "-$($_.Key)" } else { "-$($_.Key) '$($_.Value)'" }
    }) -join ' '
    Write-Log "Parameters: $paramStr"
}

# Set error action preference for consistent error handling
$ErrorActionPreference = 'Continue'

# --- Administrator Elevation Check ---
# winget upgrade --all, wsl --update, and npm install -g all need admin when npm's
# global prefix is in a protected directory. Pre-check each so UAC is skipped when nothing needs updating.
# -Sudo bypasses all pre-checks and forces immediate elevation.
$wingetNeedsElevation = $false
$wslNeedsElevation    = $false
$npmNeedsElevation    = $false

if ($Sudo) {
    Write-Status "Sudo flag set — skipping pre-checks, will elevate immediately" -Type Info
    Write-Log "Pre-check: -Sudo specified, skipping all pre-checks." -Level "INFO"
} elseif ($DryRun) {
    Write-Status "Dry run — skipping pre-checks and elevation" -Type Info
    Write-Log "Pre-check: dry run, skipping all pre-checks." -Level "INFO"
} else {
    # winget and WSL pre-checks are launched as background jobs so they run in parallel.
    # Both involve network/process calls (winget source update, GitHub API); running them
    # concurrently shaves several seconds off startup time.
    # npm prefix write-test is instant — runs inline while the jobs are in flight.
    $preWingetJob = $null
    $preWslJob    = $null

    if (-not $NoWinget -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        # ${Function:...} gives a ScriptBlock, but $using: serialises it to a string in the job.
        # Use [scriptblock]::Create() to reconstruct it on the other side.
        $fnWinget = ${Function:Test-WingetHasUpdates}.ToString()
        $preWingetJob = Start-Job -ScriptBlock {
            function Write-Status { param([string]$Message, [string]$Type = 'Info') }
            function Write-Log    { param([string]$Message, [string]$Level = 'INFO') }
            & ([scriptblock]::Create($using:fnWinget))
        }
    }

    # Only wsl --update needs elevation; apt-get does not.
    # Skip when -NoWsl or -OnlyWslPackages is set (wsl --update won't run anyway).
    if (-not $NoWsl -and -not $OnlyWslPackages -and (Get-Command wsl -ErrorAction SilentlyContinue)) {
        $fnWsl = ${Function:Test-WslHasUpdates}.ToString()
        $preWslJob = Start-Job -ScriptBlock {
            # Capture Write-Status calls so they can be replayed in the main runspace
            $wslMsgs = [System.Collections.Generic.List[hashtable]]::new()
            function Write-Status {
                param([string]$Message, [string]$Type = 'Info')
                $wslMsgs.Add(@{ Message = $Message; Type = $Type })
            }
            function Write-Log { param([string]$Message, [string]$Level = 'INFO') }
            $r = & ([scriptblock]::Create($using:fnWsl))
            [PSCustomObject]@{ Result = $r; Messages = $wslMsgs.ToArray() }
        }
    }

    if ($preWingetJob -or $preWslJob) {
        $preCheckNames = @()
        if ($preWingetJob) { $preCheckNames += 'winget' }
        if ($preWslJob)    { $preCheckNames += 'WSL' }
        Write-Status "Running $($preCheckNames -join ' + ') pre-checks in background..." -Type Action
    }

    # npm: prefix write-test runs inline (no network, no blocking) while the jobs are in flight
    if (-not $NoNpm -and -not $OnlyWsl -and -not $OnlyWslPackages -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Status "Pre-checking npm prefix writability..." -Type Action
        $npmPrefix = (& npm config get prefix 2>&1).Trim()
        $npmWriteTest = Join-Path $npmPrefix ".write-test-$([System.Guid]::NewGuid().ToString('N'))"
        $npmPrefixWritable = $false
        try {
            [System.IO.File]::WriteAllText($npmWriteTest, '')
            Remove-Item $npmWriteTest -ErrorAction SilentlyContinue
            $npmPrefixWritable = $true
        } catch { }

        if ($npmPrefixWritable) {
            Write-Status "npm: prefix writable — no elevation needed" -Type Success
            Write-Log "Pre-check: npm prefix writable, no elevation needed." -Level "INFO"
        } else {
            # Prefix is protected — only elevate if there are actual updates to install.
            # npm outdated -g --json exits 1 when outdated, 0 when current; always emits JSON (empty {} = no updates).
            $npmOutdatedJson = & npm outdated -g --json 2>$null
            $npmOutdatedParsed = $npmOutdatedJson | ConvertFrom-Json -ErrorAction SilentlyContinue
            # An empty {} parses to a non-null PSCustomObject with no properties — that means no updates.
            $npmHasUpdates = $null -ne $npmOutdatedParsed -and
                ($npmOutdatedParsed | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue).Count -gt 0
            if ($npmHasUpdates) {
                $npmNeedsElevation = $true
                Write-Status "npm: updates available + prefix '$npmPrefix' requires elevation" -Type Warning
                Write-Log "Pre-check: npm prefix '$npmPrefix' not writable and updates found — elevation needed." -Level "INFO"
            } else {
                Write-Status "npm: all packages up-to-date — no elevation needed" -Type Success
                Write-Log "Pre-check: npm prefix '$npmPrefix' not writable but no updates — no elevation needed." -Level "INFO"
            }
        }
    }

    # Collect background job results (jobs were running while npm check ran above)
    if ($preWingetJob) {
        $preWingetJob | Wait-Job | Out-Null
        $wingetNeedsElevation = [bool]($preWingetJob | Receive-Job)
        $preWingetJob | Remove-Job -Force
        if ($wingetNeedsElevation) {
            Write-Log "Pre-check: winget has updates — elevation needed." -Level "INFO"
        } else {
            Write-Status "Winget: all packages up-to-date — no elevation needed" -Type Success
            Write-Log "Pre-check: winget up-to-date, no elevation needed." -Level "INFO"
        }
    }

    if ($preWslJob) {
        $preWslJob | Wait-Job | Out-Null
        $wslJobResult = $preWslJob | Receive-Job
        $preWslJob | Remove-Job -Force
        # Replay status messages captured inside the job (version strings, warnings)
        if ($wslJobResult -and $wslJobResult.Messages) {
            foreach ($wslMsg in $wslJobResult.Messages) {
                Write-Status $wslMsg.Message -Type $wslMsg.Type
            }
        }
        $wslNeedsElevation = if ($wslJobResult) { [bool]$wslJobResult.Result } else { $false }
        if ($wslNeedsElevation) {
            Write-Log "Pre-check: WSL kernel has updates — elevation needed." -Level "INFO"
        } else {
            Write-Log "Pre-check: WSL kernel up-to-date, no elevation needed." -Level "INFO"
        }
    }
}

# Compute admin status once; used later by the WSL section to gate wsl --update.
$myWindowsID        = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole          = [System.Security.Principal.WindowsBuiltInRole]::Administrator
$script:isAdmin     = $myWindowsPrincipal.IsInRole($adminRole)

if (-not $DryRun -and ($Sudo -or $wingetNeedsElevation -or $wslNeedsElevation -or $npmNeedsElevation)) {
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
        $elevationReasons = @()
        if ($Sudo)                { $elevationReasons += '-Sudo flag' }
        if ($wingetNeedsElevation){ $elevationReasons += 'winget updates' }
        if ($wslNeedsElevation)   { $elevationReasons += 'WSL kernel update' }
        if ($npmNeedsElevation)   { $elevationReasons += 'npm updates' }
        Write-Log "Elevation required ($($elevationReasons -join ', ')) — re-launching as administrator." -Level "INFO"
        $sudoExists = Get-Command sudo -ErrorAction SilentlyContinue
        if ($sudoExists) {
            # Use the new Windows 'sudo' to re-launch.
            Write-Host "Administrator privileges are required. Re-launching with 'sudo'..." -ForegroundColor Yellow
            & sudo $psExe -ExecutionPolicy Bypass -File $MyInvocation.MyCommand.Definition @argArray
            exit
        } else {
            # Fallback to the traditional self-elevation method.
            Write-Host "Administrator privileges are required. Re-launching as administrator..." -ForegroundColor Yellow
            # Build a properly-quoted string for the runas path (sudo path uses @argArray directly).
            $argStrParts = @()
            foreach ($key in $PSBoundParameters.Keys) {
                $val = $PSBoundParameters[$key]
                if ($val -is [switch]) {
                    if ($val) { $argStrParts += "-$key" }
                } else {
                    $argStrParts += "-$key `"$val`""
                }
            }
            $argStr = $argStrParts -join ' '
            $newProcess = New-Object System.Diagnostics.ProcessStartInfo $psExe
            $newProcess.Arguments = "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`" $argStr"
            $newProcess.Verb = "runas"
            [System.Diagnostics.Process]::Start($newProcess)
            exit
        }
    }
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
$sectionKeys = "Scoop", "Winget", "Chocolatey",
              "PowerShell Modules", "Oh My Posh",
              "WSL",
              "npm", "pnpm", "Bun", "Deno",
              "Conda", "pipx", "uv", "Poetry", "Rye",
              ".NET Global Tools", "Rust", "Ruby Gems", "Composer",
              "Google Cloud SDK", "Android SDK", "Helm plugins", "krew plugins",
              "VS Code Extensions", "GitHub CLI Extensions",
              "TeX Live"
$updatedItems = @{}
$failedItems  = @{}
foreach ($k in $sectionKeys) {
    $updatedItems[$k] = @()
    $failedItems[$k]  = @()
}
$skippedSections      = @()
$script:sectionTimings = @{}   # SectionName → TimeSpan (populated by Update-Section)

# ══════════════════════════════════════════════════════
# PACKAGE MANAGERS  (update foundations first)
# ══════════════════════════════════════════════════════
Write-GroupHeader "Package Managers"

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
            Write-Log "Scoop: $($outdatedApps.Count) outdated: $($outdatedApps -join ', ')" -Level "INFO"
            $updatedItems["Scoop"] += $outdatedApps
        } else {
            Write-Status "All packages up-to-date" -Type Success
            Write-Log "Scoop: all packages up-to-date." -Level "INFO"
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
        if ($LASTEXITCODE -ne 0) {
            Write-Status "scoop cleanup failed (exit $LASTEXITCODE)" -Type Warning
            $failedItems["Scoop"] += "scoop cleanup (Exit Code: $LASTEXITCODE)"
        }
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
            # Winget may emit progress lines before the table; find the real header.
            # Same robust approach as Test-WingetHasUpdates.
            $headerLine = $lines | Where-Object { $_ -match '\bId\b' -and $_ -match '\bVersion\b' } |
                                   Select-Object -First 1
            if ($headerLine) {
                $idColIndex      = $headerLine.IndexOf('Id')
                $versionColIndex = $headerLine.IndexOf('Version')
                $headerIdx       = [Array]::IndexOf($lines, $headerLine)

                if ($idColIndex -ge 0 -and $versionColIndex -gt $idColIndex) {
                    for ($i = $headerIdx + 2; $i -lt $lines.Length; $i++) {
                        $line = $lines[$i]
                        if ($line.Trim().Length -eq 0)  { continue }
                        if ($line -match '\bPinned\b')  { continue }
                        if ($line -match '^\s*-+\s*$')  { continue }  # separator row
                        if ($line.Length -le $versionColIndex) { continue }  # bounds guard
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
            Write-Log "Winget: $($upgradablePackages.Count) upgradable: $($upgradablePackages -join ', ')" -Level "INFO"
            $updatedItems["Winget"] += $upgradablePackages
        } else {
            Write-Status "All packages up-to-date" -Type Success
            Write-Log "Winget: all packages up-to-date." -Level "INFO"
        }

        Write-Status "Refreshing winget sources..." -Type Action
        & winget source update
        if ($LASTEXITCODE -ne 0) {
            Write-Status "winget source update failed (exit $LASTEXITCODE) — package list may be stale" -Type Warning
            Write-Log "winget source update exited $LASTEXITCODE" -Level "WARN"
        }

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

# ══════════════════════════════════════════════════════
# SHELL / TERMINAL
# ══════════════════════════════════════════════════════
Write-GroupHeader "Shell / Terminal"

# --- Update PowerShell Modules ---
Update-Section "PowerShell Modules" ($NoPowerShell -or $OnlyWsl -or $OnlyWslPackages) { $true } {
    Write-Status "Retrieving installed modules..." -Type Action
    Write-Log "Retrieving installed modules."
    $installedModules = Get-InstalledModule
    Write-Status "Found $($installedModules.Count) modules to check" -Type Info

    # Batch-check latest versions from PSGallery — skip modules already at latest
    Write-Status "Checking PSGallery for available updates..." -Type Action
    $latestInGallery = @{}
    try {
        Find-Module -Name ($installedModules.Name) -ErrorAction SilentlyContinue |
            ForEach-Object { $latestInGallery[$_.Name] = $_.Version }
    } catch {}
    $modulesToUpdate = @($installedModules | Where-Object {
        $latest = $latestInGallery[$_.Name]
        $latest -and ([version]$latest -gt [version]$_.Version)
    })
    if ($modulesToUpdate.Count -eq 0) {
        Write-Status "All $($installedModules.Count) modules already at latest version" -Type Success
        return
    }
    Write-Status "$($modulesToUpdate.Count) of $($installedModules.Count) modules have updates available" -Type Info

    # Update modules sequentially (Update-Module isn't parallel-safe on shared module store).
    # When a module is detected as in-use, immediately launch a subprocess so it runs in
    # parallel with any remaining sequential Update-Module calls.
    $psExe   = (Get-Process -Id $PID).MainModule.FileName
    $subprocs = [System.Collections.Generic.List[PSCustomObject]]::new()
    $progress = 0
    foreach ($module in $modulesToUpdate) {
        Write-Progress -Activity "Updating PowerShell Modules" -Status "Updating $($module.Name)" -PercentComplete (($progress / $modulesToUpdate.Count) * 100)
        try {
            Write-Log "Updating module: $($module.Name)"
            $warnMsgs = @()
            Update-Module -Name $module.Name -Force -ErrorAction Stop -WarningVariable warnMsgs -WarningAction SilentlyContinue
            if ($warnMsgs | Where-Object { $_.Message -like "*currently in use*" }) {
                Write-Status "In use: $($module.Name) — starting subprocess..." -Type Warning
                Write-Log "Module $($module.Name) is in use — spawning subprocess." -Level "INFO"
                $tmpScript = Join-Path $env:TEMP "$([System.Guid]::NewGuid().ToString()).ps1"
                $safeName  = $module.Name -replace "'", "''"
                Set-Content $tmpScript -Encoding UTF8 -Value "Update-Module -Name '$safeName' -Force -ErrorAction Stop"
                $subprocs.Add([PSCustomObject]@{
                    Name      = $module.Name
                    TmpScript = $tmpScript
                    Process   = Start-Process $psExe `
                        -ArgumentList "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", $tmpScript `
                        -PassThru -WindowStyle Hidden
                })
            } else {
                $updatedItems["PowerShell Modules"] += $module.Name
                Write-Log "Successfully updated module: $($module.Name)"
            }
        } catch {
            Write-Status "Failed: $($module.Name) - $_" -Type Error
            Write-Log "Failed to update module: $($module.Name). Error: $_" -Level "ERROR"
            $failedItems["PowerShell Modules"] += "$($module.Name) - $($_.Exception.Message)"
        }
        $progress++
    }
    Write-Progress -Activity "Updating PowerShell Modules" -Completed

    # Wait for any in-use subprocesses (already running since they were launched during the loop)
    if ($subprocs.Count -gt 0) {
        Write-Status "Waiting for $($subprocs.Count) in-use subprocess(es)..." -Type Action
        foreach ($sp in $subprocs) {
            $sp.Process.WaitForExit()
            Remove-Item $sp.TmpScript -ErrorAction SilentlyContinue
            if ($sp.Process.ExitCode -eq 0) {
                Write-Status "Updated via subprocess: $($sp.Name)" -Type Success
                $updatedItems["PowerShell Modules"] += $sp.Name
                Write-Log "Successfully updated module via subprocess: $($sp.Name)"
            } else {
                Write-Status "Subprocess update failed: $($sp.Name) (exit $($sp.Process.ExitCode))" -Type Warning
                Write-Log "Subprocess update failed for $($sp.Name), exit $($sp.Process.ExitCode)" -Level "INFO"
                $failedItems["PowerShell Modules"] += "$($sp.Name) (subprocess failed)"
            }
        }
    }
}

# --- Update Oh My Posh ---
Update-Section "Oh My Posh" ($NoOhMyPosh -or $OnlyWsl -or $OnlyWslPackages) { Get-Command oh-my-posh -ErrorAction SilentlyContinue } {
    Invoke-SelfUpdate -ToolName "Oh My Posh" -Key "Oh My Posh" `
        -Action { & oh-my-posh upgrade 2>&1 | Out-Null } -ActionName "oh-my-posh upgrade"
}

# ══════════════════════════════════════════════════════
# SYSTEM
# ══════════════════════════════════════════════════════
Write-GroupHeader "System"

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
            $shutdownOk = Invoke-WithRetry -Action { & wsl --shutdown } -ActionName "wsl --shutdown" -MaxRetries 0
            if (-not $shutdownOk) {
                Write-Status "wsl --shutdown failed — package updates may not apply correctly" -Type Warning
            }
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
            $linuxUser = (& wsl.exe whoami 2>$null | Select-Object -First 1).Trim()
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
        if ($LASTEXITCODE -ne 0) {
            Write-Status "apt-get update failed (exit $LASTEXITCODE)" -Type Error
            $failedItems["WSL"] += "apt-get update failed"
        } else {
            & wsl.exe sudo apt-get full-upgrade -y
            if ($LASTEXITCODE -eq 0) {
                $updatedItems["WSL"] += "Updated packages in default WSL distro"
                $autoremoveOut = & wsl.exe sudo apt-get autoremove -y 2>&1
                $autoremoveExitCode = $LASTEXITCODE
                $autoremoveOut | ForEach-Object { Write-Log "  [autoremove] $_" -Level "DEBUG" }
                if ($autoremoveExitCode -ne 0) {
                    Write-Status "apt-get autoremove failed (exit $autoremoveExitCode)" -Type Warning
                    Write-Log "apt-get autoremove exited $autoremoveExitCode" -Level "WARN"
                }
            } else {
                Write-Status "apt-get full-upgrade failed (exit $LASTEXITCODE)" -Type Error
                $failedItems["WSL"] += "apt-get full-upgrade failed"
            }
        }
    }
}

# ══════════════════════════════════════════════════════
# JAVASCRIPT ECOSYSTEM
# ══════════════════════════════════════════════════════
Write-GroupHeader "JavaScript"

# --- Update npm Packages ---
Update-Section "npm (Node Package Manager) Packages" ($NoNpm -or $OnlyWsl -or $OnlyWslPackages) { Get-Command npm -ErrorAction SilentlyContinue } {
    Write-Status "Checking for outdated global packages..." -Type Action
    $outdatedNpmJson = & npm outdated -g --json 2>$null
    # npm outdated exits 1 when packages ARE outdated (by design) — not an error condition.
    # We parse JSON regardless of exit code.
    $npmOutdated = $null
    try { $npmOutdated = $outdatedNpmJson | ConvertFrom-Json -ErrorAction Stop } catch {}
    $npmToUpdate = if ($npmOutdated) { @($npmOutdated.PSObject.Properties.Name) } else { @() }

    if ($npmToUpdate.Count -eq 0) {
        Write-Status "All global packages up-to-date" -Type Success
        Write-Log "npm: all global packages up-to-date." -Level "INFO"
        return
    }

    Write-Status "Found $($npmToUpdate.Count) outdated: $($npmToUpdate -join ', ')" -Type Info
    Write-Log "npm: $($npmToUpdate.Count) outdated: $($npmToUpdate -join ', ')" -Level "INFO"

    # Verify npm's global prefix is writable — EPERM (-4048) is non-retryable, skip early
    $npmPrefix = (& npm config get prefix 2>&1).Trim()
    $npmWriteTest = Join-Path $npmPrefix ".write-test-$([System.Guid]::NewGuid().ToString('N'))"
    $npmWritable = $false
    try {
        [System.IO.File]::WriteAllText($npmWriteTest, '')
        Remove-Item $npmWriteTest -ErrorAction SilentlyContinue
        $npmWritable = $true
    } catch { }
    if (-not $npmWritable) {
        Write-Status "npm prefix '$npmPrefix' is not writable — run as Administrator to update npm" -Type Warning
        Write-Log "npm: prefix '$npmPrefix' not writable — skipping updates." -Level "WARN"
        $script:skippedSections += "npm (prefix not writable, needs elevation)"
        return
    }

    Write-Status "Updating npm itself..." -Type Action
    if (-not (Invoke-WithRetry -Action { & npm install -g npm } -ActionName "npm install -g npm")) {
        Write-Status "npm self-update failed" -Type Warning
        $failedItems["npm"] += "npm install -g npm (failed after retries)"
    }

    Write-Status "Updating all global packages..." -Type Action
    if (Invoke-WithRetry -Action { & npm update -g } -ActionName "npm update -g") {
        $updatedItems["npm"] += $npmToUpdate
    } else {
        Write-Status "npm update -g failed after retries" -Type Error
        $failedItems["npm"] += "npm update -g (failed after retries)"
    }
}

# --- Update pnpm ---
Update-Section "pnpm" ($NoPnpm -or $OnlyWsl -or $OnlyWslPackages) { Get-Command pnpm -ErrorAction SilentlyContinue } {
    Invoke-SelfUpdate -ToolName "pnpm" -Key "pnpm" -Action { & pnpm self-update 2>&1 | Out-Null }
}

# --- Update Bun ---
Update-Section "Bun" ($NoBun -or $OnlyWsl -or $OnlyWslPackages) { Get-Command bun -ErrorAction SilentlyContinue } {
    Invoke-SelfUpdate -ToolName "Bun" -Key "Bun" `
        -Action { & bun upgrade 2>&1 | Out-Null } -ActionName "bun upgrade"
}

# --- Update Deno ---
Update-Section "Deno" ($NoDeno -or $OnlyWsl -or $OnlyWslPackages) { Get-Command deno -ErrorAction SilentlyContinue } {
    Invoke-SelfUpdate -ToolName "Deno" -Key "Deno" `
        -Action { & deno upgrade 2>&1 | Out-Null } -ActionName "deno upgrade"
}

# ══════════════════════════════════════════════════════
# PYTHON ECOSYSTEM
# ══════════════════════════════════════════════════════
Write-GroupHeader "Python"

# --- Update Miniconda ---
Update-Section "Miniconda and conda environments" ($NoConda -or $OnlyWsl -or $OnlyWslPackages) { Get-Command conda -ErrorAction SilentlyContinue } {
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

    # Enumerate all non-base environments and update each
    # Note: conda prints its env list to both stdout and stderr; use 2>$null to avoid duplicates.
    $condaEnvList = & conda env list 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Status "conda env list failed" -Type Error
        $failedItems["Conda"] += "conda env list (Exit Code: $LASTEXITCODE)"
    } else {
        $nonBaseEnvs = $condaEnvList |
            Where-Object { $_ -notmatch '^\s*#' -and $_ -match '^\S' -and $_ -notmatch '^base\s' } |
            ForEach-Object { ($_ -split '\s+')[0] } |
            Where-Object { $_ -and $_ -ne 'base' } |
            Select-Object -Unique
        if ($nonBaseEnvs) {
            foreach ($envName in $nonBaseEnvs) {
                Write-Status "Updating '$envName' environment..." -Type Action
                if (Invoke-WithRetry -Action { & conda update -n $envName --all -y } -ActionName "conda update -n $envName") {
                    $updatedItems["Conda"] += "Conda environment ($envName)"
                } else {
                    Write-Status "conda update -n $envName failed after retries" -Type Error
                    $failedItems["Conda"] += "conda update -n $envName (failed)"
                }
            }
        } else {
            Write-Status "No additional conda environments found" -Type Info
        }
    }

    # Ensure base environment activates automatically in new shells so tools
    # installed there (e.g. pipx) are available on PATH without manual activation.
    # Note: auto_activate_base was renamed to auto_activate in recent conda versions.
    Write-Status "Ensuring auto_activate is enabled..." -Type Action
    & conda config --set auto_activate true
    if ($LASTEXITCODE -ne 0) {
        Write-Status "conda config --set auto_activate failed (exit $LASTEXITCODE)" -Type Warning
        Write-Log "conda config --set auto_activate failed (exit $LASTEXITCODE)" -Level "WARN"
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

# --- Update uv ---
Update-Section "uv" ($NoUv -or $OnlyWsl -or $OnlyWslPackages) { Get-Command uv -ErrorAction SilentlyContinue } {
    Write-Status "Updating uv..." -Type Action
    & uv self update 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $updatedItems["uv"] += "uv"
    } elseif ($LASTEXITCODE -eq 2) {
        # Exit code 2 = uv managed by an external package manager (Scoop, pip, brew, etc.)
        # It will be updated by that manager — not a failure.
        Write-Status "uv is managed by another package manager — skipping self-update" -Type Skip
        Write-Log "uv self update skipped: managed externally (exit 2)." -Level "INFO"
        $script:skippedSections += "uv (managed by another package manager)"
    } else {
        Write-Status "uv self update failed (exit $LASTEXITCODE)" -Type Error
        $failedItems["uv"] += "uv self update (exit $LASTEXITCODE)"
    }
}

# --- Update Poetry ---
Update-Section "Poetry" ($NoPoetry -or $OnlyWsl -or $OnlyWslPackages) { Get-Command poetry -ErrorAction SilentlyContinue } {
    Invoke-SelfUpdate -ToolName "Poetry" -Key "Poetry" `
        -Action { & poetry self update 2>&1 | Out-Null } -ActionName "poetry self update"
}

# --- Update Rye ---
Update-Section "Rye" ($NoRye -or $OnlyWsl -or $OnlyWslPackages) { Get-Command rye -ErrorAction SilentlyContinue } {
    Invoke-SelfUpdate -ToolName "Rye" -Key "Rye" `
        -Action { & rye self update 2>&1 | Out-Null } -ActionName "rye self update"
}

# ══════════════════════════════════════════════════════
# OTHER LANGUAGES
# ══════════════════════════════════════════════════════
Write-GroupHeader "Other Languages"

# --- Update .NET Global Tools ---
Update-Section ".NET Global Tools" ($NoDotnet -or $OnlyWsl -or $OnlyWslPackages) { Get-Command dotnet -ErrorAction SilentlyContinue } {
    Write-Status "Listing installed .NET global tools..." -Type Action
    # 2>$null suppresses the SDK telemetry disclaimer that dotnet writes to stderr.
    # With 2>&1 those lines get mixed into the tool list and parsed as fake tool IDs.
    $toolListOut = & dotnet tool list -g 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Status "dotnet tool list failed (exit $LASTEXITCODE)" -Type Error
        $failedItems[".NET Global Tools"] += "dotnet tool list (Exit Code: $LASTEXITCODE)"
        return
    }
    # Skip the two header lines, then keep only lines whose first token looks like a
    # NuGet package ID (letter/digit start, contains at least one dot).
    $toolLines = $toolListOut | Select-Object -Skip 2 | Where-Object { $_ -match '\S' }
    if (-not $toolLines) {
        Write-Status "No .NET global tools installed" -Type Info
        return
    }
    $toolIds = $toolLines |
        ForEach-Object { ($_ -split '\s+')[0] } |
        Where-Object { $_ -match '^[A-Za-z0-9][A-Za-z0-9._-]*\.[A-Za-z0-9]' }

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-Status "Updating $($toolIds.Count) tool(s) in parallel..." -Type Action
        $results = $toolIds | ForEach-Object -Parallel {
            & dotnet tool update -g $_ 2>&1 | Out-Null
            [PSCustomObject]@{ Id = $_; ExitCode = $LASTEXITCODE }
        } -ThrottleLimit 4

        foreach ($r in $results) {
            if ($r.ExitCode -eq 0) {
                Write-Status "Updated: $($r.Id)" -Type Success
                $updatedItems[".NET Global Tools"] += $r.Id
            } else {
                Write-Status "Failed: $($r.Id)" -Type Error
                $failedItems[".NET Global Tools"] += $r.Id
            }
        }
    } else {
        foreach ($toolId in $toolIds) {
            Write-Status "Updating: $toolId..." -Type Action
            & dotnet tool update -g $toolId 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $updatedItems[".NET Global Tools"] += $toolId
            } else {
                $failedItems[".NET Global Tools"] += $toolId
            }
        }
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

# --- Update Composer ---
Update-Section "Composer" ($NoComposer -or $OnlyWsl -or $OnlyWslPackages) { Get-Command composer -ErrorAction SilentlyContinue } {
    Invoke-SelfUpdate -ToolName "Composer" -Key "Composer" -Action { & composer self-update 2>&1 | Out-Null }
}

# ══════════════════════════════════════════════════════
# CLOUD / DEVOPS
# ══════════════════════════════════════════════════════
Write-GroupHeader "Cloud / DevOps"

# --- Update Google Cloud SDK ---
Update-Section "Google Cloud SDK" ($NoGCloud -or $OnlyWsl -or $OnlyWslPackages) { Get-Command gcloud -ErrorAction SilentlyContinue } {
    Write-Status "Updating gcloud components..." -Type Action
    if (Invoke-WithRetry -Action { & gcloud components update --quiet 2>&1 | Out-Null } -ActionName "gcloud components update") {
        $updatedItems["Google Cloud SDK"] += "All components"
    } else {
        Write-Status "gcloud components update failed" -Type Error
        $failedItems["Google Cloud SDK"] += "gcloud components update failed"
    }
}

# --- Update Android SDK Components ---
Update-Section "Android SDK" ($NoAndroid -or $OnlyWsl -or $OnlyWslPackages) { Get-Command sdkmanager -ErrorAction SilentlyContinue } {
    # sdkmanager requires Java — skip gracefully if JAVA_HOME isn't set and java isn't in PATH
    if (-not (Get-Command java -ErrorAction SilentlyContinue) -and -not $env:JAVA_HOME) {
        Write-Status "Android SDK — Java not installed" -Type Skip
        $script:skippedSections += "Android SDK (Java not configured)"
        return
    }
    Write-Status "Updating Android SDK components..." -Type Action
    $sdkOut = & sdkmanager --update 2>&1
    $sdkOut | ForEach-Object { Write-Log "  [sdkmanager] $_" -Level "DEBUG" }
    if ($LASTEXITCODE -eq 0) {
        $updatedItems["Android SDK"] += "All SDK components"
    } else {
        Write-Status "sdkmanager --update failed (exit $LASTEXITCODE)" -Type Error
        $failedItems["Android SDK"] += "sdkmanager --update (Exit Code: $LASTEXITCODE)"
    }
}

# --- Update Helm plugins ---
Update-Section "Helm plugins" ($NoHelm -or $OnlyWsl -or $OnlyWslPackages) { Get-Command helm -ErrorAction SilentlyContinue } {
    Write-Status "Listing Helm plugins..." -Type Action
    $helmPluginLines = & helm plugin list 2>&1 | Select-Object -Skip 1 | Where-Object { $_ -match '\S' }
    if (-not $helmPluginLines) {
        Write-Status "No Helm plugins installed" -Type Info
        return
    }
    $pluginNames = $helmPluginLines | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ }
    Write-Status "Updating $($pluginNames.Count) plugin(s): $($pluginNames -join ', ')..." -Type Action
    foreach ($plugin in $pluginNames) {
        & helm plugin update $plugin 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $updatedItems["Helm plugins"] += $plugin
        } else {
            Write-Status "helm plugin update $plugin failed (exit $LASTEXITCODE)" -Type Error
            $failedItems["Helm plugins"] += "$plugin (Exit Code: $LASTEXITCODE)"
        }
    }
}

# --- Update krew plugins ---
Update-Section "krew plugins" ($NoKrew -or $OnlyWsl -or $OnlyWslPackages) { Get-Command kubectl -ErrorAction SilentlyContinue } {
    & kubectl krew version 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Status "krew plugins — krew not installed" -Type Skip
        $script:skippedSections += "krew plugins (krew not installed)"
        return
    }
    Write-Status "Upgrading krew plugins..." -Type Action
    if (Invoke-WithRetry -Action { & kubectl krew upgrade 2>&1 | Out-Null } -ActionName "kubectl krew upgrade") {
        $updatedItems["krew plugins"] += "All krew plugins"
    } else {
        Write-Status "kubectl krew upgrade failed" -Type Error
        $failedItems["krew plugins"] += "kubectl krew upgrade (failed)"
    }
}

# ══════════════════════════════════════════════════════
# DEV TOOLING
# ══════════════════════════════════════════════════════
Write-GroupHeader "Dev Tooling"

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
        $actuallyUpdated = @()

        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Write-Status "Updating $($validExtensions.Count) extensions (parallel, limit 6)..." -Type Info
            $results = $validExtensions | ForEach-Object -Parallel {
                $out = & code --install-extension $_ --force 2>&1
                [PSCustomObject]@{ Id = $_; Output = ($out -join ' '); ExitCode = $LASTEXITCODE }
            } -ThrottleLimit 6

            foreach ($r in $results) {
                if ($r.ExitCode -ne 0) {
                    Write-Status "Failed: $($r.Id)" -Type Error
                    $failedItems["VS Code Extensions"] += "$($r.Id) (Exit Code: $($r.ExitCode))"
                } elseif ($r.Output -like '*successfully installed*') {
                    Write-Status "Updated: $($r.Id)" -Type Success
                    $actuallyUpdated += $r.Id
                }
            }
        } else {
            Write-Status "Checking $($validExtensions.Count) extensions for updates..." -Type Info
            $progress = 0
            foreach ($extensionId in $validExtensions) {
                $progress++
                Write-Progress -Activity "Checking VS Code Extensions" -Status "$extensionId ($progress/$($validExtensions.Count))" -PercentComplete (($progress / $validExtensions.Count) * 100)
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
        }

        if ($actuallyUpdated.Count -gt 0) {
            Write-Status "$($actuallyUpdated.Count) extensions updated" -Type Success
            Write-Log "VS Code: $($actuallyUpdated.Count) updated: $($actuallyUpdated -join ', ')" -Level "INFO"
            $updatedItems["VS Code Extensions"] += $actuallyUpdated
        } else {
            Write-Status "All extensions already up-to-date" -Type Success
            Write-Log "VS Code: all $($validExtensions.Count) extensions up-to-date." -Level "INFO"
        }
    }
}

# --- Update GitHub CLI Extensions ---
Update-Section "GitHub CLI Extensions" ($NoGhExt -or $OnlyWsl -or $OnlyWslPackages) { Get-Command gh -ErrorAction SilentlyContinue } {
    & gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Status "gh not authenticated — run 'gh auth login' to enable extension updates" -Type Warning
        $script:skippedSections += "GitHub CLI Extensions (not authenticated)"
        return
    }
    $extList = & gh extension list 2>&1
    if (-not $extList -or ($extList | Select-String "no extensions installed" -Quiet)) {
        Write-Status "No GitHub CLI extensions installed" -Type Info
        return
    }
    Write-Status "Upgrading all GitHub CLI extensions..." -Type Action
    if (Invoke-WithRetry -Action { & gh extension upgrade --all } -ActionName "gh extension upgrade --all") {
        $updatedItems["GitHub CLI Extensions"] += "All extensions"
    } else {
        Write-Status "gh extension upgrade failed" -Type Error
        $failedItems["GitHub CLI Extensions"] += "gh extension upgrade failed"
    }
}

# ══════════════════════════════════════════════════════
# TYPESETTING
# ══════════════════════════════════════════════════════
Write-GroupHeader "Typesetting"

# --- Update TeX Live ---
Update-Section "TeX Live" ($NoTex -or $OnlyWsl -or $OnlyWslPackages) { Get-Command tlmgr -ErrorAction SilentlyContinue } {
    Write-Status "Updating tlmgr and all packages (30 min timeout)..." -Type Action
    # Run in a background job so we can enforce a timeout (tlmgr can hang indefinitely).
    $tl1 = Invoke-TlMgrUpdate
    $tl1.Lines | ForEach-Object { Write-Log "  [tlmgr] $_" -Level "DEBUG" }
    Write-TexLiveLog
    if ($tl1.ExitCode -eq -2) {
        Write-Status "tlmgr timed out after 30 min — run tlmgr manually" -Type Error
        $failedItems["TeX Live"] += "tlmgr update timed out (30 min limit)"
    } elseif ($tl1.Lines | Select-String "Cross release" -Quiet) {
        Write-Status "TeX Live cross-release: local version older than remote — attempting auto-upgrade..." -Type Warning
        Write-Log "TeX Live cross-release detected — downloading update-tlmgr-latest.exe." -Level "INFO"
        $updaterPath = "$env:TEMP\update-tlmgr-latest.exe"
        try {
            Invoke-WebRequest -Uri "https://mirror.ctan.org/systems/texlive/tlnet/update-tlmgr-latest.exe" `
                -OutFile $updaterPath -UseBasicParsing -ErrorAction Stop -TimeoutSec $script:DownloadTimeoutSec
            Write-Log "Downloaded update-tlmgr-latest.exe to $updaterPath." -Level "INFO"
            Write-Status "Running update-tlmgr-latest.exe --update..." -Type Action
            $updaterOutput   = & $updaterPath --update 2>&1
            $updaterExitCode = $LASTEXITCODE
            $updaterOutput | ForEach-Object { Write-Log "  [updater] $_" -Level "DEBUG" }
            Remove-Item $updaterPath -ErrorAction SilentlyContinue   # clean up temp file
            Write-TexLiveLog
            if ($updaterExitCode -eq 0) {
                Write-Log "update-tlmgr-latest.exe succeeded. Retrying tlmgr update." -Level "INFO"
                Write-Status "tlmgr upgraded — retrying full update (30 min timeout)..." -Type Action
                $tl2 = Invoke-TlMgrUpdate
                $tl2.Lines | ForEach-Object { Write-Log "  [tlmgr] $_" -Level "DEBUG" }
                Write-TexLiveLog
                if ($tl2.ExitCode -eq -2) {
                    Write-Status "tlmgr timed out after 30 min on retry — run tlmgr manually" -Type Error
                    $failedItems["TeX Live"] += "tlmgr update timed out on retry after cross-release upgrade"
                } elseif ($tl2.ExitCode -eq 0) {
                    Write-Log "tlmgr update succeeded after cross-release upgrade." -Level "INFO"
                    $updatedItems["TeX Live"] += "All packages (cross-release upgrade)"
                } else {
                    Write-Log "tlmgr update failed after cross-release upgrade (exit $($tl2.ExitCode))." -Level "ERROR"
                    Write-Status "tlmgr update failed after cross-release upgrade" -Type Error
                    $failedItems["TeX Live"] += "tlmgr update failed after cross-release upgrade"
                }
            } else {
                Write-Log "update-tlmgr-latest.exe failed (exit $updaterExitCode)." -Level "ERROR"
                Write-Status "update-tlmgr-latest.exe failed (exit $updaterExitCode)" -Type Error
                $failedItems["TeX Live"] += "update-tlmgr-latest.exe failed — run manually"
            }
        } catch {
            Write-Log "Failed to download update-tlmgr-latest.exe: $_" -Level "ERROR"
            Write-Status "Could not download updater: $_" -Type Error
            $failedItems["TeX Live"] += "Cross-release: download failed — run update-tlmgr-latest.exe --update manually"
        }
    } elseif ($tl1.ExitCode -eq 0) {
        if ($tl1.Lines | Select-String "no updates available" -Quiet -CaseSensitive:$false) {
            Write-Status "All packages already up-to-date" -Type Success
            Write-Log "TeX Live: no updates available." -Level "INFO"
        } else {
            $updatedItems["TeX Live"] += "All packages"
        }
    } else {
        Write-Status "tlmgr update failed (admin required?)" -Type Error
        $failedItems["TeX Live"] += "tlmgr update failed"
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

# Section timings — only show sections that took 5 s or more
$slowSections = $script:sectionTimings.GetEnumerator() |
    Where-Object { $_.Value.TotalSeconds -ge 5 } |
    Sort-Object { $_.Value } -Descending
if ($slowSections) {
    Write-Host ""
    Write-Host "  $([char]0x25CB)  Timings" -ForegroundColor DarkGray
    $slowSections | ForEach-Object {
        Write-Host "       $([char]0x2022) $($_.Key): $(Format-Elapsed $_.Value)" -ForegroundColor DarkGray
    }
}

# One-line stats
$updatedCount = ($updatedItems.Values | Where-Object { $_.Count -gt 0 }).Count
$failedCount  = ($failedItems.Values  | Where-Object { $_.Count -gt 0 }).Count
$skippedCount = $skippedSections.Count
Write-Host ""
Write-Host "  $([char]0x00B7)  $updatedCount updated  $([char]0x00B7)  $failedCount failed  $([char]0x00B7)  $skippedCount skipped" -ForegroundColor DarkGray

Write-Host ""
if ($hasFailures) {
    Write-Host "  $([char]0x2570)$([char]0x2500)  $([char]0x2717)  Completed with failures in $(Format-Elapsed $totalElapsed)  $([char]0x2500)$([char]0x256F)" -ForegroundColor Red
} else {
    Write-Host "  $([char]0x2570)$([char]0x2500)  $([char]0x2713)  All done in $(Format-Elapsed $totalElapsed)  $([char]0x2500)$([char]0x256F)" -ForegroundColor Green
}
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
