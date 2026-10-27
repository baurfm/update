# update — one command to update your Windows dev machine

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

`update` brings everything on your machine up to date in one run — Scoop, winget, Windows Update,
WSL, npm, uv, PowerShell modules, VS Code/Cursor extensions, cloud CLIs, Claude Code, TeX Live
and more. It only touches tools you actually have installed, asks for admin rights only when
something really needs them, and ends with a short summary of what changed.

```text
  📦 PACKAGE MANAGERS
  ▶  [1/29] ━─────────  Updating Scoop and its packages
  ✓  All packages up-to-date
  ...
  ✓  Cursor Extensions  13 updated: dart-code.flutter, ms-python.debugpy, ... (+5 more)
  ○  Skipped (2): Winget & Microsoft Store apps, Windows Update (needs admin, use -Sudo)
  ○  Not installed (12): Chocolatey packages, Oh My Posh, pnpm, Bun, Deno, ...

  ╭─────────────────────────────────────────────────────────────╮
  │ 🎉  All done  ·  4m 42s                                     │
  │ 5 updated (6 items)  ·  0 failed (0 items)  ·  16 skipped   │
  ╰─────────────────────────────────────────────────────────────╯
```

## Install

**Scoop (recommended)** — updates arrive via `scoop update`:

```powershell
scoop bucket add baurfm https://github.com/baurfm/scoop-bucket
scoop install baurfm/update
```

**Git clone** — updates itself via `git pull` on every run:

```powershell
git clone https://github.com/baurfm/update C:\apps\update
C:\apps\update\update.ps1          # first run puts 'update' on your PATH
```

Needs Windows 10/11 and PowerShell 5.1 or 7+. Everything else is optional.

## Usage

```powershell
update                       # update everything that's installed
update -NoTex -NoWsl         # skip sections
update -Only npm,uv,Claude   # run only matching sections
update -DryRun               # show what would run, change nothing
update -Sudo                 # elevate right away (also runs Windows Update)
update -Verbose              # watch every step and raw tool output
update -h                    # full help
```

| Want to… | Use |
|----------|-----|
| Run it every night | `update -Schedule On` in an elevated shell → [unattended.md](docs/unattended.md) |
| Get a phone notification | `-NotifyWebhook https://ntfy.sh/<topic>` → [unattended.md](docs/unattended.md) |
| Make it faster | `-Parallel` pre-launches small tool self-updates in the background |
| Feed results into a script | `-OutputJson result.json` |
| Check/undo the `update` command on PATH | `update -PathSetup Status` / `Off` |

All parameters: **[docs/parameters.md](docs/parameters.md)** · What gets updated and how:
**[docs/tools.md](docs/tools.md)**

## Good to know

- **Admin rights** are only requested for winget upgrades, the WSL kernel, a write-protected npm
  prefix — and Windows Update runs whenever the script is elevated anyway. No UAC prompt if none
  of these has anything to do.
- **Logs**: `logs/update.log` next to the script (last 30 runs kept). The summary prints the path
  when something failed.
- **Exit code**: `0` all good, `1` some sections failed, `2` most failed, `3`–`5` elevation /
  lock / network problems ([full list](docs/parameters.md#exit-codes)).
- **Emoji icons** show in Windows Terminal and VS Code; set `UPDATE_NO_EMOJI=1` to turn them off.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "running scripts is disabled" | Use the `update` command (bypasses the policy), or `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| A section failed | The summary shows the error; the full tool output is in `logs/update.log`, or re-run just that section with `update -Only <name> -Verbose` |
| "Another run is active" | Another `update` is running. A lock left behind by a crashed run is cleared automatically |
| Git.Git / Windows Terminal skipped | Their installers can't run while they're in use — close Git Bash / run from classic `powershell.exe` once |
| "No network reachable" (exit 5) | The pre-check couldn't reach github.com / npm over HTTPS; behind a proxy use `-SkipNetworkCheck` |
| Extension "no longer exists in the Marketplace" | It was delisted; remove it with the `--uninstall-extension` command shown |

## More

- [CHANGELOG.md](CHANGELOG.md) — version history
- [docs/development.md](docs/development.md) — layout, tests, adding a section
- Issues and ideas: [GitHub Issues](https://github.com/baurfm/update/issues)

MIT licensed — see [LICENSE](LICENSE).
