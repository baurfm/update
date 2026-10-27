# Parameters

[Back to README](../README.md) · Scheduling and notifications: [unattended.md](unattended.md)

## Skip flags (one per section)

| Parameter | Description |
|-----------|-------------|
| `-NoPowerShell` | Skip PowerShell Modules |
| `-NoScoop` | Skip Scoop + its packages |
| `-NoWinget` | Skip Winget apps |
| `-NoChoco` | Skip Chocolatey packages |
| `-NoOhMyPosh` | Skip Oh My Posh upgrade |
| `-NoWindowsUpdate` | Skip Windows Update (runs only when elevated; use `-Sudo` to force it) |
| `-NoWsl` | Skip WSL kernel + distro packages |
| `-NoNpm` | Skip global npm packages |
| `-NoPnpm` | Skip pnpm self-update |
| `-NoBun` | Skip Bun upgrade |
| `-NoDeno` | Skip Deno upgrade |
| `-NoPipx` | Skip pipx packages |
| `-NoUv` | Skip uv self-update, Python runtime upgrades, and `uv tool upgrade --all` |
| `-NoPoetry` | Skip Poetry self-update |
| `-NoRye` | Skip Rye self-update |
| `-NoDotnet` | Skip .NET global tools |
| `-NoRust` | Skip Rust toolchain (rustup) |
| `-NoGem` | Skip Ruby Gems |
| `-NoComposer` | Skip Composer self-update |
| `-NoGCloud` | Skip Google Cloud SDK components |
| `-NoAzureCli` | Skip Azure CLI + extensions |
| `-NoAndroid` | Skip Android SDK components |
| `-NoHelm` | Skip Helm plugin updates |
| `-NoKrew` | Skip krew (kubectl plugin manager) |
| `-NoVsCode` | Skip VS Code extensions |
| `-NoGhExt` | Skip GitHub CLI extensions |
| `-NoClaude` | Skip Claude Code self-update |
| `-NoCursor` | Skip Cursor extensions |
| `-NoTex` | Skip TeX Live |

## Mode flags

| Parameter | Alias | Description |
|-----------|-------|-------------|
| `-Help` | `-h`, `-?` | Display detailed help message and exit |
| `-DryRun` | - | Preview what would run without executing any updates |
| `-Sudo` | - | Re-launch elevated immediately, skipping pre-checks |
| `-NoSelfUpdate` | - | Skip the GitHub self-update check at startup |
| `-OnlyWsl` | - | Update only WSL (kernel + distro packages) |
| `-OnlyWslPackages` | - | Update only WSL distro packages (skip kernel) |
| `-Only <names>` | - | Run only sections whose name contains one of these strings (substring match, e.g. `-Only npm,uv`); everything else is skipped silently |
| `-Parallel` | - | Pre-launch independent, quick tool self-updates (Oh My Posh, pnpm, Bun, Deno, Poetry, Rye, Composer) as background jobs before the slower sections, instead of one after another |
| `-OutputJson <path>` | - | Write a machine-readable JSON summary of the run to this path after completion |
| `-SkipWslSudoConfig` | - | Skip automatic passwordless-sudo setup for WSL |
| `-LogFile <path>` | - | Override log file path (default: `logs/update.log`) |
| `-Verbose` | - | Full blow-by-blow output — every step and raw tool output, not just results (standard PowerShell common parameter). Default output shows headers + results only; `-Quiet` only warnings, errors and the summary |
| `-PathSetup On\|Off\|Status` | - | The `update` command on PATH, then exit: `On` creates the `update.cmd` shim + User PATH entry (only if `update` isn't already reachable, e.g. via Scoop), `Off` removes both and keeps them off on future runs, `Status` shows what `update` resolves to |

## Exit Codes

| Code | Constant | Meaning |
| ---- | -------- | ------- |
| `0` | `ExitOk` | All sections succeeded |
| `1` | `ExitPartial` | At least one section failed, but fewer than 50% |
| `2` | `ExitHardFailure` | 50%+ of attempted sections failed |
| `3` | `ExitElevationMissing` | Admin required but elevation failed |
| `4` | `ExitLockActive` | Another instance is already running (lock held) |
| `5` | `ExitNetworkDown` | No configured update host reachable |
| `6` | `ExitTimedOut` | (reserved for future per-section hard timeout tracking) |
