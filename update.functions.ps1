<#
.SYNOPSIS
    Pure, side-effect-free helper functions for update.ps1.

.DESCRIPTION
    Dot-sourced by update.ps1 near the top of the script. Everything in this file is intended to
    be unit-testable in isolation with Pester (see tests/update.functions.Tests.ps1) — no Write-
    Host, no file/network/process I/O, no dependency on update.ps1's orchestration state beyond
    what's explicitly documented per function ($script:OnlyFilter for the -Only filter helpers).

    Functions that have real side effects (terminal output, external commands, locking,
    notifications, the tool-update sections themselves) stay in update.ps1 — this file is
    deliberately narrow in scope, not a step toward a full module.
#>

# Builds the JSON-serializable record for the Git.Git pending-update flag (logs/pending-git-
# update.json): increments skipCount on repeat detections, preserves the original firstDetected
# timestamp across runs. Pulled out of Set-PendingGitUpdate (which does the actual file I/O) so
# this "don't lose firstDetected, do increment skipCount" logic is unit-testable — exactly the
# kind of small stateful-looking-but-actually-pure logic that's easy to get subtly wrong (e.g.
# resetting firstDetected on every run, which would make skipCount duration tracking useless).
function Build-PendingGitUpdateRecord {
    param(
        [AllowNull()] $Existing,
        [Parameter(Mandatory)] [string[]]$Blockers,
        [Parameter(Mandatory)] [string]$Now
    )
    $firstSeen = if ($Existing -and $Existing.firstDetected) { $Existing.firstDetected } else { $Now }
    $count     = if ($Existing -and $Existing.skipCount)     { [int]$Existing.skipCount + 1 } else { 1 }
    return [ordered]@{
        package       = 'Git.Git'
        firstDetected = $firstSeen
        lastDetected  = $Now
        skipCount     = $count
        blockers      = $Blockers
    }
}

# Helper: format a TimeSpan as "4m 12s" / "38s" / "1h 2m"
# Floor, not [int]: [int] rounds half-to-even, so 90s rendered as "2m 30s" and the heartbeat
# visibly jumped backwards ("2m 30s" -> "2m 0s").
function Format-Elapsed {
    param([TimeSpan]$ts)
    if ($ts.TotalHours -ge 1)   { return "$([Math]::Floor($ts.TotalHours))h $($ts.Minutes)m" }
    if ($ts.TotalMinutes -ge 1) { return "$([Math]::Floor($ts.TotalMinutes))m $($ts.Seconds)s" }
    return "$([Math]::Floor($ts.TotalSeconds))s"
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

# Normalizes the raw -Only argument into a flat list of non-empty patterns. Needed because
# "-Only npm,uv" only arrives as a 2-element array when the script is invoked from a PowerShell
# prompt — via `pwsh -File` (the update.cmd shim, Scheduled Task, sudo/runas elevation re-launch)
# it arrives as the single literal string "npm,uv", which matched nothing at all.
function ConvertTo-OnlyFilter {
    param([AllowNull()] [AllowEmptyCollection()] [string[]]$Only)
    return @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# True if $Latest is a newer version than $Installed. PowerShellGet reports prerelease versions
# as strings like "3.0.0-preview1", which a plain [version] cast rejects with an exception — so
# compare the numeric part, and fall back to plain string inequality if that still can't parse.
function Test-VersionNewer {
    param(
        [Parameter(Mandatory)] [string]$Installed,
        [Parameter(Mandatory)] [string]$Latest
    )
    $i = $null; $l = $null
    if ([version]::TryParse(($Installed -split '[-+]')[0], [ref]$i) -and
        [version]::TryParse(($Latest    -split '[-+]')[0], [ref]$l)) {
        if ($l -ne $i) { return ($l -gt $i) }
        # Same numeric version: only a prerelease -> stable transition counts as newer.
        return ($Installed -match '-' -and $Latest -notmatch '-')
    }
    return ($Latest -ne $Installed)
}

# Classifies a successful self-update by comparing the tool's --version output before and after.
# 'Unknown' when either probe produced nothing (tool has no cheap version command, or it failed) —
# callers then fall back to the old behavior of counting the run as an update.
function Get-SelfUpdateOutcome {
    param([AllowNull()] [string]$Before, [AllowNull()] [string]$After)
    if ([string]::IsNullOrWhiteSpace($Before) -or [string]::IsNullOrWhiteSpace($After)) { return 'Unknown' }
    if ($Before.Trim() -eq $After.Trim()) { return 'Current' }
    return 'Updated'
}

# True if a successful update command's output says it had nothing to do. Every phrase below was
# taken from real tool output (live run 2026-10-27) — without this, "Python runtimes",
# "All components", "Azure CLI + extensions" etc. were counted as updated on every single run.
$script:NoOpPatterns = @(
    'Nothing to upgrade'                                   # uv tool upgrade --all
    'already on the latest supported patch release'       # uv python install --upgrade
    'All requested versions already installed'            # uv python install --upgrade (older uv)
    'All components are up to date'                       # gcloud components update
    'You already have the latest azure-cli version'       # az upgrade
    'No updates available'                                 # sdkmanager --update
    'Latest versions for all apps are installed'          # scoop update *
    'Versions did not change after running'               # pipx upgrade-all
    'No packages upgraded'                                 # pipx upgrade-all
    'upgraded 0/'                                          # choco upgrade all ("Chocolatey upgraded 0/12 packages")
    'Latest version already installed'                    # gem update --system
    '0 upgraded, 0 newly installed, 0 to remove'          # apt-get full-upgrade (WSL)
)
function Test-NoOpOutput {
    param([AllowNull()] [AllowEmptyCollection()] [object[]]$Output)
    if (-not $Output) { return $false }
    $text = ($Output | ForEach-Object { "$_" }) -join "`n"
    foreach ($p in $script:NoOpPatterns) {
        if ($text -match [regex]::Escape($p)) { return $true }
    }
    return $false
}

# Extracts extension IDs from `code --update-extensions` output. VS Code prints either
# "No extension to update" or an "Updating extensions: a.b, c.d" line followed by one
# "Extension 'a.b' v1.2.3 was successfully updated." line per extension.
function Get-VsCodeUpdatedExtensionIds {
    param([AllowNull()] [AllowEmptyCollection()] [AllowEmptyString()] [string[]]$Output)
    $ids = @()
    foreach ($line in $Output) {
        if ($line -match "Extension '([^']+)'.*successfully (updated|installed)") { $ids += $Matches[1] }
    }
    if ($ids.Count -eq 0) {
        $listLine = $Output | Where-Object { $_ -match '^\s*Updating extensions:\s*(.+)$' } | Select-Object -First 1
        if ($listLine -and $listLine -match '^\s*Updating extensions:\s*(.+)$') {
            $ids = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }
    }
    return @($ids | Select-Object -Unique)
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

# Shared row-extraction core for both Get-WingetUpgradableIds and Get-WingetExplicitTargetIds:
# given the full output and an already-located header line, walks the table starting right
# after it and returns package IDs by slicing each row at the Id/Version column positions.
# Stops at the first blank line (winget always ends a table with one — reading past it risks
# column-slicing a later section's free-form text into garbage "IDs", see #8's fix history).
# Also stops at winget's own summary line ("N upgrades available." / "N package(s) are pinned
# ..."), matched by its specific wording rather than a generic leading-digit check — a generic
# check would also misfire on a legitimate digit-led package name like "7-Zip".
# -SkipPinned additionally skips inline "Pinned" rows (only the main upgrade table marks
# user-pinned packages this way; the explicit-targeting table has no such marker).
function Get-WingetTableIds {
    param(
        # AllowEmptyString is required: $Lines legitimately contains an empty-string element for
        # the table's own trailing blank line — without it, [Parameter(Mandatory)] on an array
        # rejects the WHOLE array the moment any single element is empty, throwing "Cannot bind
        # argument ... because it is an empty string" (a well-known PowerShell gotcha: mandatory
        # array parameters validate every element, not just the array as a whole).
        [Parameter(Mandatory)] [AllowEmptyString()] [string[]]$Lines,
        [Parameter(Mandatory)] [string]$Header,
        [switch]$SkipPinned
    )
    $ids    = @()
    $idCol  = $Header.IndexOf('Id')
    $verCol = $Header.IndexOf('Version')
    if ($idCol -lt 0 -or $verCol -le $idCol) { return $ids }   # malformed header — can't parse

    $headerIdx = [Array]::IndexOf($Lines, $Header)
    for ($i = $headerIdx + 2; $i -lt $Lines.Length; $i++) {
        $line = $Lines[$i]
        if ($line.Trim().Length -eq 0)                       { break }
        # NOTE: no trailing \b after the package(s) alternative — ")" and the following space
        # are both non-word characters, so \b would never match there and silently break the match.
        if ($line -match '^\d+\s+(upgrades?\b|package\(s\))') { break }
        if ($SkipPinned -and $line -match '\bPinned\b')      { continue }
        if ($line -match '^\s*-+\s*$')                       { continue }
        if ($line.Length -le $idCol)                         { continue }
        $pkg = $line.Substring($idCol, [Math]::Min($verCol - $idCol, $line.Length - $idCol)).Trim()
        if ($pkg.Length -gt 0) { $ids += $pkg }
    }
    return $ids
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
    if (-not $WingetOutput -or -not ($WingetOutput -join '').Trim()) { return @() }
    if (($WingetOutput -join "`n") -match 'No applicable upgrades were found') { return @() }

    $lines  = $WingetOutput -split [System.Environment]::NewLine
    # Winget sometimes emits progress lines before the table header; find the real header
    # by locating the first line that contains both 'Id' and 'Version' columns.
    $header = $lines | Where-Object { $_ -match '\bId\b' -and $_ -match '\bVersion\b' } |
                       Select-Object -First 1
    if (-not $header) { return @() }

    return Get-WingetTableIds -Lines $lines -Header $header -SkipPinned
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
    if (-not $WingetOutput -or -not ($WingetOutput -join '').Trim()) { return @() }
    $lines = $WingetOutput -split [System.Environment]::NewLine
    $markerIdx = -1
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match 'require explicit targeting') { $markerIdx = $i; break }
    }
    if ($markerIdx -lt 0) { return @() }

    $header = $null
    for ($i = $markerIdx + 1; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '\bId\b' -and $lines[$i] -match '\bVersion\b') { $header = $lines[$i]; break }
    }
    if (-not $header) { return @() }

    return Get-WingetTableIds -Lines $lines -Header $header
}
