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
function Format-Elapsed {
    param([TimeSpan]$ts)
    if ($ts.TotalHours -ge 1)   { return "$([int]$ts.TotalHours)h $($ts.Minutes)m" }
    if ($ts.TotalMinutes -ge 1) { return "$([int]$ts.TotalMinutes)m $($ts.Seconds)s" }
    return "$([int]$ts.TotalSeconds)s"
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
