# Windows Development Environment Update Script

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A comprehensive PowerShell script that automates the update process for multiple development tools and package managers on Windows systems. This script provides granular control over which components to update, making it perfect for maintaining a clean and up-to-date development environment.

## 🚀 Features

- **Comprehensive Coverage**: Updates 26 development tool categories across package managers, language runtimes, CLIs and IDEs
- **Selective Updates**: Skip specific sections using command-line parameters (`-NoX` flags), or run only a targeted subset with `-Only <names>`
- **Dry-Run Mode**: Preview which sections would run without making any changes (`-DryRun`)
- **Parallel Pre-Checks**: Fast up-front detection of which sections actually need updates — reduces elevation prompts and runtime
- **Parallel Prefetch**: `-Parallel` pre-launches independent, quick tool self-updates (Oh My Posh, pnpm, Bun, Deno, Poetry, Rye, Composer) as background jobs so their network-bound work overlaps with the slower Scoop/Winget/WSL sections
- **Machine-Readable Output**: `-OutputJson <path>` writes a JSON run summary for scripting/dashboards
- **Retry with Backoff**: All external commands wrapped in `Invoke-WithRetry` for transient-error resilience
- **Automatic WSL Sudo Config**: Writes a NOPASSWD sudoers entry for `apt-get` on first run (skip with `-SkipWslSudoConfig`)
- **Self-Update Check**: Verifies the script itself is current via GitHub on startup (disable with `-NoSelfUpdate`)
- **Centralized Logs**: Output and past logs stored in a `logs/` subdirectory (auto-rotated, last 30 archives kept)
- **Administrative Support**: Lazy elevation based on pre-checks, also supports the Windows `sudo` command and the `-Sudo` flag for immediate elevation
- **Unattended / Scheduled Operation**: `-Unattended` flag silences all interactive prompts, suppresses progress bars, sets per-command timeouts, and enables notifications. `-RegisterSchedule` installs a SYSTEM-level Scheduled Task for nightly auto-runs. Lock-file prevents overlapping runs. Network pre-check aborts early if offline. Differentiates exit codes 0–6 for CI/monitoring use.
- **Notifications**: BurntToast toast notifications, generic webhook (ntfy.sh compatible), or Windows Event Log (`-NotifyToast`, `-NotifyWebhook`, `-NotifyEventLog`).
- **Auto-Reboot**: `-AutoReboot` triggers a graceful 60-second shutdown when a pending reboot is detected after updates.

## 📦 Supported Tools

Sections are organised into logical groups in the order they run:

### Package Managers

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **Scoop** | Scoop itself + all packages | `scoop update *`, `scoop cleanup *` |
| **Winget** | All Microsoft Store / winget apps (pinned packages ignored) | `winget upgrade --all` |
| **Chocolatey** | All Chocolatey packages | `choco upgrade all -y` |

### Shell & Terminal

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **PowerShell Modules** | All installed modules (with in-use fallback via subprocess) | `Update-Module` |
| **Oh My Posh** | Oh My Posh prompt engine | `oh-my-posh upgrade` |

### System

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **WSL** | WSL kernel + default distro packages | `wsl --update --web-download`, `apt-get full-upgrade`, `autoremove` |

### JavaScript

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **npm** | All globally installed packages | `npm update -g` |
| **pnpm** | pnpm itself | `pnpm self-update` |
| **Bun** | Bun runtime | `bun upgrade` |
| **Deno** | Deno runtime | `deno upgrade` |

### Python

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **pipx** | All pipx-installed apps | `pipx upgrade-all` |
| **uv** | uv itself, uv-managed Python runtimes, and all uv-installed tools | `uv self update` + `uv python install --upgrade` + `uv tool upgrade --all` |
| **Poetry** | Poetry itself | `poetry self update` |
| **Rye** | Rye itself | `rye self update` |

### Other Languages

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **.NET Global Tools** | All `dotnet tool`-installed global tools | `dotnet tool update -g` |
| **Rust** | Rust toolchain | `rustup update` |
| **Ruby Gems** | RubyGems system + all gems | `gem update --system`, `gem update` |
| **Composer** | Composer itself | `composer self-update` |

### Cloud & DevOps

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **Google Cloud SDK** | All gcloud components | `gcloud components update --quiet` |
| **Azure CLI** | CLI itself + all installed extensions | `az upgrade --yes --all` |
| **Android SDK** | All installed SDK components | `sdkmanager --update` |
| **Helm plugins** | All installed Helm plugins | `helm plugin update <name>` |
| **krew plugins** | All kubectl plugins managed by krew | `kubectl krew upgrade` |

### Dev Tooling

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **VS Code Extensions** | All installed extensions (parallel on PS7+) | `code --install-extension` |
| **GitHub CLI Extensions** | All `gh` extensions | `gh extension upgrade --all` |

### Typesetting

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **TeX Live** | All TeX packages (background job with 30-min timeout, auto cross-release upgrade) | `tlmgr update --self --all` |

## 🛠️ Installation

### Option A: Scoop (recommended)

```powershell
scoop bucket add baurfm https://github.com/baurfm/scoop-bucket
scoop install baurfm/update
update -h
```

Updates to new versions ship through `scoop update update` like any other Scoop package — no
git clone, no execution-policy changes needed.

### Option B: Clone the repository

1. **Clone or download** this repository to your local machine
2. **Ensure PowerShell execution policy** allows script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
3. **Verify prerequisites** are installed (see Prerequisites section below)

A git clone also gets the built-in self-update check (`git pull` on every run, disable with
`-NoSelfUpdate`) — the Scoop package does not, since it's not a git working copy.

## 📖 Usage

### Basic Usage

> Logs are written to `logs/update.log` by default; you can override the path with `-LogFile`.


```powershell
# Update all tools
.\update.ps1

# Skip specific sections
.\update.ps1 -NoTex

# Display help
.\update.ps1 -h
```

### Advanced Usage

```powershell
# Update only PowerShell modules and VS Code extensions
.\update.ps1 -NoScoop -NoWinget -NoTex -NoWsl

# Update everything except TeX Live (requires admin privileges)
.\update.ps1 -NoTex

# Get detailed help information
Get-Help .\update.ps1 -Full
```

## ⚙️ Parameters

### Skip flags (one per section)

| Parameter | Description |
|-----------|-------------|
| `-NoPowerShell` | Skip PowerShell Modules |
| `-NoScoop` | Skip Scoop + its packages |
| `-NoWinget` | Skip Winget apps |
| `-NoChoco` | Skip Chocolatey packages |
| `-NoOhMyPosh` | Skip Oh My Posh upgrade |
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
| `-NoTex` | Skip TeX Live |

### Mode flags

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
| `-Verbose` | - | Full blow-by-blow output — every step and raw tool output, not just results (standard PowerShell common parameter; default output shows headers + results only, see Output section) |
| `-RemoveFromPath` | - | Remove the auto-registered `update.cmd` shim and strip the script dir from User PATH, then exit |

### Unattended / Scheduled Operation

| Parameter | Description |
|-----------|-------------|
| `-Unattended` | Composite: implies `-Quiet`, `-NotifyEventLog`, `CmdTimeoutSec=600`; silences all interactive prompts globally |
| `-Quiet` | Suppress banner, section headers, and non-error terminal output |
| `-NoLock` | Skip lock-file guard (allows parallel runs; useful when called from a wrapper) |
| `-CmdTimeoutSec <n>` | Per-command hard timeout in seconds (0 = disabled, default 600 under `-Unattended`) |
| `-SkipNetworkCheck` | Skip the network reachability pre-check |
| `-AutoReboot` | Trigger `shutdown /r /t 60` if a pending reboot is detected after updates |
| `-RegisterSchedule` | Install a SYSTEM-level Scheduled Task (`UpdateDevTools`) and exit |
| `-UnregisterSchedule` | Remove the Scheduled Task and exit |
| `-ScheduleTime <HH:mm>` | Daily trigger time for `-RegisterSchedule` (default: `"03:00"`) |
| `-ScheduleFrequency <Daily/Weekly>` | Recurrence for `-RegisterSchedule` (default: `Daily`) |
| `-NotifyToast` | Send a Windows toast notification after completion (requires BurntToast) |
| `-NotifyWebhook <url>` | POST a JSON summary to this URL after completion (ntfy.sh compatible) |
| `-NotifyEventLog` | Write a Windows Application Event Log entry after completion |
| `-NotifyOn <Always/Failure/Never>` | Control when notifications fire (default: `Failure`) |

### Exit Codes

| Code | Constant | Meaning |
| ---- | -------- | ------- |
| `0` | `ExitOk` | All sections succeeded |
| `1` | `ExitPartial` | At least one section failed, but fewer than 50% |
| `2` | `ExitHardFailure` | 50%+ of attempted sections failed |
| `3` | `ExitElevationMissing` | Admin required but elevation failed |
| `4` | `ExitLockActive` | Another instance is already running (lock held) |
| `5` | `ExitNetworkDown` | No configured update host reachable |
| `6` | `ExitTimedOut` | (reserved for future per-section hard timeout tracking) |

## 📋 Prerequisites

### Required
- **Windows 10/11** (or Windows Server 2019+)
- **PowerShell 5.1+** (Windows PowerShell) or **PowerShell 7+** (PowerShell Core)
- **Administrative privileges** (for some operations like TeX Live and Winget)

### Optional (Install as needed)
- **Scoop** - Windows package manager
- **Winget** - Microsoft's package manager (Windows 10 1709+)
- **Visual Studio Code** - Code editor
- **npm (Node.js)** - JavaScript package manager
- **TeX Live** - LaTeX distribution
- **WSL** - Windows Subsystem for Linux
- **Sudo for Windows** - For a more streamlined elevation experience.

## 🔧 Configuration

The script automatically detects installed tools and skips unavailable ones. No configuration file is required, but you can customize behavior by:

1. **Modifying environment variables** for tool paths
2. **Using command-line parameters** to skip unwanted sections
3. **Running with different privilege levels** as needed

## 📊 Output

The script provides:

- **Progress counter** per section (`[7/25]`) so a long unattended-ish run doesn't feel stuck
- **Detailed error reporting** for failed operations
- **Comprehensive, compact summary** at completion — one line per category with an inline,
  truncated item list (`… (+N more)`; the full list always stays in `logs/update.log`)
- **Color-coded output** for easy reading

### Verbosity tiers

| Tier | What you see |
|------|--------------|
| `-Quiet` | Only warnings, errors and the final summary |
| Default | Headers, per-section results (✓/✗/○) and the summary — no per-step chatter |
| `-Verbose` | Everything above, plus every "doing X now" step and raw tool output (Scoop, Chocolatey, apt-get, …) |

Default output stays deliberately quiet about *how* a section is doing its work — only *whether*
it succeeded. Reach for `-Verbose` when you want to watch a long-running section (WSL's
`apt-get full-upgrade`, TeX Live) live instead of staring at a silent screen until it's done.

### WSL Package Updates

> **Logs** are stored in a `logs/` subdirectory next to the script; the last five archives are kept automatically.

The script updates packages inside your default WSL distribution via `apt-get full-upgrade`, which requires `sudo`. On first run the script **automatically writes a passwordless sudoers entry** for `apt-get` (skip with `-SkipWslSudoConfig`) — no interactive confirmation, no manual setup.

<details>
<summary>Manual passwordless-sudo setup (only if <code>-SkipWslSudoConfig</code> is used)</summary>

1. Open WSL: `wsl`
2. Find your username: `whoami`
3. Edit sudoers: `sudo visudo`
4. Append (replace `your_linux_username`):

    ```text
    your_linux_username ALL=(ALL) NOPASSWD: /usr/bin/apt-get
    ```

5. Save and exit.

</details>

### Sample Output

Default tier — headers, per-section results, and the summary; no per-step chatter:

```
  ╭────────────────────────────────────────╮
  │  ◆  Windows Update Script  v12.6       │
  │  ◆  2026-09-05  14:32:07               │
  ╰────────────────────────────────────────╯

  ══════════════════════════════════════════════════════════
  ▪ Python

  ▶  [12/25]  Updating uv

  ○  uv is managed by another package manager — skipping self-update
  ✓  Done  3s

  ▶  Update Summary

  ✓  uv  2 updated: Python runtimes, All uv tools
  ✓  pipx  1 updated: All pipx packages

  ✗  WSL  1 failed: apt-get full-upgrade failed

  ○  Skipped (2): Conda (not installed), TeX Live

  ○  Timings
       • WSL: 4m 12s

  ╭────────────────────────────────────────────────────────────╮
  │ ✗  Completed with failures  ·  4m 45s                      │
  │ 2 updated (3 items)  ·  1 failed (1 items)  ·  2 skipped   │
  ╰────────────────────────────────────────────────────────────╯
```

Item lists longer than 8 entries are truncated in the terminal (`… (+N more)`) — the full list
always stays in `logs/update.log`. Add `-Verbose` to see every intermediate step and raw tool
output (`→ Updating uv...`, `✓ uv python install --upgrade succeeded.`, …) instead of just results.

## 🔒 Security Considerations

### Security Features

- **Input Validation**: All external command inputs are validated and sanitized
- **Path Security**: Script enforces execution from its own directory
- **Command Injection Prevention**: Uses call operators (`&`) for safe command execution
- **Extension ID Validation**: VS Code extension IDs are validated against safe patterns
- **Package Name Sanitization**: Scoop package names are validated to prevent injection

### Security Best Practices

1. **Run from Trusted Location**: Always run the script from its original directory
2. **Review Before Execution**: Check the script source before running
3. **Administrative Privileges**: Only run with elevated privileges when necessary
4. **Network Security**: Ensure secure network connections for package downloads
5. **Regular Updates**: Keep the script itself updated from trusted sources

### Security Warnings

⚠️ **Important**: This script requires administrative privileges for some operations (TeX Live, Winget). Only run with elevated privileges if you trust the script source.

⚠️ **Network Security**: The script downloads packages from various sources. Ensure your network is secure and you trust the package repositories.

## 🚨 Troubleshooting

### Common Issues

1. **Execution Policy Error**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **Administrative Privileges Required**
   - Right-click PowerShell and select "Run as Administrator"
   - Or use `sudo` command if available

3. **Tool Not Found**
   - Ensure the tool is installed and in your PATH
   - The script will automatically skip unavailable tools

4. **Network Issues**
   - Check your internet connection
   - Some corporate networks may block package managers

### Debug Mode

For detailed debugging information, run with verbose output:

```powershell
.\update.ps1 -Verbose
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Guidelines

1. Follow PowerShell best practices
2. Add appropriate error handling
3. Update documentation for new features
4. Test on multiple Windows versions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Microsoft for PowerShell and Winget
- Scoop community for the excellent package manager
- All the developers of the tools this script helps maintain

## 🌐 Running Globally as `update`

To run the script from anywhere by simply typing `update` in PowerShell, add a function to your PowerShell profile.

1. Open your profile file:

   ```powershell
   notepad $PROFILE
   ```

   If the file doesn't exist yet, create it first:

   ```powershell
   New-Item -ItemType File -Path $PROFILE -Force
   ```

2. Add the following function (replace the path with the actual location of `update.ps1`):

   ```powershell
   function update {
       & "C:\path\to\your\update.ps1" @args
   }
   ```

   The `@args` forwards any flags you pass (e.g. `update -NoTex`).

3. Save and reload your profile:

   ```powershell
   . $PROFILE
   ```

After this, you can run `update`, `update -NoTex`, `update -h`, etc. from any directory.

## 📈 Version History

- **v12.17** — Extracted the Git.Git pending-update record logic (increment `skipCount`, preserve `firstDetected` across runs) into a pure `Build-PendingGitUpdateRecord` in `update.functions.ps1`, with tests. Evaluated further modularization (full PowerShell module, per-category files) and deliberately held off — not justified for a single-maintainer, single-entry-point tool.
- **v12.16** — Architecture: pure, side-effect-free helpers (winget output parsers, formatting, `-Only` matching) moved into a new dot-sourced `update.functions.ps1`, unlocking a real Pester unit-test suite (`tests/`, run automatically in CI) — no behavior change for end users, still a single `.ps1` to run. This is not a move toward a full PowerShell module; everything else stays in `update.ps1`. Distribution updated accordingly: the Scoop package now installs from the tagged source archive instead of a single uploaded asset (see `scoop-bucket`).
- **v12.15** — UX: winget's own raw output (source refresh + the `--all` upgrade table, previously an intentional exception left as direct passthrough for "long operation, live progress") is now captured and gated behind `-Verbose` like every other section — consistent quiet-by-default behavior across the whole script, per direct feedback that the passthrough looked out of place.
- **v12.14** — Simplification pass: removed the `Write-Status -Type Detail` case, which had become 100% behaviorally identical to `-Type Info` (same gating, same rendering) after earlier refactors — replaced its 3 call sites with `Info`. Merged `Get-WingetUpgradableIds` and `Get-WingetExplicitTargetIds`'s near-identical column-parsing logic into a shared `Get-WingetTableIds` — the duplication had directly caused the v12.10 bug (a fix landing in one copy but not the other). Testing the merge surfaced two more real bugs before they shipped: (1) a generic "line starts with a digit" summary-line check would have misparsed a legitimately digit-led package name like "7-Zip" as a summary line — replaced with matching winget's specific wording; (2) `[Parameter(Mandatory)]` on the new function's array parameter rejected the whole array whenever the winget output's own blank line (a normal, expected element) was present — a lesser-known PowerShell gotcha where mandatory array parameters validate every element, not just the array as a whole. Both fixed and verified against 5 scenarios before merging.
- **v12.13** — Cleanup pass: removed three files that were accidentally tracked in git despite being pure artifacts (`update.cmd` — a runtime-generated shim, `testout.txt` — a stray old debug dump, `.claude/settings.local.json` — personal Claude Code config, now all in `.gitignore`). Fix: `$script:ExitElevationMissing` (exit code 3) was declared and documented in the README but never actually used — the real gap it exposed was that cancelling the UAC prompt during self-elevation had no error handling at all and would crash with a raw Win32Exception; now caught cleanly and exits with the documented code.
- **v12.12** — Systematic test pass over lock handling, dedicated one-shot commands, and notifications turned up three real bugs: (1) `Remove-UpdateCommand`'s PATH-cleanup fallback called `.TrimEnd()` on a caught `$_` inside a `catch` block, where `$_` is the ErrorRecord, not the loop variable it shadowed — threw a real (harmless but ugly) error on every `-RemoveFromPath` run where a PATH entry needed `Resolve-Path` to fall back. (2) `-UnregisterSchedule` (no task present) and `-RemoveFromPath` (nothing to remove) printed no output at all beyond the banner — their sole feedback used `-Type Info`, silently hidden by the v12.5 default-tier chatter filter; switched to `-Type Success`/`-Type Skip` so dedicated one-shot commands always show their outcome. (3) `Write-UpdateEventLog` called `[EventLog]::SourceExists` before checking admin rights, which throws ("Inaccessible logs: Security") rather than just failing gracefully when not elevated — admin is now checked first. Also verified: stale/live lock detection, `-NoLock`, `-Quiet`, PS5.1+PS7 parsing, and a clean PSScriptAnalyzer pass.
- **v12.11** — Repo is now public and published as a Scoop package (`scoop bucket add baurfm https://github.com/baurfm/scoop-bucket && scoop install baurfm/update`), tracking tagged GitHub Releases from here on. Fix: `-Help`/`-h`/`-?` ran through the entire lock/network/self-update/elevation pre-check flow (including a possible UAC prompt) before printing help — moved to the very top of the script so it exits immediately. Added the LICENSE file the README already referenced.
- **v12.10** — Fix: `Get-WingetUpgradableIds` produced garbage entries (e.g. `ble.`, fragments of unrelated text) in the update summary whenever winget printed a second section after the main table (the "require explicit targeting" list, now common since v12.7). Root cause was two-fold: (1) the loop `continue`d past blank lines instead of stopping, reading straight into the next section's free-form text and column-slicing it as if it were a table row; (2) the "skip summary lines like '2 upgrades available.'" check tested the column-sliced fragment for a leading digit instead of the original line, so a slice landing mid-word (`available` → `ble.`) wasn't recognized as a summary line and slipped through. Caught live in production — thanks for flagging the garbled output.
- **v12.9** — Fix: live run revealed the v12.7 explicit-targeting fix (#8) correctly attempts packages like Android Studio, but some publishers' winget manifests have no working upgrade mechanism at all ("The package cannot be upgraded using WinGet") — a permanent, non-retriable condition. These now show as a skip with a clear "update via the publisher's own updater" reason instead of a failure.
- **v12.8** — First end-to-end test of `-OutputJson` and `-Parallel` since their v12.5 introduction. Fix: `-OutputJson` listed all 26 categories (most empty arrays) instead of just the ones with actual content — now only non-empty categories appear. Chore: `Start-ParallelPrefetch`'s `-Only` check now reuses `Test-SectionWanted` instead of a separate copy of the same logic.
- **v12.7** — New: Azure CLI section (`az upgrade --yes --all`, `-NoAzureCli` to skip) — found installed but not yet covered while scanning for missing tool support.
- **v12.6** — Fix: `-Only` no longer triggers unrelated elevation pre-checks/UAC prompts for sections it filters out (e.g. `-Only Scoop` no longer probes/elevates for winget). UX: empty group headers are now suppressed when `-Only` narrows the run down. UX: redesigned the closing summary into a bordered card matching the startup banner's style (bookends the run visually), auto-sized to its content. Fix: "Everything already up-to-date" and other top-level summary lines were accidentally hidden by the new default-tier chatter filter — they're always shown, regardless of `-Verbose`.
- **v12.5** — New: `-Only <names>` runs just a targeted subset of sections (substring match). New: `-Parallel` pre-launches independent tool self-updates (Oh My Posh, pnpm, Bun, Deno, Poetry, Rye, Composer) as background jobs. New: `-OutputJson <path>` writes a machine-readable run summary. New: three verbosity tiers (`-Quiet` / default / `-Verbose`) — default output now shows only headers, results, and the summary; use `-Verbose` for the full step-by-step + raw tool output. Fix ([#8](https://github.com/baurfm/update/issues/8)): winget packages that require explicit targeting (e.g. Android Studio) are no longer silently skipped by `--all` — upgraded individually and reported in the summary. Fix ([#9](https://github.com/baurfm/update/issues/9)): warns up front if VS Code is running before updating its extensions, since a locked extensions directory causes opaque exit-1 failures. Fix: elevation re-launch no longer reprints the banner/self-update check/pre-checks a second time (new internal `-Elevated` marker). Fix: the reason for elevation (e.g. "winget updates") is now shown instead of only logged. Rename: `Acquire-/Release-UpdateLock` → `Lock-/Unlock-UpdateRun` (PSScriptAnalyzer `PSUseApprovedVerbs`). Chore: added a UTF-8 BOM (fixes potential umlaut-corruption on some locales/hosts) and a GitHub Actions lint workflow (PS5.1 + PS7 parse check, PSScriptAnalyzer).
- **v12.4** — Fix: ternary operator in the notification path (`$HasFailures ? 1001 : 1000`) crashed the script's *parsing* on Windows PowerShell 5.1 entirely — replaced with `if/else`. Fix: self-update re-exec (on detecting a newer script version via `git pull`) deadlocked against its own run-lock because it re-launched itself without releasing it first — now releases the lock before re-exec, matching the existing elevation-relaunch pattern. Fix: `-UnregisterSchedule` silently reported success even when Scheduled Task removal actually failed (permission errors were swallowed as "nothing to remove"). UX: section headers now show progress (`[12/25]`); the final summary is redesigned to one compact line per category with an inline, truncated item list (`… (+N more)`, full list still in the log) instead of a bullet per item; the closing stats line now also reports total item counts, not just category counts. Docs: `-NotifyOn` default corrected to `Failure` (was documented as `Always`); Sample Output section updated to match the real output.
- **v12.3** — Fix: winget upgrade no longer fails when `bash.exe` / `git.exe` / Claude-Code sessions are running and Git.Git has a pending update. Detected blockers trigger a temporary `winget pin add --id Git.Git --gated` (removed in a `finally` block). A pending-update flag (`logs/pending-git-update.json`) persists across runs — the next run without blockers auto-applies the pending Git update via a fast-path before the regular `--all` batch. User-pre-existing pins are detected and left untouched.
- **v12.1** — Fix: gcloud auto-recovers from "Cannot use bundled Python installation" by running `gcloud components copy-bundled-python` and setting `CLOUDSDK_PYTHON` in-process, then retrying the update.
- **v12.0** — New: Unattended/headless mode (`-Unattended`, `-Quiet`). New: Lock-file prevents overlapping runs (`-NoLock` to bypass). New: Network pre-check aborts early when offline (`-SkipNetworkCheck`). New: Per-command hard timeout via `Invoke-WithTimeout` (`-CmdTimeoutSec`). New: Scheduled Task installer (`-RegisterSchedule`/`-UnregisterSchedule`/`-ScheduleTime`/`-ScheduleFrequency`) using SYSTEM principal — no password storage. New: Notifications via BurntToast toast, webhook (ntfy.sh compatible), or Windows Event Log (`-NotifyToast`/`-NotifyWebhook`/`-NotifyEventLog`/`-NotifyOn`). New: Auto-reboot when pending reboot detected (`-AutoReboot`). New: Differentiates exit codes 0–6 (Ok/Partial/HardFail/ElevationMissing/LockActive/NetworkDown/TimedOut). New: Global prompt killer silences all tool telemetry/interactive prompts in unattended mode. Fixed: Lock released before elevation re-launch so elevated child can acquire it. Log rotation increased from 5 to 30 archives.
- **v11.0** — BREAKING: Removed Conda section and `-NoConda` (migrated to uv). BREAKING: Replaced `-EnableVerbose` with standard `-Verbose` via `[CmdletBinding()]`. New: `uv python install --upgrade` in uv section (uv-managed Python runtimes). New helper `Invoke-UpdateStep` consolidates retry+result pattern across 9 call-sites. New helper `Get-WingetUpgradableIds` deduplicates winget parser. PS Modules run in parallel on PS7+ (ThrottleLimit 3). WSL apt-get now uses `Invoke-WithRetry` with retry. Fixed: 7+ log-duplication bugs (Write-Log -Level WARN after Write-Status). Fixed: `gem update --system` failures now recorded in failedItems. Fixed: Ctrl+C no longer logged as section ERROR. Docs: README Sample Output updated to reflect current UI.
- **v10.21** — Auto-register `update` command on User PATH via `update.cmd` shim (new `-RemoveFromPath` to undo); gcloud now parses output instead of blindly trusting exit code (handles external-package-manager case); cleaner summary layout (no duplicate failure lines, group headers get trailing whitespace); silent script-directory switch
- **v10.20** — Fix: winget upgrade check treated "no updates" exit code as failure; PS module subprocess leaked temp script on `Start-Process` exception; added `uv tool upgrade --all` so all uv-installed tools are updated alongside uv itself
- **v10.19** — Parallel pre-checks, `-DryRun` mode, .NET tool list stderr fix, broad refactoring
- **v10.18** — Fix: temp-file leak, defensive `$LASTEXITCODE` capture
- **v10.17** — Fix: npm pre-check stderr pollution
- **v10.16** — Fix bugs, improve terminal hierarchy (`Write-GroupHeader` / `Write-SectionHeader`)
- **v10.14** — Fix: TeX Live false-positive 'Updated' when no packages changed
- **v10.13** — Add: group headers to terminal output
- **v10.12** — Fix: uv self-update no longer reports failure when managed externally (Scoop/pip)
- **v10.11** — Sections reordered into logical groups; fix Conda duplicate environments
- **v10.10** — Add 10 new sections: pnpm, Bun, Deno, Oh My Posh, uv, Poetry, Rye, Composer, Helm plugins, krew plugins (plus `uv tool upgrade --all` for all uv-installed tools)
- **v10.9** — Fix: pre-check log entries missing from `update.log`
- **v10.8** — Improve log file coverage
- **v10.7** — Fix: `-Sudo` flag skips pre-checks and elevates immediately
- **v10.6** — Error handling improvements, `-Sudo` flag, fix npm false elevation
- **v10.5** — Add: GitHub self-update check at startup (`-NoSelfUpdate` to skip); PS modules batch pre-check via `Find-Module`; npm handles EPERM gracefully
- **v10.4** — Add: Android SDK via `sdkmanager --update` (`-NoAndroid`); Conda updates all named environments dynamically
- **v10.3** — Perf: VS Code extensions updated in parallel on PS7+ (ThrottleLimit 6)
- **v10.2** — Add: Google Cloud SDK, GitHub CLI extensions, .NET global tools (`-NoGCloud`/`-NoGhExt`/`-NoDotnet`)
- **v10.1** — Fix: TeX Live cross-release auto-upgrade, WSL `full-upgrade` for kept-back packages, conda `auto_activate` key, PS module false-success for in-use modules; UI: box-drawing banner, colored status
- **v10.0** — Add: pipx, Rust, Ruby Gems, Chocolatey (`-NoPipx`/`-NoRust`/`-NoGem`/`-NoChoco`); Fix: WSL circular sudo (`wsl -u root` instead of `wsl sudo`); Refactor: `Set-WslPasswordlessSudo` helper

<details>
<summary>Older versions (v8.x – v9.9)</summary>

- **v9.9** — Automatic passwordless sudo config for WSL (`-SkipWslSudoConfig`)
- **v9.8** — winget ignores pinned packages, conda base `--all` update, logs in `logs/` folder
- **v9.7** — hashtable refactor, retry-style cleanup, winget source update, scoop cleanup, structured logging
- **v9.6** — Conda regex fix, skipped-sections in summary, PS version check, disk space warning
- **v9.5** — winget/scoop retry bug fix, dead code removal
- **v9.4** — Retry logic across all sections, proper exit codes
- **v9.3** — Improved WSL updates with retry and sudo handling
- **v9.2** — Windows `sudo` command support
- **v9.0–9.1** — Comprehensive error handling and summary reporting
- **v8.x** — Incremental improvements

</details>

---

**Note**: This script is designed for Windows development environments. For Linux or macOS, consider using similar tools like `apt`, `brew`, or `yum` with appropriate scripts.
