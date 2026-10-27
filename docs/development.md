# Development

[Back to README](../README.md)

## Layout

| File | Purpose |
|------|---------|
| `update.ps1` | The whole update run: sections, terminal output, elevation, lock, scheduling, notifications |
| `update.functions.ps1` | Pure, side-effect-free helpers (winget parsers, formatting, `-Only` matching, version comparison) — dot-sourced by `update.ps1`, unit-tested in isolation |
| `tests/update.functions.Tests.ps1` | Pester tests for `update.functions.ps1` |
| `PSScriptAnalyzerSettings.psd1` | Analyzer rules excluded on purpose (Write-Host etc.) |

## Before every commit

```powershell
# 1. Unit tests
Invoke-Pester -Path .\tests -Output Detailed

# 2. Parse check on BOTH hosts — PS7-only syntax (?:, ??, &&) breaks PS5.1 parsing entirely
$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile("$PWD\update.ps1",[ref]$null,[ref]$e); $e
#    run once in powershell.exe and once in pwsh

# 3. Smoke test, then a real run of the touched sections
.\update.ps1 -DryRun
.\update.ps1 -Only <section> -NoWinget -NoWsl -NoSelfUpdate
```

`-DryRun` alone isn't enough for output or elevation changes. Exclude elevation-triggering
sections (`-NoWinget -NoWsl`) in non-interactive sessions — a UAC prompt there hangs.

CI (`.github/workflows/lint.yml`) runs the PS5.1 + PS7 parse check, PSScriptAnalyzer and Pester
on every push.

## Adding a section

1. Wrap it in `Update-Section "Name" ($NoX -or $OnlyWsl -or $OnlyWslPackages) { Get-Command tool } { ... }`
2. Run external commands through `Invoke-WithRetry` / `Invoke-UpdateStep`; self-updating tools
   through `Invoke-SelfUpdate` with a `-VersionCommand` so no-ops aren't counted as updates
3. Add the summary key to `$sectionKeys` and the section to the matching group (and its
   `Test-GroupWanted` list)
4. Add a `[switch]$NoX` parameter, document it in [tools.md](tools.md) and [parameters.md](parameters.md)
5. Bump the version in the script header and `$script:VersionString`, add a [CHANGELOG](../CHANGELOG.md) entry

Pure logic goes into `update.functions.ps1` with Pester tests; anything with side effects stays
in `update.ps1`.
