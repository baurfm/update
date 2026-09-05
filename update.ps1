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

.PARAMETER Only
    Run only sections whose name matches one of these strings (substring match, e.g.
    -Only npm,uv). All other sections are skipped silently. Combine with -NoSelfUpdate for a
    fast targeted run.

.PARAMETER Parallel
    Pre-launch independent, quick tool self-updates (Oh My Posh, pnpm, Bun, Deno, Poetry, Rye,
    Composer) as background jobs before the slower Package Manager / System / npm sections run,
    instead of running them strictly one after another. Purely an optimization — each section
    falls back to its normal retry-wrapped update if the background job hasn't finished or failed.

.PARAMETER OutputJson
    Write a machine-readable JSON summary of the run (counts, updated/failed/skipped items,
    exit code, duration) to this path after completion.

.PARAMETER LogFile
    Path to the log file. Default is 'update.log'.

.PARAMETER DryRun
    Show which tools are installed and would be updated, without executing any updates.
    Pre-checks and elevation are skipped; all sections show "dry run" in the output.

.PARAMETER RegisterSchedule
    Register the script as a Scheduled Task running with highest privileges, then exit.
    Combine with -ScheduleTime and -ScheduleFrequency. Re-running replaces the existing task.

.PARAMETER UnregisterSchedule
    Remove the Scheduled Task registered by -RegisterSchedule, then exit.

.PARAMETER Unattended
    Composite switch for headless runs (Scheduled Task / CI): silences prompts, enforces command
    timeouts, enables Event Log notification on failure, suppresses progress bars.

.PARAMETER Quiet
    Suppress the banner and most status output. Summary + failures still print.

.PARAMETER CmdTimeoutSec
    Hard timeout (seconds) applied to each external command via Invoke-WithRetry.
    0 disables. Default: 0 (on) / 600 (when -Unattended).

.PARAMETER AutoReboot
    Reboot automatically if the script detects a pending reboot at the end of the run.

.PARAMETER NotifyToast
    Show a Windows Toast notification after the run (installs BurntToast from PSGallery on first use).

.PARAMETER NotifyWebhook
    POST a JSON summary to the given URL (ntfy.sh, Discord, Slack, etc.) after the run.

.PARAMETER NotifyEventLog
    Write the run result into the Windows Event Log under source 'UpdateScript'.

.PARAMETER NotifyOn
    Controls when notifications fire: Always, Failure (default), or Never.

.PARAMETER SkipNetworkCheck
    Skip the network reachability pre-check at startup.

.EXAMPLE
    .\update.ps1

    Runs all update tasks.

.EXAMPLE
    .\update.ps1 -NoTex

    Runs all update tasks EXCEPT for TeX Live.

.EXAMPLE
    .\update.ps1 -h

    Displays this help message without running any updates.

.EXAMPLE
    Get-Help .\update.ps1 -Full

    Displays this help message using the built-in PowerShell help system.

.EXAMPLE
    .\update.ps1 -Verbose -LogFile "myupdate.log"

    Runs updates with verbose output and logs to 'myupdate.log'.

.EXAMPLE
    .\update.ps1 -OnlyWslPackages

    Updates only the WSL packages (apt-get), skipping WSL kernel and other sections.

.EXAMPLE
    .\update.ps1 -RegisterSchedule -ScheduleTime "03:00"

    Registers a daily Scheduled Task that runs the script unattended at 03:00 with admin rights.

.EXAMPLE
    .\update.ps1 -Unattended -NotifyWebhook "https://ntfy.sh/my-topic"

    Runs fully unattended: prompts silenced, strict timeouts, summary pushed to the given webhook.

.NOTES
    Author: Your Name
    Date: 2026-09-05
    Version: 12.13
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Display this help message.")]
    [Alias('h', '?')]
    [switch]$Help,

    [switch]$NoPowerShell,
    [switch]$NoScoop,
    [switch]$NoWinget,
    [switch]$NoVsCode,
    [switch]$NoTex,
    [switch]$NoWsl,
    [switch]$NoNpm,
    [switch]$NoPipx,
    [switch]$NoRust,
    [switch]$NoGem,
    [switch]$NoChoco,
    [switch]$NoGCloud,
    [switch]$NoAzureCli,    # Skip Azure CLI (az upgrade)
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
    [switch]$RemoveFromPath, # Remove update.cmd shim and strip script dir from User PATH, then exit
    [switch]$OnlyWsl,
    [switch]$OnlyWslPackages,

    # Internal: set automatically when the script re-launches itself elevated (see the
    # Administrator Elevation Check below). The parent process already showed the banner,
    # ran the self-update check and the elevation pre-checks — redoing all of that in the
    # elevated child would just print everything twice. Not meant to be passed manually.
    [switch]$Elevated,

    [Parameter(HelpMessage = "Run only sections whose name matches one of these (substring match, e.g. -Only npm,uv). All other sections are skipped.")]
    [string[]]$Only,

    [Parameter(HelpMessage = "Run independent, quick tool self-updates (Oh My Posh, pnpm, Bun, Deno, Poetry, Rye, Composer) as background jobs pre-launched before the slower sections, instead of one after another.")]
    [switch]$Parallel,

    [Parameter(HelpMessage = "Write a machine-readable JSON summary of the run to this path after completion.")]
    [string]$OutputJson,

    [Parameter(HelpMessage = "If set, skip any automatic configuration of WSL sudo (passwordless apt-get).")]
    [switch]$SkipWslSudoConfig,

    [Parameter(HelpMessage = "Path to log file. Defaults to 'logs/update.log' under script directory.")]
    [string]$LogFile = "update.log",

    # ── Unattended / Scheduling ─────────────────────────────────────────────
    [Parameter(HelpMessage = "Register as a Scheduled Task running with highest privileges, then exit.")]
    [switch]$RegisterSchedule,
    [Parameter(HelpMessage = "Remove the Scheduled Task registered by -RegisterSchedule, then exit.")]
    [switch]$UnregisterSchedule,
    [Parameter(HelpMessage = "Time of day for the Scheduled Task in HH:mm 24h format. Default: 03:00.")]
    [string]$ScheduleTime = '03:00',
    [Parameter(HelpMessage = "Scheduled-Task frequency.")]
    [ValidateSet('Daily','Weekly')]
    [string]$ScheduleFrequency = 'Daily',

    [Parameter(HelpMessage = "Composite flag: silence prompts + strict timeouts + notify on failure. Ideal for Scheduled Task runs.")]
    [switch]$Unattended,
    [Parameter(HelpMessage = "Suppress the banner and all non-essential terminal output; summary + failures remain.")]
    [switch]$Quiet,
    [Parameter(HelpMessage = "Do not acquire an exclusive lock — allow overlapping runs (dangerous).")]
    [switch]$NoLock,
    [Parameter(HelpMessage = "Hard per-external-command timeout in seconds. 0 disables. Default: 600.")]
    [int]$CmdTimeoutSec = 0,
    [Parameter(HelpMessage = "Skip the network reachability pre-check.")]
    [switch]$SkipNetworkCheck,

    [Parameter(HelpMessage = "Reboot automatically if a pending reboot is detected at the end of the run.")]
    [switch]$AutoReboot,

    # ── Notifications ────────────────────────────────────────────────────────
    [Parameter(HelpMessage = "Show a BurntToast notification after the run. Requires BurntToast module.")]
    [switch]$NotifyToast,
    [Parameter(HelpMessage = "POST a JSON summary to this URL after the run (ntfy.sh, Discord, Slack, etc.).")]
    [string]$NotifyWebhook,
    [Parameter(HelpMessage = "Write the run result into the Windows Event Log (source: UpdateScript).")]
    [switch]$NotifyEventLog,
    [Parameter(HelpMessage = "When to send notifications: Always, Failure, Never. Default: Failure.")]
    [ValidateSet('Always','Failure','Never')]
    [string]$NotifyOn = 'Failure'
)

# -Help/-h/-? exits immediately, before the lock/network/self-update/elevation-pre-check
# machinery below — none of that should run (or risk triggering a UAC prompt) just to print
# the help text.
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}

# ── Configurable constants ─────────────────────────────────────────────────
$script:TexLiveTimeoutSec  = 1800   # max seconds to wait for tlmgr (30 min)
$script:TexLiveLogAgeMins  = 10     # minutes back to scan for TeX Live log files
$script:DownloadTimeoutSec = 120    # seconds for Invoke-WebRequest calls
$script:DiskSpaceWarnGB    = 2      # GB free on C: below which to warn
$script:LogArchiveCount    = 30     # number of archived log files to keep (headroom for unattended daily runs)
$script:EventLogSource     = 'UpdateScript'
$script:ScheduledTaskName  = 'UpdateScript-Daily'
$script:NetCheckHosts      = @('github.com','registry.npmjs.org','ghcr.io')
$script:NetCheckTimeoutSec = 5

# ── Exit codes ─────────────────────────────────────────────────────────────
# Consumed by Scheduled-Task history, wrappers, and monitoring.
$script:ExitOk             = 0   # everything updated cleanly
$script:ExitPartial        = 1   # some sections failed but majority succeeded
$script:ExitHardFailure    = 2   # >=50% of attempted sections failed
$script:ExitElevationMissing = 3 # needed elevation but couldn't acquire it
$script:ExitLockActive     = 4   # another run already in progress
$script:ExitNetworkDown    = 5   # no network reachable
$script:ExitTimedOut       = 6   # wall-clock or per-section timeout hit
# ───────────────────────────────────────────────────────────────────────────

# ── Unattended composite flag — expands convenient defaults ────────────────
# Must run before any Write-Status / Write-Log so preferences are in place.
if ($Unattended) {
    if (-not $PSBoundParameters.ContainsKey('Quiet'))          { $Quiet          = $true }
    if (-not $PSBoundParameters.ContainsKey('NotifyEventLog')) { $NotifyEventLog = $true }
    if (-not $PSBoundParameters.ContainsKey('CmdTimeoutSec') -or $CmdTimeoutSec -eq 0) { $CmdTimeoutSec = 600 }
    if (-not $PSBoundParameters.ContainsKey('SkipWslSudoConfig')) { $SkipWslSudoConfig = $false }  # still want it
}

# Globale Preferences für Unattended-Betrieb — verhindert Prompts aus Tools/Cmdlets.
$ConfirmPreference     = 'None'
$ErrorActionPreference = 'Continue'
if ($Quiet -or $Unattended) { $ProgressPreference = 'SilentlyContinue' }

# Telemetry / update-check opt-outs — silent for unattended runs, harmless otherwise.
$env:POWERSHELL_UPDATECHECK       = 'Off'
$env:DOTNET_CLI_TELEMETRY_OPTOUT  = '1'
$env:NEXT_TELEMETRY_DISABLED      = '1'
$env:DO_NOT_TRACK                 = '1'
$env:PYTHONUTF8                   = '1'

$script:QuietMode      = [bool]$Quiet
$script:CmdTimeoutSec  = [int]$CmdTimeoutSec
$script:LockAcquired   = $false
$script:VersionString  = '12.13'
$script:OnlyFilter     = $Only
$script:parallelJobs   = @{}
$script:lastLineBlank  = $true   # avoids a spurious leading blank before the very first output

# Prints exactly one blank separator line — never two in a row, regardless of which combination
# of Write-GroupHeader / Write-SectionHeader / Update-Section / Write-Status calls precede it.
# Replaces the old pattern of headers hardcoding their own leading/trailing "Write-Host ''",
# which stacked into double blank lines wherever two of them met back to back.
function Write-BlankLine {
    if (-not $script:QuietMode -and -not $script:lastLineBlank) {
        Write-Host ""
        $script:lastLineBlank = $true
    }
}

# Helper: format a TimeSpan as "4m 12s" / "38s" / "1h 2m"
function Format-Elapsed {
    param([TimeSpan]$ts)
    if ($ts.TotalHours -ge 1)   { return "$([int]$ts.TotalHours)h $($ts.Minutes)m" }
    if ($ts.TotalMinutes -ge 1) { return "$([int]$ts.TotalMinutes)m $($ts.Seconds)s" }
    return "$([int]$ts.TotalSeconds)s"
}

# Draws a rounded box around one or more pre-formatted lines — mirrors the startup banner's style
# so the run visually "bookends" between an opening and a closing card. Lines longer than the box
# width are truncated defensively (should not normally happen; callers keep lines short).
function Write-ResultBox {
    param(
        [Parameter(Mandatory)] [string[]]$Lines,
        [string[]]$LineColors,
        [string]$BorderColor = 'DarkGray',
        [int]$Width = 0   # 0 = auto-fit to the longest line (clamped to [40, 78])
    )
    if ($script:QuietMode) { return }
    if ($Width -le 0) {
        $longest = ($Lines | ForEach-Object Length | Measure-Object -Maximum).Maximum
        $Width   = [Math]::Min(78, [Math]::Max(40, $longest + 4))
    }
    $bar = [char]0x2502
    Write-Host "  $([char]0x256D)$(([char]0x2500).ToString() * $Width)$([char]0x256E)" -ForegroundColor $BorderColor
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line  = $Lines[$i]
        $color = if ($LineColors -and $LineColors.Count -gt $i) { $LineColors[$i] } else { 'White' }
        if ($line.Length -gt $Width - 2) { $line = $line.Substring(0, $Width - 5) + '...' }
        Write-Host "  $bar " -NoNewline -ForegroundColor $BorderColor
        Write-Host $line -NoNewline -ForegroundColor $color
        Write-Host (" " * [Math]::Max(0, $Width - $line.Length - 1)) -NoNewline
        Write-Host "$bar" -ForegroundColor $BorderColor
    }
    Write-Host "  $([char]0x2570)$(([char]0x2500).ToString() * $Width)$([char]0x256F)" -ForegroundColor $BorderColor
}

# Helper: join an item list for the summary, truncated to $MaxShown with a "+N more" suffix.
# Full lists always remain in the log file — this only affects the terminal display.
function Format-SummaryLine {
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]]$Items,
        [int]$MaxShown = 8
    )
    $count = $Items.Count
    $text  = ($Items | Select-Object -First $MaxShown) -join ', '
    if ($count -gt $MaxShown) { $text += " (+$($count - $MaxShown) more)" }
    return $text
}

# Function to display a formatted section header (secondary level — within a group).
# Uses Write-BlankLine (not a hardcoded "Write-Host ''") for its leading/trailing spacing so it
# never stacks a double blank line with whatever printed immediately before or after it.
function Write-SectionHeader {
    param([string]$Title, [string]$Progress)
    if ($script:QuietMode) { return }
    Write-BlankLine
    Write-Host "  $([char]0x25B6)  " -NoNewline -ForegroundColor DarkCyan   # ▶
    if ($Progress) { Write-Host "[$Progress]  " -NoNewline -ForegroundColor DarkGray }
    Write-Host $Title -ForegroundColor Cyan
    $script:lastLineBlank = $false
    Write-BlankLine
}

# Function to display a group header (primary level — separates logical categories)
function Write-GroupHeader {
    param([string]$Title)
    if ($script:QuietMode) { return }
    $maxLen = 54   # 58-char rule minus 4 for the ▪ prefix — truncate if longer
    if ($Title.Length -gt $maxLen) { $Title = $Title.Substring(0, $maxLen - 3) + '...' }
    $line = ([char]0x2550).ToString() * 58   # ══════════ (double rule — visually heavier)
    Write-BlankLine
    Write-Host "  $line" -ForegroundColor DarkGray
    Write-Host "  $([char]0x25AA) " -NoNewline -ForegroundColor DarkYellow   # ▪
    Write-Host $Title -ForegroundColor Yellow
    $script:lastLineBlank = $false
    Write-BlankLine
}

# Function to display a status message with a consistent prefix.
#
# Verbosity tiers:
#   -Quiet            only Warning/Error survive (plus the summary, printed separately)
#   default           headers, Success/Skip/Warning/Error — the "what happened" level
#   -Verbose          adds Info/Action/Detail — the "what it's doing right now" blow-by-blow
# Info/Action/Detail are always in the log file regardless of tier (see Write-Log).
function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error", "Skip", "Action", "Detail")]
        [string]$Type = "Info"
    )
    # In quiet mode only surface failures and warnings — callers still call this freely.
    if ($script:QuietMode -and $Type -in @('Info','Skip','Action','Success','Detail')) { return }
    # Chatty per-step / per-item noise is verbose-only in the default (non-quiet) tier.
    if (-not $script:QuietMode -and $Type -in @('Info','Action','Detail') -and $VerbosePreference -eq 'SilentlyContinue') { return }
    switch ($Type) {
        "Info"    { Write-Host "  $([char]0x00B7)  $Message" -ForegroundColor DarkGray }  # ·
        "Success" { Write-Host "  $([char]0x2713)  $Message" -ForegroundColor Green }     # ✓
        "Warning" { Write-Host "  $([char]0x26A0)  $Message" -ForegroundColor Yellow }    # ⚠
        "Error"   { Write-Host "  $([char]0x2717)  $Message" -ForegroundColor Red }       # ✗
        "Skip"    { Write-Host "  $([char]0x25CB)  $Message" -ForegroundColor DarkGray }  # ○
        "Detail"  { Write-Host "  $([char]0x00B7)  $Message" -ForegroundColor DarkGray }  # · (verbose-only per-item detail)
        "Action"  {
            Write-Host "  $([char]0x2192)  " -NoNewline -ForegroundColor DarkCyan         # →
            Write-Host $Message -ForegroundColor White
        }
    }
    $script:lastLineBlank = $false
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
    if ($VerbosePreference -ne 'SilentlyContinue') {
        Write-Host $logMessage -ForegroundColor DarkGray
    } elseif ($Level -eq "WARN") {
        Write-Status $Message -Type Warning
    } elseif ($Level -eq "ERROR") {
        Write-Status $Message -Type Error
    }
    # INFO and DEBUG are silent in terminal unless -Verbose
}

# Shared -Only substring-match check, used both by Update-Section (to skip sections) and the
# elevation pre-check block (to avoid probing/elevating for a section -Only would filter out
# anyway — no point triggering a UAC prompt for winget when -Only excludes it).
function Test-SectionWanted {
    param([Parameter(Mandatory)] [string]$Name)
    if (-not $script:OnlyFilter -or $script:OnlyFilter.Count -eq 0) { return $true }
    foreach ($pattern in $script:OnlyFilter) {
        if ($Name -like "*$pattern*") { return $true }
    }
    return $false
}

# Same idea as Test-SectionWanted, but for a whole group header: true if -Only is unset, or at
# least one of the group's section names matches — avoids a wall of empty "═══ Group ═══"
# headers with nothing under them when -Only narrows the run down to one or two sections.
function Test-GroupWanted {
    param([Parameter(Mandatory)] [string[]]$SectionNames)
    if (-not $script:OnlyFilter -or $script:OnlyFilter.Count -eq 0) { return $true }
    foreach ($name in $SectionNames) {
        if (Test-SectionWanted -Name $name) { return $true }
    }
    return $false
}

# Function to handle common update section logic
function Update-Section {
    param(
        [string]$SectionName,
        [bool]$SkipCondition,
        [scriptblock]$ToolCheck,
        [scriptblock]$UpdateAction
    )

    $script:sectionIndex++
    $progress = if ($script:totalSections) { "$($script:sectionIndex)/$($script:totalSections)" } else { $null }

    # -Only filters the whole run down to sections whose name contains one of the given
    # substrings. Silent skip (log only) — a wall of "skipped" lines for everything not
    # requested would defeat the point of a targeted run.
    if (-not (Test-SectionWanted -Name $SectionName)) {
        Write-Log "Skipping $SectionName — not matched by -Only filter." -Level "DEBUG"
        return
    }

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

    Write-SectionHeader "Updating $SectionName" -Progress $progress
    Write-Log "Starting $SectionName updates."

    $sectionStart = Get-Date
    try {
        & $UpdateAction
        $elapsed = (Get-Date) - $sectionStart
        $script:sectionTimings[$SectionName] = $elapsed
        Write-Status "Done  $(Format-Elapsed $elapsed)" -Type Success
        Write-Log "$SectionName updates completed in $(Format-Elapsed $elapsed)."
    } catch {
        if ($_.Exception -is [System.Management.Automation.PipelineStoppedException]) { throw }
        $elapsed = (Get-Date) - $sectionStart
        $script:sectionTimings[$SectionName] = $elapsed
        Write-Status "Failed after $(Format-Elapsed $elapsed): $_" -Type Error
        Write-Log "Error during $SectionName updates: $_ [$(Format-Elapsed $elapsed)]" -Level "ERROR"
    }
    Write-BlankLine   # separates this section from whatever prints next (section or group header)
}

# Runs a native command scriptblock, capturing its stdout+stderr instead of letting it print
# straight to the console: always fully logged, but only echoed live to the terminal in the
# default tier when -Verbose is on. Sets $LASTEXITCODE as usual (reflects the last native exe
# run inside $Command, unaffected by capturing its output into a variable).
function Invoke-NativeCapture {
    param(
        [Parameter(Mandatory)] [scriptblock]$Command,
        [Parameter(Mandatory)] [string]$LogTag
    )
    # *>&1 (not 2>&1): PowerShell-based tools like scoop write via Write-Host, which lands on the
    # Information stream — 2>&1 only merges stderr and would let that chatter leak through anyway.
    $out = & $Command *>&1
    if ($out) {
        $out | ForEach-Object { Write-Log "  [$LogTag] $_" -Level "DEBUG" }
        if ($VerbosePreference -ne 'SilentlyContinue') {
            $out | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
        }
    }
}

# Function to execute a command with retry logic.
# When TimeoutSec > 0 (or -CmdTimeoutSec is set globally for unattended runs), the action runs in
# a background job and is killed if it exceeds the timeout — a timed-out attempt counts as a
# failure and is retried like any other failure up to MaxRetries.
function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,
        [Parameter(Mandatory = $true)]
        [string]$ActionName,
        [int]$MaxRetries = 2,
        [int]$DelaySeconds = 5,
        [int]$TimeoutSec = 0
    )
    # Inherit global default from -CmdTimeoutSec / -Unattended when caller didn't set one.
    if ($TimeoutSec -le 0 -and $script:CmdTimeoutSec -gt 0) { $TimeoutSec = $script:CmdTimeoutSec }

    $attempt = 0
    $maxAttempts = $MaxRetries + 1
    do {
        $attempt++
        Write-Log "Executing $ActionName (attempt $attempt of $maxAttempts$( if ($TimeoutSec -gt 0) { ", timeout ${TimeoutSec}s" } ))" -Level "DEBUG"
        try {
            if ($TimeoutSec -gt 0) {
                $r = Invoke-WithTimeout -Action $Action -TimeoutSec $TimeoutSec
                if ($r.Output) { $r.Output | ForEach-Object { Write-Log "  [$ActionName] $_" -Level "DEBUG" } }
                if ($r.TimedOut) {
                    Write-Status "$ActionName timed out after ${TimeoutSec}s" -Type Warning
                    Write-Log "$ActionName timed out after ${TimeoutSec}s (attempt $attempt)" -Level "INFO"
                } elseif ($r.Error) {
                    Write-Log "$ActionName threw (attempt $attempt): $($r.Error)" -Level "WARN"
                } elseif ($r.ExitCode -eq 0) {
                    Write-Log "$ActionName succeeded." -Level "INFO"
                    return $true
                } else {
                    Write-Log "$ActionName failed with exit code $($r.ExitCode) (attempt $attempt)" -Level "WARN"
                }
            } else {
                Invoke-NativeCapture -Command $Action -LogTag $ActionName
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "$ActionName succeeded." -Level "INFO"
                    return $true
                } else {
                    Write-Log "$ActionName failed with exit code $LASTEXITCODE (attempt $attempt)" -Level "WARN"
                }
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

# Helper: like Invoke-SelfUpdate, but first checks for a -Parallel prefetch job (started early via
# Start-ParallelPrefetch, overlapping with the much slower Scoop/Winget/WSL/npm sections that run
# before these independent leaf tools). Uses the job's result if it landed and succeeded; otherwise
# falls back to the normal sequential retry-wrapped path — identical behavior to Invoke-SelfUpdate
# when -Parallel wasn't requested or the prefetch didn't pan out. Can only help, never hurt.
function Invoke-SelfUpdateWithPrefetch {
    param(
        [Parameter(Mandatory)] [string]$ToolName,
        [Parameter(Mandatory)] [string]$Key,
        [Parameter(Mandatory)] [scriptblock]$Action,
        [string]$ActionName
    )
    if (-not $ActionName) { $ActionName = "$ToolName self-update" }
    if ($script:parallelJobs.ContainsKey($Key)) {
        $job = $script:parallelJobs[$Key]
        $script:parallelJobs.Remove($Key)
        Write-Status "Updating $ToolName..." -Type Action
        $done = $job | Wait-Job -Timeout 90
        $result = if ($done) { $job | Receive-Job -ErrorAction SilentlyContinue } else { $null }
        $job | Stop-Job -ErrorAction SilentlyContinue
        $job | Remove-Job -Force -ErrorAction SilentlyContinue
        if ($result -and $result.ExitCode -eq 0) {
            Write-Log "$ActionName succeeded (prefetched in parallel)." -Level "INFO"
            $updatedItems[$Key] += $ToolName
            return
        }
        Write-Log "$ActionName prefetch missed or failed (exit $($result.ExitCode)) — falling back to sequential retry." -Level "INFO"
    }
    Invoke-SelfUpdate -ToolName $ToolName -Key $Key -Action $Action -ActionName $ActionName
}

# Launches independent, quick tool self-updates as background jobs before the (much slower)
# Package Managers / System / npm sections run. By the time each tool's own section is reached
# later in the normal sequential order, its job has usually already finished — see
# Invoke-SelfUpdateWithPrefetch. Only used when -Parallel is passed; a no-op otherwise.
function Start-ParallelPrefetch {
    $specs = [ordered]@{
        'Oh My Posh' = @{ Cmd = { oh-my-posh upgrade *>&1 | Out-Null }; Tool = 'oh-my-posh'; Skip = $NoOhMyPosh }
        'pnpm'       = @{ Cmd = { pnpm self-update *>&1 | Out-Null };   Tool = 'pnpm';       Skip = $NoPnpm }
        'Bun'        = @{ Cmd = { bun upgrade *>&1 | Out-Null };        Tool = 'bun';         Skip = $NoBun }
        'Deno'       = @{ Cmd = { deno upgrade *>&1 | Out-Null };       Tool = 'deno';        Skip = $NoDeno }
        'Poetry'     = @{ Cmd = { poetry self update *>&1 | Out-Null }; Tool = 'poetry';      Skip = $NoPoetry }
        'Rye'        = @{ Cmd = { rye self update *>&1 | Out-Null };    Tool = 'rye';         Skip = $NoRye }
        'Composer'   = @{ Cmd = { composer self-update *>&1 | Out-Null }; Tool = 'composer';  Skip = $NoComposer }
    }
    foreach ($key in $specs.Keys) {
        $spec = $specs[$key]
        if ($spec.Skip -or -not (Test-SectionWanted -Name $key)) { continue }
        if (-not (Get-Command $spec.Tool -ErrorAction SilentlyContinue)) { continue }
        $cmdText = $spec.Cmd.ToString()
        $script:parallelJobs[$key] = Start-Job -Name "prefetch-$key" -ScriptBlock {
            param($cmdText)
            $sb = [scriptblock]::Create($cmdText)
            & $sb
            [PSCustomObject]@{ ExitCode = $LASTEXITCODE }
        } -ArgumentList $cmdText
    }
    if ($script:parallelJobs.Count -gt 0) {
        Write-Status "Pre-launched $($script:parallelJobs.Count) independent tool self-update(s) in background (-Parallel): $($script:parallelJobs.Keys -join ', ')" -Type Info
        Write-Log "Parallel prefetch started for: $($script:parallelJobs.Keys -join ', ')" -Level "INFO"
    }
}

# Cleanup: stop/remove any prefetch jobs nobody consumed (e.g. -Only filtered that section out,
# or the run stopped early). Called once at the very end of the script.
function Stop-ParallelPrefetch {
    foreach ($job in $script:parallelJobs.Values) {
        $job | Stop-Job -ErrorAction SilentlyContinue
        $job | Remove-Job -Force -ErrorAction SilentlyContinue
    }
    $script:parallelJobs.Clear()
}

# Helper: run Invoke-WithRetry and record success/failure into result hashtables.
# Collapses the repetitive: if (Invoke-WithRetry ...) { $updatedItems[...] += ... }
# else { Write-Status Error; $failedItems[...] += ... }
function Invoke-UpdateStep {
    param(
        [Parameter(Mandatory)] [string]$Key,
        [Parameter(Mandatory)] [string]$ActionName,
        [Parameter(Mandatory)] [scriptblock]$Action,
        [Parameter(Mandatory)] [string]$SuccessLabel,
        [string]$FailureLabel,
        [int]$MaxRetries = 2
    )
    if (-not $FailureLabel) { $FailureLabel = "$ActionName (failed after retries)" }
    if (Invoke-WithRetry -Action $Action -ActionName $ActionName -MaxRetries $MaxRetries) {
        $updatedItems[$Key] += $SuccessLabel
        return $true
    }
    Write-Status "$ActionName failed after retries" -Type Error
    $failedItems[$Key] += $FailureLabel
    return $false
}

# Parse `winget upgrade` output and return an array of upgradable package IDs.
# Returns @() when no updates, when only pinned packages show, or when output is unparseable.
# Used by both Test-WingetHasUpdates (pre-check) and the Winget section (update loop).
function Get-WingetUpgradableIds {
    param(
        [Parameter(Mandatory)]
        [AllowNull()] [AllowEmptyCollection()] [AllowEmptyString()]
        [string[]]$WingetOutput
    )
    $ids = @()
    if (-not $WingetOutput -or -not ($WingetOutput -join '').Trim()) { return $ids }
    if (($WingetOutput -join "`n") -match 'No applicable upgrades were found') { return $ids }

    $lines  = $WingetOutput -split [System.Environment]::NewLine
    # Winget sometimes emits progress lines before the table header; find the real header
    # by locating the first line that contains both 'Id' and 'Version' columns.
    $header = $lines | Where-Object { $_ -match '\bId\b' -and $_ -match '\bVersion\b' } |
                       Select-Object -First 1
    if (-not $header) { return $ids }

    $idCol  = $header.IndexOf('Id')
    $verCol = $header.IndexOf('Version')
    # Malformed header = can't parse = return empty (avoid false elevation/upgrades)
    if ($idCol -lt 0 -or $verCol -le $idCol) { return $ids }

    $headerIdx = [Array]::IndexOf($lines, $header)
    for ($i = $headerIdx + 2; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        # A blank line ends the table — do NOT `continue` past it. winget prints follow-up
        # sections after the table (e.g. a second "require explicit targeting" table for
        # pinned/unsupported packages) — reading past the blank line let that free-form text
        # get sliced by column position and misread as a garbage package "ID".
        if ($line.Trim().Length -eq 0)  { break }
        # Summary lines like "2 upgrades available." or "1 package(s) are pinned ...": check
        # the FULL line for a leading digit, not the column-sliced substring below — slicing
        # first and checking the fragment (the original approach) can land mid-word (e.g.
        # "available" sliced at the Id/Version column boundary becomes "ble.", which doesn't
        # start with a digit and so wasn't filtered).
        if ($line -match '^\s*\d')      { continue }
        if ($line -match '\bPinned\b')  { continue }   # user-pinned — skip
        if ($line -match '^\s*-+\s*$')  { continue }   # separator row
        if ($line.Length -le $idCol)    { continue }
        $pkg = $line.Substring($idCol, [Math]::Min($verCol - $idCol, $line.Length - $idCol)).Trim()
        if ($pkg.Length -gt 0) { $ids += $pkg }
    }
    return $ids
}

# Parses the separate "require explicit targeting" table that winget prints alongside the main
# upgradable-packages table for packages it refuses to touch via --all (e.g. version-pinned
# packages, or packages where the available version looks like a downgrade). Without this,
# such packages are silently never upgraded and never show up anywhere in the summary — see
# https://github.com/baurfm/update/issues/8.
function Get-WingetExplicitTargetIds {
    param(
        [Parameter(Mandatory)]
        [AllowNull()] [AllowEmptyCollection()] [AllowEmptyString()]
        [string[]]$WingetOutput
    )
    $ids = @()
    if (-not $WingetOutput -or -not ($WingetOutput -join '').Trim()) { return $ids }
    $lines = $WingetOutput -split [System.Environment]::NewLine
    $markerIdx = -1
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match 'require explicit targeting') { $markerIdx = $i; break }
    }
    if ($markerIdx -lt 0) { return $ids }

    $header = $null
    for ($i = $markerIdx + 1; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '\bId\b' -and $lines[$i] -match '\bVersion\b') { $header = $lines[$i]; break }
    }
    if (-not $header) { return $ids }

    $idCol  = $header.IndexOf('Id')
    $verCol = $header.IndexOf('Version')
    if ($idCol -lt 0 -or $verCol -le $idCol) { return $ids }

    $headerIdx = [Array]::IndexOf($lines, $header)
    for ($i = $headerIdx + 2; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line.Trim().Length -eq 0) { break }         # blank line ends the table
        if ($line -match '^\s*-+\s*$') { continue }       # separator row
        if ($line -match '^\s*\d+\s+package')  { break }  # "N package(s) are pinned..." summary
        if ($line.Length -le $idCol) { continue }
        $pkg = $line.Substring($idCol, [Math]::Min($verCol - $idCol, $line.Length - $idCol)).Trim()
        if ($pkg.Length -gt 0) { $ids += $pkg }
    }
    return $ids
}

# Helper: non-elevated pre-check — returns $true if winget reports any non-pinned upgradable
# packages. On any parse error or winget failure, returns $false (safe default: no elevation).
function Test-WingetHasUpdates {
    # Refresh sources first — stale cache can show phantom updates that disappear after refresh.
    & winget source update 2>$null | Out-Null

    # Omit --include-unknown: "unknown-version" packages appear upgradeable but winget upgrade
    # --all cannot actually install them ("No installed package found matching input criteria").
    # NOTE: winget exits non-zero (0x8A150014) when there are NO updates — do NOT gate on
    # $LASTEXITCODE here. We rely entirely on the output text and table content.
    $output = & winget upgrade 2>$null
    return ((Get-WingetUpgradableIds $output).Count -gt 0)
}

# Returns an array of process names that would block the Git for Windows installer.
# Inno Setup uses the Restart Manager API to detect any process whose binary lives
# inside the Git installation (usually C:\Program Files\Git\…). bash.exe is the most
# common culprit because Git Bash is the shell of choice for many devs — if update.ps1
# runs FROM a Git Bash (e.g. Claude Code's default terminal), the installer will abort
# with exit 1 in silent mode.
function Test-GitBinariesInUse {
    $blockers = @('bash.exe', 'git.exe', 'git-bash.exe', 'mintty.exe', 'gitk.exe', 'git-cmd.exe')
    $running  = @()
    foreach ($name in $blockers) {
        $procName = [System.IO.Path]::GetFileNameWithoutExtension($name)
        if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
            $running += $name
        }
    }
    return ,$running
}

# Pending-Git-Update flag: persists across runs when Git.Git had to be skipped
# because bash.exe etc. were running. A later run that starts without blockers
# can then apply the pending update as a fast-path before the regular upgrade batch.
function Get-PendingGitUpdate {
    if (-not (Test-Path $script:PendingGitUpdateFlag)) { return $null }
    try {
        return Get-Content -Path $script:PendingGitUpdateFlag -Raw -ErrorAction Stop |
               ConvertFrom-Json -ErrorAction Stop
    } catch {
        # corrupted/unreadable — remove and treat as no pending update
        Remove-Item -Path $script:PendingGitUpdateFlag -Force -ErrorAction SilentlyContinue
        return $null
    }
}

function Set-PendingGitUpdate {
    param(
        [Parameter(Mandatory)] [string[]]$Blockers
    )
    $existing  = Get-PendingGitUpdate
    $now       = (Get-Date).ToString('s')
    $firstSeen = if ($existing -and $existing.firstDetected) { $existing.firstDetected } else { $now }
    $count     = if ($existing -and $existing.skipCount)     { [int]$existing.skipCount + 1 } else { 1 }
    $data = [ordered]@{
        package       = 'Git.Git'
        firstDetected = $firstSeen
        lastDetected  = $now
        skipCount     = $count
        blockers      = $Blockers
    }
    try {
        $data | ConvertTo-Json -Depth 3 | Set-Content -Path $script:PendingGitUpdateFlag -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Log "Failed to write pending Git update flag: $_" -Level "INFO"
    }
}

function Clear-PendingGitUpdate {
    if (Test-Path $script:PendingGitUpdateFlag) {
        Remove-Item -Path $script:PendingGitUpdateFlag -Force -ErrorAction SilentlyContinue
    }
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

# Ensures 'update' is callable from any shell by writing a small update.cmd shim
# in the script directory and adding that directory to the User PATH. Idempotent:
# no-op if an 'update' command already resolves (respects user's existing setup).
function Initialize-UpdateCommand {
    param([string]$ScriptDir)

    # Respect existing setups (profile function, scoop shim, manual entry, …)
    if (Get-Command update -ErrorAction SilentlyContinue) { return }

    $shimPath = Join-Path $ScriptDir "update.cmd"
    if (-not (Test-Path $shimPath)) {
        $shimBody = @'
@echo off
where /q pwsh >nul 2>&1
if %errorlevel%==0 (
    pwsh -File "%~dp0update.ps1" %*
) else (
    powershell -File "%~dp0update.ps1" %*
)
'@
        Set-Content -Path $shimPath -Value $shimBody -Encoding ASCII
        Write-Status "Created update.cmd shim" -Type Info
    }

    $resolvedDir = try { (Resolve-Path $ScriptDir).Path.TrimEnd('\') } catch { $ScriptDir.TrimEnd('\') }
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $entries  = @()
    if ($userPath) { $entries = $userPath -split ';' | Where-Object { $_ } }

    $alreadyInPath = $false
    foreach ($e in $entries) {
        $resolved = try { (Resolve-Path $e -ErrorAction Stop).Path.TrimEnd('\') } catch { $e.TrimEnd('\') }
        if ($resolved -ieq $resolvedDir) { $alreadyInPath = $true; break }
    }

    if (-not $alreadyInPath) {
        $newUserPath = if ($userPath) { "$userPath;$ScriptDir" } else { $ScriptDir }
        [Environment]::SetEnvironmentVariable('PATH', $newUserPath, 'User')
        Write-Status "Added $ScriptDir to user PATH — 'update' is now reachable from any shell" -Type Success
        Write-Log "PATH: appended $ScriptDir to User PATH" -Level "INFO"
    }

    # Also make it visible in the *current* session
    if (";$env:PATH;" -notlike "*;$ScriptDir;*") {
        $env:PATH = "$env:PATH;$ScriptDir"
    }
}

# Removes the update.cmd shim and strips the script directory from User PATH.
function Remove-UpdateCommand {
    param([string]$ScriptDir)

    $shimPath = Join-Path $ScriptDir "update.cmd"
    if (Test-Path $shimPath) {
        Remove-Item $shimPath -Force -ErrorAction SilentlyContinue
        Write-Status "Removed update.cmd shim" -Type Success
    }

    $resolvedDir = try { (Resolve-Path $ScriptDir).Path.TrimEnd('\') } catch { $ScriptDir.TrimEnd('\') }
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($userPath) {
        $kept = $userPath -split ';' | Where-Object {
            $entry = $_
            if (-not $entry) { return $false }
            # NOTE: $_ inside the catch block below is the caught ErrorRecord, not this $entry —
            # a classic PowerShell shadowing gotcha. Capture $entry first so the fallback (used
            # when Resolve-Path can't find the path, e.g. it was already removed) trims the
            # right string instead of throwing "ErrorRecord has no method TrimEnd".
            $resolved = try { (Resolve-Path $entry -ErrorAction Stop).Path.TrimEnd('\') } catch { $entry.TrimEnd('\') }
            $resolved -ine $resolvedDir
        }
        $newUserPath = $kept -join ';'
        if ($newUserPath -ne $userPath) {
            [Environment]::SetEnvironmentVariable('PATH', $newUserPath, 'User')
            Write-Status "Removed $ScriptDir from User PATH" -Type Success
            Write-Log "PATH: removed $ScriptDir from User PATH" -Level "INFO"
        } else {
            Write-Status "$ScriptDir was not in User PATH" -Type Skip
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# UNATTENDED HELPERS  (lock, network probe, timeouts, schedule, notifications)
# ═══════════════════════════════════════════════════════════════════════════

# Exclusive run lock: writes <logs>/update.lock with PID + start time. Returns $true on acquire,
# $false if another live run already holds the lock (stale locks from dead PIDs are evicted).
function Lock-UpdateRun {
    param([string]$LockPath)
    if (Test-Path $LockPath) {
        try {
            $existing = Get-Content $LockPath -ErrorAction Stop | ConvertFrom-Json
            $alive = $false
            if ($existing.PID) { $alive = [bool](Get-Process -Id $existing.PID -ErrorAction SilentlyContinue) }
            if ($alive) {
                Write-Status "Another run is active (PID $($existing.PID), started $($existing.StartTime))" -Type Error
                Write-Log "Lock active: PID=$($existing.PID), started=$($existing.StartTime)" -Level "INFO"
                return $false
            }
            Write-Log "Evicting stale lock from dead PID $($existing.PID)." -Level "INFO"
            Remove-Item $LockPath -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Log "Lock file corrupted ($($_.Exception.Message)) — evicting." -Level "INFO"
            Remove-Item $LockPath -Force -ErrorAction SilentlyContinue
        }
    }
    @{ PID = $PID; StartTime = (Get-Date).ToString('o'); Host = $env:COMPUTERNAME; User = $env:USERNAME } |
        ConvertTo-Json -Compress | Set-Content -Path $LockPath -Encoding UTF8
    $script:LockAcquired = $true
    return $true
}

function Unlock-UpdateRun {
    param([string]$LockPath)
    if ($script:LockAcquired -and $LockPath -and (Test-Path $LockPath)) {
        Remove-Item $LockPath -Force -ErrorAction SilentlyContinue
    }
}

# Network reachability pre-check. Returns $true if any of the probe hosts answers within the
# configured timeout; $false means "offline" and is a safe-skip signal for the main run.
function Test-NetworkReachable {
    param(
        [string[]]$Hosts = $script:NetCheckHosts,
        [int]$TimeoutSec = $script:NetCheckTimeoutSec
    )
    foreach ($h in $Hosts) {
        try {
            $reply = Test-Connection -TargetName $h -Count 1 -TimeoutSeconds $TimeoutSec -Quiet -ErrorAction SilentlyContinue
            if ($reply) { return $true }
        } catch {
            # Test-Connection on PS5.1 has different parameters — fallback:
            try {
                $ok = [bool](Test-Connection -ComputerName $h -Count 1 -Quiet -ErrorAction SilentlyContinue)
                if ($ok) { return $true }
            } catch { }
        }
    }
    return $false
}

# Run a scriptblock in a background job with a hard timeout. Returns a PSCustomObject:
#   @{ TimedOut=[bool]; ExitCode=[int]; Output=[object[]]; Error=[string] }
# Used by Invoke-WithRetry when -TimeoutSec > 0 so hanging external commands can't stall the run.
# ScriptBlocks don't cross the job boundary as live objects — serialise to text and reconstruct.
function Invoke-WithTimeout {
    param(
        [Parameter(Mandatory)] [scriptblock]$Action,
        [Parameter(Mandatory)] [int]$TimeoutSec
    )
    $actionText = $Action.ToString()
    $envPath    = $env:PATH     # preserve PATH so the child sees tools installed in this shell's env
    $job = Start-Job -ScriptBlock {
        $env:PATH = $using:envPath
        try {
            $sb  = [scriptblock]::Create($using:actionText)
            $out = & $sb *>&1
            [PSCustomObject]@{ ExitCode = $LASTEXITCODE; Output = $out; Error = $null }
        } catch {
            [PSCustomObject]@{ ExitCode = -1; Output = $null; Error = $_.Exception.Message }
        }
    }
    $done = $job | Wait-Job -Timeout $TimeoutSec
    if ($null -eq $done) {
        $job | Stop-Job -ErrorAction SilentlyContinue
        $job | Remove-Job -Force -ErrorAction SilentlyContinue
        return [PSCustomObject]@{ TimedOut = $true; ExitCode = -2; Output = @(); Error = "timed out after ${TimeoutSec}s" }
    }
    $r = $job | Receive-Job
    $job | Remove-Job -Force -ErrorAction SilentlyContinue
    return [PSCustomObject]@{ TimedOut = $false; ExitCode = $r.ExitCode; Output = $r.Output; Error = $r.Error }
}

# Register this script as a Scheduled Task. Idempotent: re-registering replaces the existing task.
# Uses the Windows Task Scheduler ServiceAccount principal so the task runs elevated without
# storing a password. Requires admin for registration (Scheduled Tasks API limitation).
function Register-UpdateScheduledTask {
    param(
        [Parameter(Mandatory)] [string]$ScriptPath,
        [Parameter(Mandatory)] [string]$AtTime,
        [Parameter(Mandatory)] [ValidateSet('Daily','Weekly')] [string]$Frequency
    )
    if (-not $script:isAdmin) {
        Write-Status "Scheduled Task registration requires admin — re-run in an elevated shell." -Type Error
        return $false
    }
    $pwshExe = (Get-Process -Id $PID).MainModule.FileName
    $taskArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -Unattended -NoSelfUpdate"
    $action   = New-ScheduledTaskAction -Execute $pwshExe -Argument $taskArgs
    $trigger  = switch ($Frequency) {
        'Daily'  { New-ScheduledTaskTrigger -Daily  -At $AtTime }
        'Weekly' { New-ScheduledTaskTrigger -Weekly -At $AtTime -DaysOfWeek Monday }
    }
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
        -WakeToRun -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5) `
        -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    try {
        Register-ScheduledTask -TaskName $script:ScheduledTaskName -Action $action `
            -Trigger $trigger -Principal $principal -Settings $settings `
            -Description "Windows Update Script — unattended daily dev-tool refresh (v$script:VersionString)" `
            -Force | Out-Null
        Write-Status "Scheduled Task '$($script:ScheduledTaskName)' registered ($Frequency at $AtTime, SYSTEM, elevated)" -Type Success
        Write-Log "Scheduled Task registered: name=$($script:ScheduledTaskName) freq=$Frequency at=$AtTime" -Level "INFO"
        return $true
    } catch {
        Write-Status "Scheduled Task registration failed: $($_.Exception.Message)" -Type Error
        Write-Log "Scheduled Task register failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Unregister-UpdateScheduledTask {
    try {
        $null = Get-ScheduledTask -TaskName $script:ScheduledTaskName -ErrorAction Stop
    } catch {
        Write-Status "No Scheduled Task '$($script:ScheduledTaskName)' to remove." -Type Skip
        return $true
    }
    try {
        Unregister-ScheduledTask -TaskName $script:ScheduledTaskName -Confirm:$false -ErrorAction Stop
        Write-Status "Scheduled Task '$($script:ScheduledTaskName)' removed" -Type Success
        Write-Log "Scheduled Task unregistered: $($script:ScheduledTaskName)" -Level "INFO"
        return $true
    } catch {
        Write-Status "Failed to remove Scheduled Task '$($script:ScheduledTaskName)': $($_.Exception.Message)" -Type Error
        Write-Log "Scheduled Task unregister failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Detect pending reboot via the canonical set of Windows registry/WMI signals used by
# Windows Update / Component Based Servicing. No reboot-is-pending key has an authoritative
# name, so we OR a handful of well-known ones.
function Test-PendingReboot {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending'
    )
    foreach ($k in $keys) { if (Test-Path $k) { return $true } }
    $pfro = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    if ($pfro -and $pfro.PendingFileRenameOperations) { return $true }
    return $false
}

# Ensure BurntToast is installed (once), then emit a toast. No-op + one-line log on any failure
# so a toast problem never breaks the main run. Runs in quiet mode as well — this IS the output.
function Send-ToastNotification {
    param([string]$Title, [string]$Body)
    try {
        if (-not (Get-Module -ListAvailable -Name BurntToast)) {
            if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue | Out-Null
            }
            Install-Module BurntToast -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        }
        Import-Module BurntToast -ErrorAction Stop
        New-BurntToastNotification -Text $Title, $Body -AppLogo $null | Out-Null
        Write-Log "Toast sent: $Title" -Level "INFO"
    } catch {
        Write-Log "Toast failed: $($_.Exception.Message)" -Level "INFO"
    }
}

# POST a JSON summary to a generic webhook (ntfy.sh, Discord, Slack all tolerate it).
# For ntfy, the body is the message and the title is sent via headers — detect and adapt.
function Send-WebhookNotification {
    param([string]$Url, [string]$Title, [string]$Body, [hashtable]$Summary)
    try {
        if ($Url -match 'ntfy\.sh') {
            $headers = @{ Title = $Title; Priority = if ($Summary.Failures -gt 0) { 'high' } else { 'default' } }
            Invoke-RestMethod -Uri $Url -Method Post -Body $Body -Headers $headers -TimeoutSec 10 -ErrorAction Stop | Out-Null
        } else {
            $payload = @{ title = $Title; text = $Body; body = $Body; content = $Body; summary = $Summary } |
                ConvertTo-Json -Depth 6 -Compress
            Invoke-RestMethod -Uri $Url -Method Post -Body $payload -ContentType 'application/json' -TimeoutSec 10 -ErrorAction Stop | Out-Null
        }
        Write-Log "Webhook notified: $Url" -Level "INFO"
    } catch {
        Write-Log "Webhook failed ($Url): $($_.Exception.Message)" -Level "INFO"
    }
}

# Write the run result to the Windows Event Log. Registers the source on first use.
function Write-UpdateEventLog {
    param(
        [Parameter(Mandatory)] [ValidateSet('Information','Warning','Error')] [string]$EntryType,
        [Parameter(Mandatory)] [string]$Message,
        [int]$EventId = 1000
    )
    try {
        # Check admin BEFORE calling SourceExists: without elevation, SourceExists itself throws
        # ("Inaccessible logs: Security") rather than just returning $false, so checking admin
        # first avoids a confusing exception and lets us skip with a clear reason instead.
        if (-not $script:isAdmin) {
            Write-Log "Cannot register Event Log source '$($script:EventLogSource)' — not admin." -Level "INFO"
            return
        }
        if (-not [System.Diagnostics.EventLog]::SourceExists($script:EventLogSource)) {
            New-EventLog -LogName Application -Source $script:EventLogSource -ErrorAction Stop
        }
        Write-EventLog -LogName Application -Source $script:EventLogSource -EntryType $EntryType `
            -EventId $EventId -Message $Message -ErrorAction Stop
        Write-Log "Event Log written: $EntryType (id $EventId)" -Level "INFO"
    } catch {
        Write-Log "Event Log write failed: $($_.Exception.Message)" -Level "INFO"
    }
}

# Aggregator: decide whether to send + fan out to all enabled channels.
function Send-UpdateNotifications {
    param(
        [Parameter(Mandatory)] [hashtable]$Summary,
        [Parameter(Mandatory)] [bool]$HasFailures
    )
    $should = switch ($NotifyOn) {
        'Never'   { $false }
        'Always'  { $true  }
        'Failure' { $HasFailures }
    }
    if (-not $should) { return }

    $title = if ($HasFailures) {
        "Update script: FAILED on $env:COMPUTERNAME"
    } else {
        "Update script: ok on $env:COMPUTERNAME"
    }
    $body = @(
        "Updated: $($Summary.Updated)  Failed: $($Summary.Failures)  Skipped: $($Summary.Skipped)"
        "Duration: $($Summary.Duration)"
        if ($Summary.FailedSections) { "Failed sections: $($Summary.FailedSections -join ', ')" }
    ) -join "`n"

    if ($NotifyToast)     { Send-ToastNotification   -Title $title -Body $body }
    if ($NotifyWebhook)   { Send-WebhookNotification -Url $NotifyWebhook -Title $title -Body $body -Summary $Summary }
    if ($NotifyEventLog)  {
        $entryType = if ($HasFailures) { 'Error' } else { 'Information' }
        $eventId   = if ($HasFailures) { 1001 } else { 1000 }
        Write-UpdateEventLog -EntryType $entryType -Message "$title`n$body" -EventId $eventId
    }
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
$script:LockFilePath         = Join-Path $LogDir "update.lock"
$script:PendingGitUpdateFlag = Join-Path $LogDir "pending-git-update.json"
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

# Display startup banner (suppressed in quiet/unattended mode, and on an elevated
# re-launch — the parent process already showed it).
$_version = "v$($script:VersionString)"
if (-not $script:QuietMode -and -not $Elevated) {
    $_bw      = 40
    $_bTop    = "  $([char]0x256D)$(([char]0x2500).ToString() * $_bw)$([char]0x256E)"
    $_bBot    = "  $([char]0x2570)$(([char]0x2500).ToString() * $_bw)$([char]0x256F)"
    $_bBar    = [char]0x2502
    $_gem     = [char]0x25C6
    $_title   = "  $_gem  Windows Update Script  "
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
}

# --- Compute admin status early so schedule/event-log helpers know their privilege ---
$myWindowsID        = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole          = [System.Security.Principal.WindowsBuiltInRole]::Administrator
$script:isAdmin     = $myWindowsPrincipal.IsInRole($adminRole)

# --- Handle -UnregisterSchedule: remove Scheduled Task and exit ---
if ($UnregisterSchedule) {
    $unregisterOk = Unregister-UpdateScheduledTask
    exit $(if ($unregisterOk) { $script:ExitOk } else { $script:ExitHardFailure })
}

# --- Handle -RegisterSchedule: install Scheduled Task and exit ---
if ($RegisterSchedule) {
    $ok = Register-UpdateScheduledTask -ScriptPath $PSCommandPath -AtTime $ScheduleTime -Frequency $ScheduleFrequency
    exit $(if ($ok) { $script:ExitOk } else { $script:ExitHardFailure })
}

# --- Handle -RemoveFromPath: strip shim + PATH entry and exit ---
if ($RemoveFromPath) {
    Remove-UpdateCommand -ScriptDir $ScriptPath
    exit $script:ExitOk
}

# --- Lock-File: prevent overlapping runs (e.g. Scheduled Task + manual run) ---
if (-not $NoLock -and -not $DryRun) {
    if (-not (Lock-UpdateRun -LockPath $script:LockFilePath)) {
        exit $script:ExitLockActive
    }
}

# --- Network reachability pre-check ---
if (-not $SkipNetworkCheck -and -not $DryRun) {
    if (-not (Test-NetworkReachable)) {
        Write-Status "No network reachable — update hosts unresponsive" -Type Error
        Write-Log "Network pre-check failed — exiting." -Level "INFO"
        Unlock-UpdateRun -LockPath $script:LockFilePath
        exit $script:ExitNetworkDown
    }
}

# --- Auto-register 'update' command on PATH (silent if already reachable) ---
Initialize-UpdateCommand -ScriptDir $ScriptPath

# --- Self-update via git pull ---
# Skipped on an elevated re-launch — the parent process already ran this check.
if (-not $NoSelfUpdate -and -not $Elevated) {
    $scriptDir = Split-Path $PSCommandPath -Parent
    if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $scriptDir ".git"))) {
        Write-Status "Checking for script updates (git pull)..." -Type Action
        try {
            $pullOut = & git -C $scriptDir pull 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Status "git pull failed: $($pullOut -join ' ')" -Type Warning
                Write-Log "Self-update: git pull failed (exit $LASTEXITCODE): $($pullOut -join ' ')" -Level "INFO"
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
                    # Release the lock before re-exec — the child re-invocation runs in this same
                    # process ($PID unchanged), so without releasing first it would find its own
                    # still-alive PID holding the lock and abort with "Another run is active".
                    Unlock-UpdateRun -LockPath $script:LockFilePath
                    & $PSCommandPath @PSBoundParameters -NoSelfUpdate
                    exit $LASTEXITCODE
                } else {
                    Write-Status "Repo updated (non-script files only)" -Type Info
                    Write-Log "Self-update: repo updated (non-script files only)" -Level "INFO"
                }
            }
        } catch {
            Write-Status "git pull failed: $($_.Exception.Message)" -Type Warning
            Write-Log "Self-update: git pull exception: $($_.Exception.Message)" -Level "INFO"
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
    Write-Log "WARNING: Low disk space: ${freeGB} GB free on C: (threshold: $($script:DiskSpaceWarnGB) GB)" -Level "INFO"
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

if ($Elevated) {
    # Re-launched elevated child: the parent already ran these pre-checks to decide whether
    # elevation was needed at all — redoing them here would just waste time and reprint output.
    Write-Log "Pre-check: skipped — running as the elevated re-launch of an already-checked parent." -Level "INFO"
} elseif ($Sudo) {
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

    if (-not $NoWinget -and (Test-SectionWanted 'Winget & Microsoft Store apps') -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        # ${Function:...} gives a ScriptBlock, but $using: serialises it to a string in the job.
        # Use [scriptblock]::Create() to reconstruct it on the other side.
        # Both functions must be passed: Test-WingetHasUpdates calls Get-WingetUpgradableIds.
        $fnWingetIds = ${Function:Get-WingetUpgradableIds}.ToString()
        $fnWinget    = ${Function:Test-WingetHasUpdates}.ToString()
        $preWingetJob = Start-Job -ScriptBlock {
            function Write-Status { param([string]$Message, [string]$Type = 'Info') }
            function Write-Log    { param([string]$Message, [string]$Level = 'INFO') }
            # dot-source to define Get-WingetUpgradableIds in this job's scope
            . ([scriptblock]::Create("function Get-WingetUpgradableIds { $($using:fnWingetIds) }"))
            & ([scriptblock]::Create($using:fnWinget))
        }
    }

    # Only wsl --update needs elevation; apt-get does not.
    # Skip when -NoWsl or -OnlyWslPackages is set (wsl --update won't run anyway).
    if (-not $NoWsl -and -not $OnlyWslPackages -and (Test-SectionWanted 'Windows Subsystem for Linux (WSL)') -and (Get-Command wsl -ErrorAction SilentlyContinue)) {
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
    if (-not $NoNpm -and -not $OnlyWsl -and -not $OnlyWslPackages -and (Test-SectionWanted 'npm (Node Package Manager) Packages') -and (Get-Command npm -ErrorAction SilentlyContinue)) {
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

# $script:isAdmin already computed near the top (used by schedule/event-log helpers).

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
        # Mark the child as the elevated re-launch so it skips the banner, self-update check and
        # pre-checks — this process (the parent) already did all of that.
        $argArray += "-Elevated"

        # Not running as admin, so attempt to re-launch with elevation.
        # Use the current PowerShell executable (pwsh.exe for PS7, powershell.exe for PS5)
        # so the elevated process runs the same version.
        $psExe = (Get-Process -Id $PID).MainModule.FileName
        $elevationReasons = @()
        if ($Sudo)                { $elevationReasons += '-Sudo flag' }
        if ($wingetNeedsElevation){ $elevationReasons += 'winget updates' }
        if ($wslNeedsElevation)   { $elevationReasons += 'WSL kernel update' }
        if ($npmNeedsElevation)   { $elevationReasons += 'npm updates' }
        Write-Status "Elevation needed: $($elevationReasons -join ', ')" -Type Warning
        Write-Log "Elevation required ($($elevationReasons -join ', ')) — re-launching as administrator." -Level "INFO"
        # Release the lock so the elevated child process can acquire it.
        Unlock-UpdateRun -LockPath $script:LockFilePath
        $sudoExists = Get-Command sudo -ErrorAction SilentlyContinue
        if ($sudoExists) {
            # Use the new Windows 'sudo' to re-launch.
            Write-Status "Administrator privileges required — re-launching with 'sudo'..." -Type Action
            & sudo $psExe -ExecutionPolicy Bypass -File $MyInvocation.MyCommand.Definition @argArray
            exit $LASTEXITCODE
        } else {
            # Fallback to the traditional self-elevation method.
            Write-Status "Administrator privileges required — re-launching as administrator..." -Type Action
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
            $argStrParts += "-Elevated"
            $argStr = $argStrParts -join ' '
            $newProcess = New-Object System.Diagnostics.ProcessStartInfo $psExe
            $newProcess.Arguments = "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`" $argStr"
            $newProcess.Verb = "runas"
            try {
                [System.Diagnostics.Process]::Start($newProcess) | Out-Null
                exit $script:ExitOk
            } catch {
                # Thrown when the user cancels the UAC prompt (or elevation otherwise can't be
                # acquired) -- without this, that's an unhandled Win32Exception with a scary
                # stack trace instead of a clean message and the documented exit code.
                Write-Status "Elevation failed or was cancelled: $($_.Exception.Message)" -Type Error
                Write-Log "Elevation failed: $($_.Exception.Message)" -Level "ERROR"
                exit $script:ExitElevationMissing
            }
        }
    }
}

if ((Get-Location).Path -ne $ScriptPath) {
    Set-Location $ScriptPath
}


# Initialize hashtables to store results for the final summary
$sectionKeys = "Scoop", "Winget", "Chocolatey",
              "PowerShell Modules", "Oh My Posh",
              "WSL",
              "npm", "pnpm", "Bun", "Deno",
              "pipx", "uv", "Poetry", "Rye",
              ".NET Global Tools", "Rust", "Ruby Gems", "Composer",
              "Google Cloud SDK", "Azure CLI", "Android SDK", "Helm plugins", "krew plugins",
              "VS Code Extensions", "GitHub CLI Extensions",
              "TeX Live"
$script:sectionIndex   = 0
$script:totalSections  = $sectionKeys.Count
$updatedItems = @{}
$failedItems  = @{}
foreach ($k in $sectionKeys) {
    $updatedItems[$k] = @()
    $failedItems[$k]  = @()
}
$skippedSections      = @()
$script:sectionTimings = @{}   # SectionName → TimeSpan (populated by Update-Section)

if ($Parallel -and -not $DryRun) { Start-ParallelPrefetch }

# ══════════════════════════════════════════════════════
# PACKAGE MANAGERS  (update foundations first)
# ══════════════════════════════════════════════════════
if (Test-GroupWanted 'Scoop and its packages','Winget & Microsoft Store apps','Chocolatey packages') {
Write-GroupHeader "Package Managers"
}

# --- Update Scoop ---
Update-Section "Scoop and its packages" ($NoScoop -or $OnlyWsl -or $OnlyWslPackages) { Get-Command scoop -ErrorAction SilentlyContinue } {
    Write-Status "Checking for outdated packages..." -Type Action
    # *>&1: scoop writes status chatter ("Everything is ok!" etc.) via Write-Host, which lands on
    # the Information stream — a plain assignment wouldn't capture it and it would leak straight
    # to the console regardless of verbosity tier.
    $scoopStatus = & scoop status *>&1
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
        Invoke-UpdateStep -Key "Scoop" -ActionName "scoop update" -Action { & scoop update } -SuccessLabel "Scoop" | Out-Null

        Write-Status "Updating all installed packages..." -Type Action
        # No retry — scoop returns non-zero if ANY package fails.
        # Retrying would re-run ALL updates unnecessarily.
        Invoke-NativeCapture -Command { & scoop update * } -LogTag "scoop update *"
        if ($LASTEXITCODE -ne 0) {
            Write-Status "Some packages may have failed (exit code $LASTEXITCODE)" -Type Warning
            Write-Log "scoop update * exited with code $LASTEXITCODE" -Level "INFO"
        }

        Write-Status "Removing old package versions..." -Type Action
        Invoke-NativeCapture -Command { & scoop cleanup * } -LogTag "scoop cleanup *"
        if ($LASTEXITCODE -ne 0) {
            Write-Status "scoop cleanup failed (exit $LASTEXITCODE)" -Type Warning
            $failedItems["Scoop"] += "scoop cleanup (Exit Code: $LASTEXITCODE)"
        }
    }
}

# --- Update Winget & Microsoft Store Apps ---
Update-Section "Winget & Microsoft Store apps" ($NoWinget -or $OnlyWsl -or $OnlyWslPackages) { Get-Command winget -ErrorAction SilentlyContinue } {
    Write-Status "Checking for outdated packages..." -Type Action
    # NOTE: winget exits non-zero (0x8A150014) when there are NO updates — do NOT gate on
    # $LASTEXITCODE here. We rely entirely on output text and table content.
    $wingetUpgradeOutput = & winget upgrade --include-unknown 2>&1
    $upgradablePackages  = Get-WingetUpgradableIds $wingetUpgradeOutput
    # Packages winget refuses to touch via --all (version-pinned, or the available version looks
    # like a downgrade) — winget prints them in a separate table and suggests upgrading by --id
    # explicitly. Without this they'd silently never update. See issue #8.
    $explicitTargetIds  = Get-WingetExplicitTargetIds $wingetUpgradeOutput

    if ($upgradablePackages.Count -gt 0 -or $explicitTargetIds.Count -gt 0) {
      if ($upgradablePackages.Count -gt 0) {
        Write-Status "Found $($upgradablePackages.Count) upgradable packages" -Type Info
        Write-Log "Winget: $($upgradablePackages.Count) upgradable: $($upgradablePackages -join ', ')" -Level "INFO"

        # Fast-Path: falls Git.Git von einem früheren Lauf als "pending" markiert wurde und
        # jetzt keine Blocker-Prozesse laufen, ziehen wir das Update sofort direkt vor — so
        # muss der User nur einmal Bash/Claude-Code schließen, dann heilt sich das Problem
        # beim nächsten Lauf von selbst (ohne manuellen Eingriff an winget).
        $pending = Get-PendingGitUpdate
        if ($pending -and ($upgradablePackages -contains 'Git.Git')) {
            $currentBlockers = Test-GitBinariesInUse
            if ($currentBlockers.Count -eq 0) {
                Write-Status "Pending Git.Git update from earlier run — applying now (skipCount=$($pending.skipCount))" -Type Action
                Write-Log "Winget: consuming pending Git.Git flag (firstDetected=$($pending.firstDetected))" -Level "INFO"
                & winget upgrade --id Git.Git --accept-source-agreements --accept-package-agreements --include-unknown
                $gitFastCode = $LASTEXITCODE
                if ($gitFastCode -eq 0) {
                    Write-Status "Git.Git successfully updated" -Type Success
                    Clear-PendingGitUpdate
                    $updatedItems["Winget"] += 'Git.Git'
                    $upgradablePackages = @($upgradablePackages | Where-Object { $_ -ne 'Git.Git' })
                } else {
                    Write-Status "Git.Git fast-path update failed (exit $gitFastCode) — falling through to normal flow" -Type Warning
                    Write-Log "Winget: Git.Git fast-path exited $gitFastCode" -Level "INFO"
                }
            } else {
                Write-Status "Git.Git update pending since $($pending.firstDetected) ($($pending.skipCount) run(s)) — still blocked by: $($currentBlockers -join ', ')" -Type Warning
                Write-Status "  -> close these processes and re-run 'update' to clear the backlog" -Type Info
                Write-Log "Winget: pending Git.Git still blocked by $($currentBlockers -join ', ')" -Level "INFO"
            }
        } elseif ($pending -and ($upgradablePackages -notcontains 'Git.Git')) {
            # Git.Git ist nicht mehr in der Upgrade-Liste → wurde irgendwie aktualisiert (oder neu genug).
            # Alten Flag wegwerfen, damit die Nagging-Meldung nicht ewig bleibt.
            Write-Log "Winget: pending Git.Git no longer upgradable — clearing stale flag." -Level "INFO"
            Clear-PendingGitUpdate
        }

        # Git.Git-Schutz: Inno Setup erkennt laufende bash.exe/git.exe und bricht Silent-Install
        # mit Exit 1 ab. Wenn update.ps1 aus einer Git-Bash läuft (z.B. Claude-Code-Terminal),
        # würde Git.Git bei jedem Lauf reproduzierbar fehlschlagen. Lösung: temporärer --gated-Pin,
        # im finally wieder entfernt. User-eigene Pins lassen wir unangetastet.
        $pinAddedByUs  = $false
        $gitSkipReason = $null
        if ($upgradablePackages -contains 'Git.Git') {
            $gitBlockers = Test-GitBinariesInUse
            if ($gitBlockers.Count -gt 0) {
                $pinList = (& winget pin list --id Git.Git 2>$null | Out-String)
                $alreadyPinned = $pinList -match '(?im)^\s*Git\.Git\b'
                if (-not $alreadyPinned) {
                    Write-Status "Git.Git update would fail (running: $($gitBlockers -join ', ')) — pinning Git.Git temporarily" -Type Warning
                    Write-Log "Winget: pinning Git.Git to skip during --all (blockers: $($gitBlockers -join ', '))" -Level "INFO"
                    & winget pin add --id Git.Git --gated --accept-source-agreements 2>&1 |
                        ForEach-Object { Write-Log "  [winget-pin] $_" -Level "DEBUG" }
                    if ($LASTEXITCODE -eq 0) {
                        $pinAddedByUs  = $true
                        $gitSkipReason = "skipped — close $($gitBlockers -join '/') and re-run"
                    } else {
                        Write-Status "winget pin add failed (exit $LASTEXITCODE) — proceeding anyway, Git.Git will likely fail" -Type Warning
                    }
                } else {
                    Write-Log "Winget: Git.Git already pinned by user — leaving as-is." -Level "INFO"
                    $gitSkipReason = "already user-pinned"
                }
                # Pending-Flag setzen, damit der nächste Lauf ohne Blocker das Update direkt einspielt.
                # Nur wenn der Pin nicht bereits vom User kommt — dann ist es gewollt, kein Backlog.
                if ($gitSkipReason -ne "already user-pinned") {
                    Set-PendingGitUpdate -Blockers $gitBlockers
                }
                $upgradablePackages = @($upgradablePackages | Where-Object { $_ -ne 'Git.Git' })
            }
        }

        Write-Status "Refreshing winget sources..." -Type Action
        & winget source update
        if ($LASTEXITCODE -ne 0) {
            Write-Status "winget source update failed (exit $LASTEXITCODE) — package list may be stale" -Type Warning
            Write-Log "winget source update exited $LASTEXITCODE" -Level "INFO"
        }

        try {
            Write-Status "Upgrading all packages..." -Type Action
            # No retry — winget returns non-zero if ANY package fails (e.g. Office).
            # Pinned packages are excluded by default; we deliberately do not pass
            # --include-pinned so user pins are preserved.
            & winget upgrade --all --accept-source-agreements --accept-package-agreements --include-unknown
            $wingetUpgradeCode = $LASTEXITCODE
            # Record results AFTER the upgrade so the summary reflects what actually ran.
            $updatedItems["Winget"] += $upgradablePackages
            if ($wingetUpgradeCode -ne 0) {
                Write-Status "Some packages may have failed, e.g. Office (exit code $wingetUpgradeCode)" -Type Warning
                Write-Log "winget upgrade --all exited with code $wingetUpgradeCode" -Level "INFO"
                $failedItems["Winget"] += "Some installers failed (exit $wingetUpgradeCode)"
            }
            if ($gitSkipReason) {
                $script:skippedSections += "Git.Git ($gitSkipReason)"
            }
        }
        finally {
            if ($pinAddedByUs) {
                Write-Log "Winget: removing temporary Git.Git pin." -Level "INFO"
                & winget pin remove --id Git.Git 2>&1 |
                    ForEach-Object { Write-Log "  [winget-unpin] $_" -Level "DEBUG" }
                if ($LASTEXITCODE -ne 0) {
                    Write-Status "winget pin remove for Git.Git failed (exit $LASTEXITCODE) — run 'winget pin remove --id Git.Git' manually" -Type Warning
                    Write-Log "Winget: pin remove failed exit $LASTEXITCODE — manual cleanup needed" -Level "INFO"
                }
            }
        }
      }

      if ($explicitTargetIds.Count -gt 0) {
        Write-Status "$($explicitTargetIds.Count) package(s) need explicit targeting: $($explicitTargetIds -join ', ')" -Type Info
        Write-Log "Winget: explicit-targeting packages: $($explicitTargetIds -join ', ')" -Level "INFO"
        foreach ($id in $explicitTargetIds) {
            Write-Status "Upgrading $id (explicit targeting)..." -Type Action
            # Captured (not direct passthrough) so we can tell "publisher doesn't support a
            # winget-driven upgrade at all" apart from a real, retriable failure — still echoed
            # so the outcome is visible without needing -Verbose.
            $explicitOut  = & winget upgrade --id $id --accept-source-agreements --accept-package-agreements 2>&1
            $explicitCode = $LASTEXITCODE
            $explicitOut | ForEach-Object { Write-Host $_ }
            if ($explicitCode -eq 0) {
                Write-Status "$id successfully updated" -Type Success
                $updatedItems["Winget"] += $id
            } elseif (($explicitOut | Out-String) -match 'cannot be upgraded using WinGet') {
                # Some publishers ship a winget manifest with no working upgrade mechanism at all
                # (e.g. Android Studio's own self-updater) — winget says so explicitly. Retrying
                # this every run would just repeat the same permanent failure, so treat it as a
                # skip with a clear reason instead of a "failed" that implies retrying could help.
                Write-Status "$id has no winget-compatible upgrade path — update via the publisher's own updater" -Type Skip
                Write-Log "Winget: $id has no winget upgrade path (publisher-managed)." -Level "INFO"
                $script:skippedSections += "$id (no winget upgrade path — use publisher's updater)"
            } else {
                Write-Status "$id explicit-targeting upgrade failed (exit $explicitCode)" -Type Warning
                Write-Log "Winget: explicit-targeting upgrade of $id exited $explicitCode" -Level "INFO"
                $failedItems["Winget"] += "$id (explicit targeting, exit $explicitCode)"
            }
        }
      }
    } else {
        Write-Status "All packages up-to-date" -Type Success
        Write-Log "Winget: no applicable upgrades." -Level "INFO"
    }
}

# --- Update Chocolatey packages ---
Update-Section "Chocolatey packages" ($NoChoco -or $OnlyWsl -or $OnlyWslPackages) { Get-Command choco -ErrorAction SilentlyContinue } {
    Write-Status "Upgrading all Chocolatey packages..." -Type Action
    Write-Log "Upgrading Chocolatey packages."
    Invoke-UpdateStep -Key "Chocolatey" -ActionName "choco upgrade all" -Action { & choco upgrade all -y } -SuccessLabel "All Chocolatey packages" | Out-Null
}

# ══════════════════════════════════════════════════════
# SHELL / TERMINAL
# ══════════════════════════════════════════════════════
if (Test-GroupWanted 'PowerShell Modules','Oh My Posh') {
Write-GroupHeader "Shell / Terminal"
}

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

    $psExe    = (Get-Process -Id $PID).MainModule.FileName
    $subprocs = [System.Collections.Generic.List[PSCustomObject]]::new()

    # PS7+: run module updates in parallel (ThrottleLimit 3 — conservative to avoid shared-dep
    # collisions). Write-Status/Write-Log are not available in runspaces, so collect results
    # as [PSCustomObject] and process sequentially after the parallel block.
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $results = $modulesToUpdate | ForEach-Object -Parallel {
            $name = $_.Name
            try {
                $warnMsgs = @()
                Update-Module -Name $name -Force -ErrorAction Stop -WarningVariable warnMsgs -WarningAction SilentlyContinue
                $inUse = ($warnMsgs | Where-Object { $_.Message -like "*currently in use*" }).Count -gt 0
                [PSCustomObject]@{ Name = $name; Status = if ($inUse) { 'InUse' } else { 'OK' }; Error = $null }
            } catch {
                [PSCustomObject]@{ Name = $name; Status = 'Error'; Error = $_.Exception.Message }
            }
        } -ThrottleLimit 3

        foreach ($r in $results) {
            switch ($r.Status) {
                'OK'    {
                    $updatedItems["PowerShell Modules"] += $r.Name
                    Write-Log "Updated module: $($r.Name)"
                }
                'InUse' {
                    Write-Status "In use: $($r.Name) — starting subprocess..." -Type Warning
                    Write-Log "Module $($r.Name) is in use — spawning subprocess." -Level "INFO"
                    $tmpScript = Join-Path $env:TEMP "$([System.Guid]::NewGuid().ToString()).ps1"
                    $safeName  = $r.Name -replace "'", "''"
                    Set-Content $tmpScript -Encoding UTF8 -Value "Update-Module -Name '$safeName' -Force -ErrorAction Stop"
                    try {
                        $proc = Start-Process $psExe `
                            -ArgumentList "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", $tmpScript `
                            -PassThru -WindowStyle Hidden
                        $subprocs.Add([PSCustomObject]@{ Name = $r.Name; TmpScript = $tmpScript; Process = $proc })
                    } catch {
                        Remove-Item $tmpScript -ErrorAction SilentlyContinue
                        throw
                    }
                }
                'Error' {
                    Write-Status "Failed: $($r.Name) - $($r.Error)" -Type Error
                    Write-Log "Failed to update module: $($r.Name). Error: $($r.Error)" -Level "ERROR"
                    $failedItems["PowerShell Modules"] += "$($r.Name) - $($r.Error)"
                }
            }
        }
    } else {
        # PS5.1 fallback: sequential update; spawn subprocess for in-use modules
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
                    try {
                        $proc = Start-Process $psExe `
                            -ArgumentList "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", $tmpScript `
                            -PassThru -WindowStyle Hidden
                        $subprocs.Add([PSCustomObject]@{ Name = $module.Name; TmpScript = $tmpScript; Process = $proc })
                    } catch {
                        Remove-Item $tmpScript -ErrorAction SilentlyContinue
                        throw
                    }
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
    }

    # Wait for any in-use subprocesses (launched during either the parallel or sequential loop)
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
    Invoke-SelfUpdateWithPrefetch -ToolName "Oh My Posh" -Key "Oh My Posh" `
        -Action { & oh-my-posh upgrade 2>&1 | Out-Null } -ActionName "oh-my-posh upgrade"
}

# ══════════════════════════════════════════════════════
# SYSTEM
# ══════════════════════════════════════════════════════
if (Test-GroupWanted 'Windows Subsystem for Linux (WSL)') {
Write-GroupHeader "System"
}

# --- Update WSL ---
Update-Section "Windows Subsystem for Linux (WSL)" ($NoWsl -and !$OnlyWsl -and !$OnlyWslPackages) { Get-Command wsl -ErrorAction SilentlyContinue } {
    Write-Log "Starting WSL updates."
    # Since elevation is handled at the start, we can proceed directly.
    if (-not $OnlyWslPackages) {
        if ($script:isAdmin) {
            Write-Status "Updating WSL kernel..." -Type Action
            Write-Log "Updating WSL kernel."
            Invoke-UpdateStep -Key "WSL" -ActionName "wsl --update" -Action { & wsl --update --web-download } -SuccessLabel "WSL Kernel" -MaxRetries 2 | Out-Null

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
        # When running as Windows admin use -u root + DEBIAN_FRONTEND=noninteractive
        # (avoids the "unable to initialize frontend: Dialog" debconf noise).
        # When not admin (e.g. -OnlyWslPackages without elevation) fall back to sudo.
        # ScriptBlocks contain no variable references so they survive Invoke-WithTimeout serialisation.
        if ($script:isAdmin) {
            $aptUpdateBlock  = { & wsl.exe -u root sh -c "DEBIAN_FRONTEND=noninteractive apt-get update -q" }
            $aptUpgradeBlock = { & wsl.exe -u root sh -c "DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y -q" }
            $aptRemoveBlock  = { & wsl.exe -u root sh -c "DEBIAN_FRONTEND=noninteractive apt-get autoremove -y -q" }
        } else {
            $aptUpdateBlock  = { & wsl.exe sudo apt-get update }
            $aptUpgradeBlock = { & wsl.exe sudo apt-get full-upgrade -y }
            $aptRemoveBlock  = { & wsl.exe sudo apt-get autoremove -y }
        }
        if (-not (Invoke-WithRetry -Action $aptUpdateBlock -ActionName "apt-get update" -MaxRetries 2)) {
            Write-Status "apt-get update failed after retries" -Type Error
            $failedItems["WSL"] += "apt-get update failed"
        } else {
            # full-upgrade: MaxRetries 1 — can carry partial state, retry conservatively
            if (Invoke-WithRetry -Action $aptUpgradeBlock -ActionName "apt-get full-upgrade" -MaxRetries 1) {
                $updatedItems["WSL"] += "Updated packages in default WSL distro"
                $autoremoveOut = & $aptRemoveBlock 2>&1
                $autoremoveExit = $LASTEXITCODE
                $autoremoveOut | ForEach-Object { Write-Log "  [autoremove] $_" -Level "DEBUG" }
                if ($autoremoveExit -ne 0) {
                    Write-Status "apt-get autoremove failed (exit $autoremoveExit)" -Type Warning
                    Write-Log "apt-get autoremove exited $autoremoveExit" -Level "INFO"
                }
            } else {
                Write-Status "apt-get full-upgrade failed after retries" -Type Error
                $failedItems["WSL"] += "apt-get full-upgrade failed"
            }
        }
    }
}

# ══════════════════════════════════════════════════════
# JAVASCRIPT ECOSYSTEM
# ══════════════════════════════════════════════════════
if (Test-GroupWanted 'npm (Node Package Manager) Packages','pnpm','Bun','Deno') {
Write-GroupHeader "JavaScript"
}

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
        Write-Log "npm: prefix '$npmPrefix' not writable — skipping updates." -Level "INFO"
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
    Invoke-SelfUpdateWithPrefetch -ToolName "pnpm" -Key "pnpm" -Action { & pnpm self-update 2>&1 | Out-Null }
}

# --- Update Bun ---
Update-Section "Bun" ($NoBun -or $OnlyWsl -or $OnlyWslPackages) { Get-Command bun -ErrorAction SilentlyContinue } {
    Invoke-SelfUpdateWithPrefetch -ToolName "Bun" -Key "Bun" `
        -Action { & bun upgrade 2>&1 | Out-Null } -ActionName "bun upgrade"
}

# --- Update Deno ---
Update-Section "Deno" ($NoDeno -or $OnlyWsl -or $OnlyWslPackages) { Get-Command deno -ErrorAction SilentlyContinue } {
    Invoke-SelfUpdateWithPrefetch -ToolName "Deno" -Key "Deno" `
        -Action { & deno upgrade 2>&1 | Out-Null } -ActionName "deno upgrade"
}

# ══════════════════════════════════════════════════════
# PYTHON ECOSYSTEM
# ══════════════════════════════════════════════════════
if (Test-GroupWanted 'pipx packages','uv','Poetry','Rye') {
Write-GroupHeader "Python"
}

# --- Update pipx packages ---
Update-Section "pipx packages" ($NoPipx -or $OnlyWsl -or $OnlyWslPackages) { Get-Command pipx -ErrorAction SilentlyContinue } {
    Write-Status "Upgrading all pipx packages..." -Type Action
    Write-Log "Upgrading pipx packages."
    # Force Python UTF-8 mode so pipx can print emoji in its output without crashing
    # on Windows consoles with cp1252 or other narrow code pages.
    $env:PYTHONUTF8 = '1'
    Invoke-UpdateStep -Key "pipx" -ActionName "pipx upgrade-all" -Action { & pipx upgrade-all } -SuccessLabel "All pipx packages" | Out-Null
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
    } else {
        Write-Status "uv self update failed (exit $LASTEXITCODE)" -Type Error
        $failedItems["uv"] += "uv self update (exit $LASTEXITCODE)"
    }

    Write-Status "Upgrading uv-managed Python runtimes..." -Type Action
    Invoke-UpdateStep -Key "uv" -ActionName "uv python install --upgrade" -Action { & uv python install --upgrade } -SuccessLabel "Python runtimes" | Out-Null

    Write-Status "Upgrading all uv tools..." -Type Action
    Invoke-UpdateStep -Key "uv" -ActionName "uv tool upgrade --all" -Action { & uv tool upgrade --all } -SuccessLabel "All uv tools" | Out-Null
}

# --- Update Poetry ---
Update-Section "Poetry" ($NoPoetry -or $OnlyWsl -or $OnlyWslPackages) { Get-Command poetry -ErrorAction SilentlyContinue } {
    Invoke-SelfUpdateWithPrefetch -ToolName "Poetry" -Key "Poetry" `
        -Action { & poetry self update 2>&1 | Out-Null } -ActionName "poetry self update"
}

# --- Update Rye ---
Update-Section "Rye" ($NoRye -or $OnlyWsl -or $OnlyWslPackages) { Get-Command rye -ErrorAction SilentlyContinue } {
    Invoke-SelfUpdateWithPrefetch -ToolName "Rye" -Key "Rye" `
        -Action { & rye self update 2>&1 | Out-Null } -ActionName "rye self update"
}

# ══════════════════════════════════════════════════════
# OTHER LANGUAGES
# ══════════════════════════════════════════════════════
if (Test-GroupWanted '.NET Global Tools','Rust (rustup)','Ruby Gems','Composer') {
Write-GroupHeader "Other Languages"
}

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
                Write-Status "Updated: $($r.Id)" -Type Detail
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
    Invoke-UpdateStep -Key "Rust" -ActionName "rustup update" -Action { & rustup update } -SuccessLabel "Rust toolchain" | Out-Null
}

# --- Update Ruby Gems ---
Update-Section "Ruby Gems" ($NoGem -or $OnlyWsl -or $OnlyWslPackages) { Get-Command gem -ErrorAction SilentlyContinue } {
    Write-Status "Updating RubyGems system..." -Type Action
    Write-Log "Updating Ruby Gems."
    Invoke-UpdateStep -Key "Ruby Gems" -ActionName "gem update --system" -Action { & gem update --system } -SuccessLabel "RubyGems system" | Out-Null
    Write-Status "Updating all gems..." -Type Action
    Invoke-UpdateStep -Key "Ruby Gems" -ActionName "gem update" -Action { & gem update } -SuccessLabel "All gems" | Out-Null
}

# --- Update Composer ---
Update-Section "Composer" ($NoComposer -or $OnlyWsl -or $OnlyWslPackages) { Get-Command composer -ErrorAction SilentlyContinue } {
    Invoke-SelfUpdateWithPrefetch -ToolName "Composer" -Key "Composer" -Action { & composer self-update 2>&1 | Out-Null }
}

# ══════════════════════════════════════════════════════
# CLOUD / DEVOPS
# ══════════════════════════════════════════════════════
if (Test-GroupWanted 'Google Cloud SDK','Azure CLI','Android SDK','Helm plugins','krew plugins') {
Write-GroupHeader "Cloud / DevOps"
}

# --- Update Google Cloud SDK ---
Update-Section "Google Cloud SDK" ($NoGCloud -or $OnlyWsl -or $OnlyWslPackages) { Get-Command gcloud -ErrorAction SilentlyContinue } {
    Write-Status "Updating gcloud components..." -Type Action
    # Don't retry: gcloud often exits non-zero when installed via an external
    # package manager (Scoop/Choco/apt) because the component manager is disabled.
    # Capture output so we can distinguish real failures from benign ones.
    $gcloudOut  = & gcloud components update --quiet 2>&1
    $gcloudCode = $LASTEXITCODE
    $gcloudText = ($gcloudOut | Out-String)
    $gcloudOut | ForEach-Object { Write-Log "  [gcloud] $_" -Level "DEBUG" }

    if ($gcloudText -match 'disabled for this installation' -or
        $gcloudText -match 'managed by an external package manager' -or
        $gcloudText -match 'installation is managed by') {
        Write-Status "gcloud is managed by an external package manager — skipping" -Type Skip
        Write-Log "gcloud: component manager disabled (external install)" -Level "INFO"
        $script:skippedSections += "Google Cloud SDK (managed externally)"
        return
    }

    # gcloud refuses Self-Update in non-interactive mode when using bundled Python:
    # copy it to a separate location, set CLOUDSDK_PYTHON (process-scope only), retry.
    if ($gcloudCode -ne 0 -and $gcloudText -match 'Cannot use bundled Python installation') {
        Write-Status "gcloud needs CLOUDSDK_PYTHON workaround — copying bundled Python..." -Type Action
        $copyOut  = & gcloud components copy-bundled-python 2>&1
        $copyCode = $LASTEXITCODE
        $pythonPath = ($copyOut | Out-String).Trim()
        if ($copyCode -eq 0 -and $pythonPath -and (Test-Path $pythonPath)) {
            $env:CLOUDSDK_PYTHON = $pythonPath
            Write-Log "gcloud: CLOUDSDK_PYTHON set to $pythonPath, retrying update." -Level "INFO"
            $gcloudOut  = & gcloud components update --quiet 2>&1
            $gcloudCode = $LASTEXITCODE
            $gcloudText = ($gcloudOut | Out-String)
            $gcloudOut | ForEach-Object { Write-Log "  [gcloud-retry] $_" -Level "DEBUG" }
        } else {
            Write-Status "gcloud copy-bundled-python failed (exit $copyCode)" -Type Error
            Write-Log "gcloud copy-bundled-python output: $copyOut" -Level "INFO"
            $failedItems["Google Cloud SDK"] += "copy-bundled-python failed (exit $copyCode)"
            return
        }
    }

    if ($gcloudCode -eq 0 -or $gcloudText -match 'All components are up to date') {
        $updatedItems["Google Cloud SDK"] += "All components"
    } else {
        Write-Status "gcloud components update failed (exit $gcloudCode)" -Type Error
        Write-Log "gcloud output: $gcloudText" -Level "INFO"
        $failedItems["Google Cloud SDK"] += "gcloud components update (exit $gcloudCode)"
    }
}

# --- Update Azure CLI ---
Update-Section "Azure CLI" ($NoAzureCli -or $OnlyWsl -or $OnlyWslPackages) { Get-Command az -ErrorAction SilentlyContinue } {
    Write-Status "Updating Azure CLI and extensions..." -Type Action
    Invoke-UpdateStep -Key "Azure CLI" -ActionName "az upgrade" -Action { & az upgrade --yes --all } -SuccessLabel "Azure CLI + extensions" | Out-Null
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
    Invoke-UpdateStep -Key "krew plugins" -ActionName "kubectl krew upgrade" -Action { & kubectl krew upgrade 2>&1 | Out-Null } -SuccessLabel "All krew plugins" | Out-Null
}

# ══════════════════════════════════════════════════════
# DEV TOOLING
# ══════════════════════════════════════════════════════
if (Test-GroupWanted 'Visual Studio Code Extensions','GitHub CLI Extensions') {
Write-GroupHeader "Dev Tooling"
}

# --- Update Visual Studio Code Extensions ---
Update-Section "Visual Studio Code Extensions" ($NoVsCode -or $OnlyWsl -or $OnlyWslPackages) { Get-Command code -ErrorAction SilentlyContinue } {
    # A running VS Code can hold its extensions directory locked, making `code --install-extension`
    # fail with a bare exit 1 and no useful message — same class of problem as Git.Git vs. bash.exe
    # (see Test-GitBinariesInUse). Warn up front so a failure isn't a mystery. See issue #9.
    if (Get-Process -Name 'Code','Code - Insiders' -ErrorAction SilentlyContinue) {
        Write-Status "VS Code is currently running — extension updates may fail while files are locked" -Type Warning
        Write-Log "VS Code Extensions: VS Code process detected running before update." -Level "INFO"
    }
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
                    Write-Status "Updated: $($r.Id)" -Type Detail
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
                    Write-Status "Updated: $extensionId" -Type Detail
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
    Invoke-UpdateStep -Key "GitHub CLI Extensions" -ActionName "gh extension upgrade --all" -Action { & gh extension upgrade --all } -SuccessLabel "All extensions" | Out-Null
}

# ══════════════════════════════════════════════════════
# TYPESETTING
# ══════════════════════════════════════════════════════
if (Test-GroupWanted 'TeX Live') {
Write-GroupHeader "Typesetting"
}

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

$hasUpdates        = $false
$totalUpdatedItems = 0
foreach ($key in $updatedItems.Keys) {
    if ($updatedItems[$key].Count -gt 0) {
        $hasUpdates = $true
        $totalUpdatedItems += $updatedItems[$key].Count
        Write-Host "  $([char]0x2713)  " -NoNewline -ForegroundColor Green
        Write-Host "$key" -NoNewline -ForegroundColor Green
        Write-Host "  $($updatedItems[$key].Count) updated: " -NoNewline -ForegroundColor Gray
        Write-Host (Format-SummaryLine -Items $updatedItems[$key]) -ForegroundColor Gray
        $script:lastLineBlank = $false
    }
}

if (-not $hasUpdates) {
    Write-Status "Everything already up-to-date" -Type Success
}
Write-BlankLine

$hasFailures      = $false
$totalFailedItems = 0
foreach ($key in $failedItems.Keys) {
    if ($failedItems[$key].Count -gt 0) {
        $hasFailures = $true
        $totalFailedItems += $failedItems[$key].Count
        Write-Host "  $([char]0x2717)  " -NoNewline -ForegroundColor Red
        Write-Host "$key" -NoNewline -ForegroundColor Red
        Write-Host "  $($failedItems[$key].Count) failed: " -NoNewline -ForegroundColor DarkRed
        Write-Host (Format-SummaryLine -Items $failedItems[$key]) -ForegroundColor DarkRed
        $script:lastLineBlank = $false
    }
}

if (-not $hasFailures) {
    Write-Status "No failures" -Type Success
}

if ($skippedSections.Count -gt 0) {
    Write-BlankLine
    Write-Host "  $([char]0x25CB)  " -NoNewline -ForegroundColor DarkGray
    Write-Host "Skipped ($($skippedSections.Count)): " -NoNewline -ForegroundColor DarkGray
    Write-Host (Format-SummaryLine -Items $skippedSections -MaxShown 12) -ForegroundColor DarkGray
    $script:lastLineBlank = $false
}

# Section timings — only show sections that took 5 s or more
$slowSections = $script:sectionTimings.GetEnumerator() |
    Where-Object { $_.Value.TotalSeconds -ge 5 } |
    Sort-Object { $_.Value } -Descending
if ($slowSections) {
    Write-BlankLine
    Write-Host "  $([char]0x25CB)  Timings" -ForegroundColor DarkGray
    $slowSections | ForEach-Object {
        Write-Host "       $([char]0x2022) $($_.Key): $(Format-Elapsed $_.Value)" -ForegroundColor DarkGray
    }
    $script:lastLineBlank = $false
}

# One-line stats
$updatedCount = ($updatedItems.Values | Where-Object { $_.Count -gt 0 }).Count
$failedCount  = ($failedItems.Values  | Where-Object { $_.Count -gt 0 }).Count
$skippedCount = $skippedSections.Count

# Closing card — bookends the startup banner with the same rounded-box style.
Write-Host ""
if ($hasFailures) {
    Write-ResultBox -BorderColor Red -LineColors @('Red', 'Gray') -Lines @(
        "$([char]0x2717)  Completed with failures  $([char]0x00B7)  $(Format-Elapsed $totalElapsed)"
        "$updatedCount updated ($totalUpdatedItems items)  $([char]0x00B7)  $failedCount failed ($totalFailedItems items)  $([char]0x00B7)  $skippedCount skipped"
    )
} else {
    Write-ResultBox -BorderColor Green -LineColors @('Green', 'Gray') -Lines @(
        "$([char]0x2713)  All done  $([char]0x00B7)  $(Format-Elapsed $totalElapsed)"
        "$updatedCount updated ($totalUpdatedItems items)  $([char]0x00B7)  $failedCount failed ($totalFailedItems items)  $([char]0x00B7)  $skippedCount skipped"
    )
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
        # Use INFO so Write-Log doesn't re-emit the already-shown terminal line via Write-Status
        Write-Log "  Failed  [$key]: $($failedItems[$key] -join ', ')"
    }
}
if ($skippedSections.Count -gt 0) {
    Write-Log "  Skipped: $($skippedSections -join ', ')"
}
Write-Log "Total time: $(Format-Elapsed $totalElapsed)"
Write-Log "==================="

# --- Exit-Code-Entscheidung: Ok / Partial / HardFailure ---
$attemptedCount = $updatedCount + $failedCount
$exitCode = $script:ExitOk
if ($hasFailures) {
    if ($attemptedCount -gt 0 -and ($failedCount / $attemptedCount) -ge 0.5) {
        $exitCode = $script:ExitHardFailure
        Write-Log "Script completed with hard failure ($failedCount/$attemptedCount sections failed)."
    } else {
        $exitCode = $script:ExitPartial
        Write-Log "Script completed with partial failures ($failedCount/$attemptedCount sections failed)."
    }
} else {
    Write-Log "Script completed successfully."
}

# --- Notifications ---
$failedSectionList = @()
foreach ($key in $failedItems.Keys) {
    if ($failedItems[$key].Count -gt 0) { $failedSectionList += $key }
}
$summaryHash = @{
    Updated        = $updatedCount
    Failures       = $failedCount
    Skipped        = $skippedCount
    Duration       = Format-Elapsed $totalElapsed
    FailedSections = $failedSectionList
}
Send-UpdateNotifications -HasFailures $hasFailures -Summary $summaryHash

# --- Machine-readable JSON summary (-OutputJson) ---
if ($OutputJson) {
    # Only non-empty categories — a JSON consumer shouldn't have to filter out 20+ empty arrays
    # for sections that either weren't touched (-Only) or had nothing to do.
    $jsonUpdated = @{}
    foreach ($key in $updatedItems.Keys) { if ($updatedItems[$key].Count -gt 0) { $jsonUpdated[$key] = $updatedItems[$key] } }
    $jsonFailed = @{}
    foreach ($key in $failedItems.Keys)  { if ($failedItems[$key].Count -gt 0)  { $jsonFailed[$key]  = $failedItems[$key] } }

    $jsonReport = [ordered]@{
        version         = $script:VersionString
        startTime       = $scriptStartTime.ToString('o')
        durationSeconds = [int]$totalElapsed.TotalSeconds
        exitCode        = $exitCode
        categoriesUpdated = $updatedCount
        categoriesFailed  = $failedCount
        categoriesSkipped = $skippedCount
        itemsUpdated      = $totalUpdatedItems
        itemsFailed       = $totalFailedItems
        updated  = $jsonUpdated
        failed   = $jsonFailed
        skipped  = $skippedSections
    }
    try {
        $jsonReport | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputJson -Encoding UTF8 -ErrorAction Stop
        Write-Log "JSON summary written to $OutputJson" -Level "INFO"
    } catch {
        Write-Log "Failed to write JSON summary to $OutputJson`: $($_.Exception.Message)" -Level "WARN"
    }
}

# --- Cleanup: stop any leftover -Parallel prefetch jobs nobody consumed ---
Stop-ParallelPrefetch

# --- Lock-Release ---
Unlock-UpdateRun -LockPath $script:LockFilePath

# --- Auto-Reboot bei erkenntlichem Pending Reboot ---
if ($AutoReboot -and (Test-PendingReboot)) {
    Write-Status "Pending reboot detected — rebooting in 60 seconds (auto-reboot)" -Type Warning
    Write-Log "AutoReboot: pending reboot detected, triggering shutdown /r /t 60." -Level "INFO"
    & shutdown.exe /r /t 60 /c "update.ps1 auto-reboot" | Out-Null
}

exit $exitCode
