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
    '--No<Section>' parameter when you run the script. It also supports dry-run mode to preview updates
    without executing them.

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

.PARAMETER OnlyWsl
    A switch to only update WSL and skip other sections.

.PARAMETER OnlyWslPackages
    A switch to only update WSL packages (apt-get) and skip other sections including WSL kernel.

.PARAMETER DryRun
    A switch to perform a dry run without making changes.

.PARAMETER EnableVerbose
    A switch to enable verbose output.

.PARAMETER LogFile
    Path to the log file. Default is 'update.log'.

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
    .\update.ps1 -DryRun

    Performs a dry run to see what would be updated without making changes.

.EXAMPLE
    .\update.ps1 -EnableVerbose -LogFile "myupdate.log"

    Runs updates with verbose output and logs to 'myupdate.log'.

.EXAMPLE
    .\update.ps1 -OnlyWslPackages -DryRun

    Performs a dry run of only the WSL package updates.

.NOTES
    Author: Your Name
    Date: 2024-08-02
    Version: 9.1 (Fixed PSScriptAnalyzer warning for unused '$hasFailures' variable)
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
    [switch]$OnlyWsl,
    [switch]$OnlyWslPackages,

    [Parameter(HelpMessage = "Perform a dry run without making changes.")]
    [switch]$DryRun,

    [Parameter(HelpMessage = "Enable verbose output.")]
    [switch]$EnableVerbose,

    [Parameter(HelpMessage = "Path to log file.")]
    [string]$LogFile = "update.log"
)

# Function to display a formatted section header
function Write-SectionHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Function to write log messages
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    if ($EnableVerbose -or $Level -ne "INFO") {
        Write-Host $logMessage
    }
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logMessage
    }
}

# Function to invoke update commands with retry logic
function Invoke-UpdateCommand {
    param(
        [string]$Command,
        [string[]]$Arguments = @(),
        [int]$MaxRetries = 1,
        [string]$Section
    )
    $retryCount = 0
    $fullCommand = "$Command $($Arguments -join ' ')"
    do {
        if ($DryRun) {
            Write-Log "DRY RUN: Would execute: $fullCommand" -Level "INFO"
            return $true
        }
        Write-Log "Executing: $fullCommand" -Level "DEBUG"
        $result = & $Command @Arguments 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Command succeeded: $fullCommand" -Level "INFO"
            return $true
        } else {
            $retryCount++
            Write-Log "Command failed (attempt $retryCount): $fullCommand. Error: $result" -Level "ERROR"
            if ($retryCount -lt $MaxRetries) {
                Start-Sleep -Seconds 5
            }
        }
    } while ($retryCount -lt $MaxRetries)
    return $false
}
# Function to handle common update section logic
function Update-Section {
    param(
        [string]$SectionName,
        [string]$SectionKey,
        [bool]$SkipCondition,
        [scriptblock]$ToolCheck,
        [scriptblock]$UpdateAction
    )

    if ($SkipCondition) {
        Write-Host "Skipping $SectionName updates as requested."
        Write-Log "Skipping $SectionName updates."
        return
    }

    Write-SectionHeader "Updating $SectionName"
    Write-Log "Starting $SectionName updates."

    if (-not (& $ToolCheck)) {
        Write-Host "$SectionName is not available. Skipping."
        return
    }

    try {
        & $UpdateAction
        Write-Log "$SectionName updates completed."
    } catch {
        Write-Host "An error occurred while updating $SectionName. $_" -ForegroundColor Red
        Write-Log "Error during $SectionName updates: $_" -Level "ERROR"
    }
}

# Initialize logging
Write-Log "Starting update script."
if ($DryRun) {
    Write-Log "Dry run mode enabled. No changes will be made." -Level "WARN"
}

# Set error action preference for consistent error handling
$ErrorActionPreference = 'Continue'

# --- Administrator Elevation Check ---
# If Winget or WSL updates are planned, the script needs to run as an administrator.
# This block checks for the necessary permissions and re-launches the script with elevation if required.
if (-not $NoWinget -or -not $NoWsl -or $OnlyWsl -or $OnlyWslPackages) {
    $myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID)
    $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

    if (-not $myWindowsPrincipal.IsInRole($adminRole)) {
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
        $sudoExists = Get-Command sudo -ErrorAction SilentlyContinue
        if ($sudoExists) {
            # Use the new Windows 'sudo' to re-launch.
            Write-Host "Administrator privileges are required. Re-launching with 'sudo'..." -ForegroundColor Yellow
            & sudo powershell.exe -ExecutionPolicy Bypass -File $MyInvocation.MyCommand.Definition @argArray
            exit
        } else {
            # Fallback to the traditional self-elevation method.
            Write-Host "Administrator privileges are required. Re-launching as administrator..." -ForegroundColor Yellow
            $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell"
            $newProcess.Arguments = "& '" + $MyInvocation.MyCommand.Definition + "' " + ($argArray -join ' ')
            $newProcess.Verb = "runas"
            [System.Diagnostics.Process]::Start($newProcess)
            exit
        }
    }
}

# Security: Require script to be run from the directory where it's located
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
if ((Get-Location).Path -ne $ScriptPath) {
    Write-Warning "Script should be run from its directory: $ScriptPath"
    Write-Host "Changing to script directory..." -ForegroundColor Yellow
    Set-Location $ScriptPath
}

# If -Help, -h, or -? is used, show the help for this script and exit.
if ($Help) {
    # Use the built-in Get-Help command to display the comment-based help block from the top of this script.
    Get-Help $MyInvocation.MyCommand.Path -Full
    return # Exit the script
}


# Initialize hashtables to store results for the final summary
$updatedItems = @{
    "PowerShell Modules" = @()
    "Scoop" = @()
    "Winget" = @()
    "VS Code Extensions" = @()
    "Conda" = @()
    "TeX Live" = @()
    "WSL" = @()
    "npm" = @()
}

$failedItems = @{
    "PowerShell Modules" = @()
    "Scoop" = @()
    "Winget" = @()
    "VS Code Extensions" = @()
    "Conda" = @()
    "TeX Live" = @()
    "WSL" = @()
    "npm" = @()
}

# --- Update PowerShell Modules ---
Update-Section "PowerShell Modules" "PowerShell Modules" ($NoPowerShell -or $OnlyWsl -or $OnlyWslPackages) { $true } {
    Write-Host "Checking for installed PowerShell modules and updating them..."
    Write-Log "Retrieving installed modules."
    $installedModules = Get-InstalledModule
    $progress = 0
    foreach ($module in $installedModules) {
        Write-Progress -Activity "Updating PowerShell Modules" -Status "Updating $($module.Name)" -PercentComplete (($progress / $installedModules.Count) * 100)
        try {
            Write-Host "Updating module: $($module.Name)..."
            Write-Log "Updating module: $($module.Name)"
            if (-not $DryRun) {
                Update-Module -Name $module.Name -Force -ErrorAction Stop
            }
            $updatedItems["PowerShell Modules"] += $module.Name
            Write-Log "Successfully updated module: $($module.Name)"
        } catch {
            Write-Host "--> Failed to update module: $($module.Name). Error: $_" -ForegroundColor Red
            Write-Log "Failed to update module: $($module.Name). Error: $_" -Level "ERROR"
            $failedItems["PowerShell Modules"] += "$($module.Name) - $($_.Exception.Message)"
        }
        $progress++
    }
    Write-Progress -Activity "Updating PowerShell Modules" -Completed
    Write-Host "PowerShell module update check completed."
}

# --- Update Scoop ---
Update-Section "Scoop and its packages" "Scoop" ($NoScoop -or $OnlyWsl -or $OnlyWslPackages) { Get-Command scoop -ErrorAction SilentlyContinue } {
    Write-Host "Checking for outdated Scoop packages..."
    $scoopStatus = & scoop status
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "The 'scoop status' command failed with exit code $LASTEXITCODE. Skipping Scoop updates."
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
            Write-Host "Found $($outdatedApps.Count) outdated packages: $($outdatedApps -join ', ')"
            $updatedItems["Scoop"] += $outdatedApps
        } else {
            Write-Host "No outdated Scoop packages found to update."
        }

        Write-Host "Updating Scoop itself..."
        & scoop update
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The 'scoop update' command failed with exit code $LASTEXITCODE."
            $failedItems["Scoop"] += "scoop update (Exit Code: $LASTEXITCODE)"
        }

        Write-Host "Updating all installed packages via Scoop..."
        & scoop update *
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The 'scoop update *' command failed with exit code $LASTEXITCODE."
            $failedItems["Scoop"] += "scoop update * (Exit Code: $LASTEXITCODE)"
        }

        if ($updatedItems["Scoop"].Count -eq 0 -and $failedItems["Scoop"].Count -eq 0) {
            $updatedItems["Scoop"] += "Ran 'scoop update *' (no outdated packages were detected beforehand)."
        }
    }
}

# --- Update Winget & Microsoft Store Apps ---
if (-not $NoWinget -and !$OnlyWsl -and !$OnlyWslPackages) {
    Write-SectionHeader "Updating Winget & Microsoft Store apps"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Checking for outdated Winget packages..."
        # We run 'winget upgrade' to get the list of upgradable packages.
        # We need to specify --include-unknown to match the upgrade command.
        $wingetUpgradeOutput = & winget upgrade --include-unknown
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The 'winget upgrade' command failed with exit code $LASTEXITCODE. Skipping Winget updates."
            $failedItems["Winget"] += "winget upgrade (check) (Exit Code: $LASTEXITCODE)"
        } else {
            $upgradablePackages = @()

            if ($wingetUpgradeOutput -and $wingetUpgradeOutput.Length -gt 2) {
                $lines = $wingetUpgradeOutput -split [System.Environment]::NewLine
                # The first line is the header, which we can use to find column positions.
                $headerLine = $lines[0]
                $idColIndex = $headerLine.IndexOf('Id')
                $versionColIndex = $headerLine.IndexOf('Version')

                if ($idColIndex -ge 0 -and $versionColIndex -gt $idColIndex) {
                    # Start processing from the third line (index 2) to skip header and separator.
                    for ($i = 2; $i -lt $lines.Length; $i++) {
                        $line = $lines[$i]
                        if ($line.Trim().Length -gt 0) {
                            # Extract the Id based on the column position.
                            $packageId = $line.Substring($idColIndex, $versionColIndex - $idColIndex).Trim()
                            if (-not [string]::IsNullOrWhiteSpace($packageId)) {
                                $upgradablePackages += $packageId
                            }
                        }
                    }
                }
            }

            if ($upgradablePackages.Count -gt 0) {
                Write-Host "Found $($upgradablePackages.Count) upgradable packages."
                $updatedItems["Winget"] += $upgradablePackages
            } else {
                Write-Host "No outdated Winget packages found to update."
            }

            Write-Host "Running winget to upgrade all packages (including pinned and unknown)..."
            # Using the standard command-line tool directly. It will print its own progress.
            & winget upgrade --all --accept-source-agreements --accept-package-agreements --include-pinned --include-unknown
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "The 'winget upgrade --all' command failed with exit code $LASTEXITCODE."
                $failedItems["Winget"] += "winget upgrade --all (Exit Code: $LASTEXITCODE)"
            }

            # Add a generic message to the summary if no specific packages were found to be outdated.
            if ($updatedItems["Winget"].Count -eq 0 -and $failedItems["Winget"].Count -eq 0) {
                $updatedItems["Winget"] += "Ran 'winget upgrade --all' (no outdated packages were detected beforehand)."
            }
        }
    } else {
        Write-Host "Winget is not installed. Skipping."
    }
} else {
    Write-Host "Skipping Winget updates as requested."
}


# --- Update Visual Studio Code Extensions ---
if (-not $NoVsCode -and !$OnlyWsl -and !$OnlyWslPackages) {
    Write-SectionHeader "Updating Visual Studio Code Extensions"
    if (Get-Command code -ErrorAction SilentlyContinue) {
        Write-Host "Listing installed VS Code extensions..."
        $installedExtensions = & code --list-extensions
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The 'code --list-extensions' command failed with exit code $LASTEXITCODE. Skipping VS Code extension updates."
            $failedItems["VS Code Extensions"] += "code --list-extensions (Exit Code: $LASTEXITCODE)"
        } else {
            $actuallyUpdated = @()

            foreach ($extensionId in $installedExtensions) {
                if ($extensionId.Trim().Length -gt 0) {
                    # Security: Validate extension ID format to prevent injection
                    if ($extensionId -match '^[a-zA-Z0-9._-]+\.[a-zA-Z0-9._-]+$') {
                        Write-Host "Checking/updating extension: $extensionId..."
                        # The '--force' flag ensures that the extension is updated if it's already installed. We capture stderr too.
                        $updateOutput = & code --install-extension $extensionId --force 2>&1

                        if ($LASTEXITCODE -ne 0) {
                            Write-Warning "Failed to update extension: $extensionId (Exit Code: $LASTEXITCODE)"
                            $failedItems["VS Code Extensions"] += "$extensionId (Exit Code: $LASTEXITCODE)"
                        } else {
                            # We check the output to see if the extension was actually updated.
                            # The message for a successful update/install is "Extension ... was successfully installed."
                            # The message for no update is "Extension ... is already installed."
                            if ($updateOutput -join ' ' -like '*successfully installed*') {
                                Write-Host "--> Successfully updated $extensionId" -ForegroundColor Cyan
                                $actuallyUpdated += $extensionId
                            }
                        }
                    } else {
                        Write-Warning "Skipping invalid extension ID: $extensionId"
                    }
                }
            }

            if ($actuallyUpdated.Count -gt 0) {
                Write-Host "$($actuallyUpdated.Count) extensions were updated." -ForegroundColor Green
                $updatedItems["VS Code Extensions"] += $actuallyUpdated
            } else {
                Write-Host "All VS Code extensions were already up-to-date."
            }

            if ($updatedItems["VS Code Extensions"].Count -eq 0 -and $failedItems["VS Code Extensions"].Count -eq 0) {
                $updatedItems["VS Code Extensions"] += "All extensions checked and were up-to-date."
            }
        }
    } else {
        Write-Host "The 'code' command is not in your PATH. Skipping VS Code extension updates."
    }
} else {
    Write-Host "Skipping VS Code Extension updates as requested."
}

# --- Update Miniconda ---
if (-not $NoConda -and !$OnlyWsl -and !$OnlyWslPackages) {
    Write-SectionHeader "Updating Miniconda and 'ocr-azure' environment"
    if (Get-Command conda -ErrorAction SilentlyContinue) {
        Write-Host "Updating the base conda environment..."
        & conda update -n base -c defaults conda -y
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The 'conda update -n base' command failed with exit code $LASTEXITCODE."
            $failedItems["Conda"] += "conda update -n base (Exit Code: $LASTEXITCODE)"
        } else {
            $updatedItems["Conda"] += "Miniconda (base)"
        }

        # Check if 'ocr-azure' environment exists
        $condaEnvs = & conda env list
        if ($LASTEXITCODE -eq 0 -and ($condaEnvs -join ' ') -match 'ocr-azure') {
            Write-Host "Found 'ocr-azure' environment. Updating all packages within it..."
            & conda update -n ocr-azure --all -y
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "The 'conda update -n ocr-azure' command failed with exit code $LASTEXITCODE."
                $failedItems["Conda"] += "conda update -n ocr-azure (Exit Code: $LASTEXITCODE)"
            } else {
                $updatedItems["Conda"] += "Conda environment (ocr-azure)"
            }
        } else {
            Write-Host "'ocr-azure' environment not found or 'conda env list' failed. Skipping."
            if ($LASTEXITCODE -ne 0) {
                $failedItems["Conda"] += "conda env list (Exit Code: $LASTEXITCODE)"
            }
        }
    } else {
        Write-Host "conda is not found in your PATH. Skipping."
    }
} else {
    Write-Host "Skipping Conda updates as requested."
}

# --- Update TeX Live ---
if (-not $NoTex -and !$OnlyWsl -and !$OnlyWslPackages) {
    Write-SectionHeader "Updating TeX Live"
    if (Get-Command tlmgr -ErrorAction SilentlyContinue) {
        Write-Host "Updating TeX Live package manager (tlmgr) and all packages..."
        & tlmgr update --self --all
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The 'tlmgr update --self --all' command failed with exit code $LASTEXITCODE. Ensure you are running as an Administrator."
            $failedItems["TeX Live"] += "tlmgr update (Exit Code: $LASTEXITCODE)"
        } else {
            $updatedItems["TeX Live"] += "All packages"
        }
    } else {
        Write-Host "TeX Live (tlmgr) is not installed or not in your PATH. Skipping."
    }
} else {
    Write-Host "Skipping TeX Live updates as requested."
}

# --- Update WSL ---
if (-not $NoWsl -or $OnlyWsl -or $OnlyWslPackages) {
    Write-SectionHeader "Updating Windows Subsystem for Linux (WSL)"
    Write-Log "Starting WSL updates."
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        # Since elevation is handled at the start, we can proceed directly.
        if (-not $OnlyWslPackages) {
            Write-Host "Updating the WSL kernel..."
            Write-Log "Updating WSL kernel."
            if (Invoke-UpdateCommand "wsl" @("--update", "--web-download") 2 "WSL") {
                $updatedItems["WSL"] += "WSL Kernel"
            }

            Write-Host "Shutting down WSL to apply updates..."
            Write-Log "Shutting down WSL."
            Invoke-UpdateCommand "wsl" @("--shutdown") 1 "WSL"  # Shutdown might not need retry
        } else {
            Write-Log "Skipping WSL kernel update as requested."
        }

    } else {
        Write-Host "WSL is not installed. Skipping."
        Write-Log "WSL not installed."
    }
} else {
    Write-Host "Skipping WSL updates as requested."
    Write-Log "Skipping WSL updates."
}

# --- Update npm Packages ---
if (-not $NoNpm -and !$OnlyWsl) {
    Write-SectionHeader "Updating npm (Node Package Manager) Packages"
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "Checking for outdated global npm packages..."
        $outdatedNpmPackages = & npm outdated -g --parseable --depth=0
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The 'npm outdated -g' command failed with exit code $LASTEXITCODE. Skipping npm updates."
            $failedItems["npm"] += "npm outdated -g (Exit Code: $LASTEXITCODE)"
        } else {
            $npmToUpdate = @()
            foreach ($line in ($outdatedNpmPackages -split [System.Environment]::NewLine)) {
                if ($line) {
                    $packageName = ($line.Split(':'))[2]
                    if ($packageName) {
                        $npmToUpdate += $packageName
                    }
                }
            }

            if ($npmToUpdate.Count -gt 0) {
                Write-Host "Found $($npmToUpdate.Count) outdated npm packages: $($npmToUpdate -join ', ')"
                $updatedItems["npm"] += $npmToUpdate
            } else {
                Write-Host "No outdated global npm packages found."
            }

            # Run the update command
            Write-Host "Updating all global npm packages..."
            & npm update -g
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "The 'npm update -g' command failed with exit code $LASTEXITCODE."
                $failedItems["npm"] += "npm update -g (Exit Code: $LASTEXITCODE)"
            }

            if ($updatedItems["npm"].Count -eq 0 -and $failedItems["npm"].Count -eq 0) {
                $updatedItems["npm"] += "Ran 'npm update -g' (no outdated packages were detected beforehand)."
            }
        }
    } else {
        Write-Host "npm is not installed or not in your PATH. Skipping."
    }
} else {
    Write-Host "Skipping npm updates as requested."
}


# --- Final Summary ---
Write-SectionHeader "Update Summary"
Write-Host "The script has completed. Here is the summary of what was changed."

$hasUpdates = $false
foreach ($key in $updatedItems.Keys) {
    if ($updatedItems[$key].Count -gt 0) {
        $hasUpdates = $true
        Write-Host ""
        Write-Host "--- Successfully Ran: $key ---" -ForegroundColor Green
        $updatedItems[$key] | ForEach-Object { Write-Host "  - $_" }
    }
}

if (-not $hasUpdates) {
    Write-Host ""
    Write-Host "No update sections were run." -ForegroundColor Yellow
}

$hasFailures = $false
foreach ($key in $failedItems.Keys) {
    if ($failedItems[$key].Count -gt 0) {
        $hasFailures = $true
        Write-Host ""
        Write-Host "--- Failed Sections: $key ---" -ForegroundColor Red
        $failedItems[$key] | ForEach-Object { Write-Host "  - $_" }
    }
}

# --- THIS IS THE FIX ---
# Check the $hasFailures variable and report if everything was successful.
if (-not $hasFailures) {
    Write-Host ""
    Write-Host "No failures were reported during this run." -ForegroundColor Green
}

Write-Host ""
Write-SectionHeader "All update tasks have been attempted."