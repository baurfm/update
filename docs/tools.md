# Supported tools

[Back to README](../README.md)

Sections are organised into logical groups in the order they run:

## Package Managers

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **Scoop** | Scoop itself + all packages; removes old versions and clears the download cache | `scoop update *`, `scoop cleanup *`, `scoop cache rm --all` |
| **Winget** | All Microsoft Store / winget apps (pinned packages ignored) | `winget upgrade --all` |
| **Chocolatey** | All Chocolatey packages | `choco upgrade all -y` |

## Shell & Terminal

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **PowerShell Modules** | PowerShellGet and PSResourceGet modules (in-use fallback via subprocess; PSResourceGet pinned to the original, trusted repository) | `Update-Module`, `Update-PSResource` |
| **Oh My Posh** | Oh My Posh prompt engine | `oh-my-posh upgrade` |

## System

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **Windows Update** | Windows updates via the PSWindowsUpdate module — only when the run is elevated anyway, never reboots by itself | `Install-WindowsUpdate -AcceptAll -IgnoreReboot` |
| **WSL** | WSL kernel + default distro packages | `wsl --update --web-download`, `apt-get full-upgrade`, `autoremove` |

## JavaScript

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **npm** | npm itself + all outdated global packages, including major versions | `npm install -g npm`, `npm install -g <pkg>@<latest>` |
| **pnpm** | pnpm itself | `pnpm self-update` |
| **Bun** | Bun runtime | `bun upgrade` |
| **Deno** | Deno runtime | `deno upgrade` |

## Python

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **pipx** | All pipx-installed apps | `pipx upgrade-all` |
| **uv** | uv itself, uv-managed Python runtimes, and all uv-installed tools | `uv self update` + `uv python install --upgrade` + `uv tool upgrade --all` |
| **Poetry** | Poetry itself | `poetry self update` |
| **Rye** | Rye itself | `rye self update` |

## Other Languages

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **.NET Global Tools** | All `dotnet tool`-installed global tools | `dotnet tool update -g` |
| **Rust** | Rust toolchain | `rustup update` |
| **Ruby Gems** | RubyGems system + all gems | `gem update --system`, `gem update` |
| **Composer** | Composer itself | `composer self-update` |

## Cloud & DevOps

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **Google Cloud SDK** | All gcloud components | `gcloud components update --quiet` |
| **Azure CLI** | CLI itself + all installed extensions | `az upgrade --yes --all` |
| **Android SDK** | All installed SDK components | `sdkmanager --update` |
| **Helm plugins** | All installed Helm plugins | `helm plugin update <name>` |
| **krew plugins** | All kubectl plugins managed by krew | `kubectl krew upgrade` |

## Dev Tooling

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **VS Code Extensions** | Outdated extensions only | `code --update-extensions` (fallback: `code --install-extension --force` per extension) |
| **Cursor Extensions** | Outdated Cursor extensions | `cursor --update-extensions` |
| **GitHub CLI Extensions** | All `gh` extensions | `gh extension upgrade --all` |
| **Claude Code** | Claude Code CLI (native or npm install) | `claude update` |

## Typesetting

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **TeX Live** | All TeX packages (background job with 30-min timeout, auto cross-release upgrade) | `tlmgr update --self --all` |

## Section notes

- **Windows Update** only runs when the script is elevated anyway (winget/WSL/npm needed admin,
  or you passed `-Sudo`). It never asks for elevation itself and never reboots on its own —
  combine with `-AutoReboot` if you want that.
- **Git.Git** is temporarily pinned out of `winget upgrade --all` while `bash.exe`/`git.exe` are
  running (its installer would fail) and applied automatically on the next run without them.
- **Windows Terminal** is skipped when the script runs *inside* Windows Terminal — upgrading it
  would kill the session. Run once from classic `powershell.exe` to update it.
- **VS Code / Cursor extensions** that were removed from the Marketplace show up as skipped with
  the matching `--uninstall-extension` command.

## WSL Package Updates

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
