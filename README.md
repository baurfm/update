# Windows Development Environment Update Script

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A comprehensive PowerShell script that automates the update process for multiple development tools and package managers on Windows systems. This script provides granular control over which components to update, making it perfect for maintaining a clean and up-to-date development environment.

## 🚀 Features

- **Comprehensive Coverage**: Updates ~27 development tool categories across package managers, language runtimes, CLIs and IDEs
- **Selective Updates**: Skip specific sections using command-line parameters (`-NoX` flags)
- **Dry-Run Mode**: Preview which sections would run without making any changes (`-DryRun`)
- **Parallel Pre-Checks**: Fast up-front detection of which sections actually need updates — reduces elevation prompts and runtime
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

1. **Clone or download** this repository to your local machine
2. **Ensure PowerShell execution policy** allows script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
3. **Verify prerequisites** are installed (see Prerequisites section below)

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
| `-SkipWslSudoConfig` | - | Skip automatic passwordless-sudo setup for WSL |
| `-LogFile <path>` | - | Override log file path (default: `logs/update.log`) |
| `-Verbose` | - | Verbose output (standard PowerShell common parameter) |
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
| `-NotifyOn <Always/Failure/Never>` | Control when notifications fire (default: `Always`) |

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

- **Real-time progress updates** for each section
- **Detailed error reporting** for failed operations
- **Comprehensive summary** at completion
- **Color-coded output** for easy reading

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

```
  ╭────────────────────────────────────────╮
  │  ◆  Windows Update Script  v12.0      │
  │  ◆  2026-04-22  14:32:07              │
  ╰────────────────────────────────────────╯

  ══════════════════════════════════════════════════════════
  ▪ Python

  ▶  Updating uv

  →  Updating uv...
  ○  uv is managed by another package manager — skipping self-update
  →  Upgrading uv-managed Python runtimes...
  ✓  uv python install --upgrade succeeded.
  →  Upgrading all uv tools...
  ✓  All uv tools upgraded.
  ✓  Done  3s

  ══════════════════════════════════════════════════════════
  ▪ Update Summary

  ✓  Updated (3 sections):  uv: Python runtimes, All uv tools | pipx: All pipx packages | ...
  ·  Skipped (2):  Conda (not installed) | TeX Live (--NoTex)
```

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
