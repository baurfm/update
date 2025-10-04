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
    '--No<Section>' parameter when you run the script.

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
    [switch]$NoNpm
)

# Set error action preference for consistent error handling
$ErrorActionPreference = 'Continue'

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
if (-not $NoPowerShell) {
    Write-SectionHeader "Updating PowerShell Modules"
    try {
        Write-Host "Checking for installed PowerShell modules and updating them..."
        $installedModules = Get-InstalledModule
        foreach ($module in $installedModules) {
            try {
                Write-Host "Updating module: $($module.Name)..."
                Update-Module -Name $module.Name -Force -ErrorAction Stop
                $updatedItems["PowerShell Modules"] += $module.Name
            } catch {
                Write-Host "--> Failed to update module: $($module.Name). Error: $_" -ForegroundColor Red
                $failedItems["PowerShell Modules"] += "$($module.Name) - $($_.Exception.Message)"
            }
        }
        Write-Host "PowerShell module update check completed."
    } catch {
        Write-Host "An error occurred while updating PowerShell modules. $_" -ForegroundColor Red
    }
} else {
    Write-Host "Skipping PowerShell Module updates as requested."
}

# --- Update Scoop ---
if (-not $NoScoop) {
    Write-SectionHeader "Updating Scoop and its packages"
    try {
        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            Write-Host "Checking for outdated Scoop packages..."
            $scoopStatus = & scoop status
            $outdatedApps = @()
            # We parse the output of 'scoop status' to find packages marked as outdated.
            foreach ($line in ($scoopStatus -split [System.Environment]::NewLine)) {
                if ($line -like '*outdated*') {
                    # Extracts the package name, which is the first element on the line.
                    # Security: Sanitize input to prevent injection
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
            Write-Host "Updating all installed packages via Scoop..."
            & scoop update *

            # Add a generic message to the summary if no specific packages were found to be outdated.
            if ($updatedItems["Scoop"].Count -eq 0) {
                $updatedItems["Scoop"] += "Ran 'scoop update *' (no outdated packages were detected beforehand)."
            }
        } else {
            Write-Host "Scoop is not installed. Skipping."
        }
    } catch {
        Write-Host "An error occurred while updating Scoop. Please check your Scoop installation." -ForegroundColor Red
        $failedItems["Scoop"] += "General Scoop Error - $($_.Exception.Message)"
    }
} else {
    Write-Host "Skipping Scoop updates as requested."
}

# --- Update Winget & Microsoft Store Apps ---
if (-not $NoWinget) {
    Write-SectionHeader "Updating Winget & Microsoft Store apps"
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "Checking for outdated Winget packages..."
            # We run 'winget upgrade' to get the list of upgradable packages.
            # We need to specify --include-unknown to match the upgrade command.
            $wingetUpgradeOutput = & winget upgrade --include-unknown
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
            & sudo winget upgrade --all --accept-source-agreements --accept-package-agreements --include-pinned --include-unknown

            # Add a generic message to the summary if no specific packages were found to be outdated.
            if ($updatedItems["Winget"].Count -eq 0) {
                $updatedItems["Winget"] += "Ran 'winget upgrade --all' (no outdated packages were detected beforehand)."
            }
        } else {
            Write-Host "Winget is not installed. Skipping."
        }
    } catch {
        $errorMessage = if ($_.Exception) { $_.Exception.Message } else { $_ }
        Write-Host "An error occurred while running 'winget upgrade'. The command may have failed. Error: $errorMessage" -ForegroundColor Red
        $failedItems["Winget"] += "Winget command failed - $errorMessage"
    }
} else {
    Write-Host "Skipping Winget updates as requested."
}


# --- Update Visual Studio Code Extensions ---
if (-not $NoVsCode) {
    Write-SectionHeader "Updating Visual Studio Code Extensions"
    try {
        if (Get-Command code -ErrorAction SilentlyContinue) {
            Write-Host "Checking for and updating all VS Code extensions..."
            $installedExtensions = & code --list-extensions
            $actuallyUpdated = @()

            foreach ($extensionId in $installedExtensions) {
                if ($extensionId.Trim().Length -gt 0) {
                    # Security: Validate extension ID format to prevent injection
                    if ($extensionId -match '^[a-zA-Z0-9._-]+\.[a-zA-Z0-9._-]+$') {
                        Write-Host "Checking/updating extension: $extensionId..."
                        # The '--force' flag ensures that the extension is updated if it's already installed. We capture stderr too.
                        $updateOutput = & code --install-extension $extensionId --force 2>&1

                        # We check the output to see if the extension was actually updated.
                        # The message for a successful update/install is "Extension ... was successfully installed."
                        # The message for no update is "Extension ... is already installed."
                        if ($updateOutput -join ' ' -like '*successfully installed*') {
                            Write-Host "--> Successfully updated $extensionId" -ForegroundColor Cyan
                            $actuallyUpdated += $extensionId
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

            if ($updatedItems["VS Code Extensions"].Count -eq 0) {
                $updatedItems["VS Code Extensions"] += "All extensions checked and were up-to-date."
            }
        } else {
            Write-Host "The 'code' command is not in your PATH. Skipping VS Code extension updates."
        }
    } catch {
        Write-Host "An error occurred while updating VS Code extensions. $_" -ForegroundColor Red
        $failedItems["VS Code Extensions"] += "General VS Code Error - $($_.Exception.Message)"
    }
} else {
    Write-Host "Skipping VS Code Extension updates as requested."
}

# --- Update Miniconda ---
if (-not $NoConda) {
    Write-SectionHeader "Updating Miniconda and 'ocr-azure' environment"
    try {
        if (Get-Command conda -ErrorAction SilentlyContinue) {
            Write-Host "Updating the base conda environment..."
            & conda update -n base -c defaults conda -y
            $updatedItems["Conda"] += "Miniconda (base)"
            
            if (& conda env list | Select-String -SimpleMatch -Quiet -Pattern "ocr-azure") {
                Write-Host "Found 'ocr-azure' environment. Updating all packages within it..."
                & conda update -n ocr-azure --all -y
                $updatedItems["Conda"] += "Conda environment (ocr-azure)"
            } else {
                Write-Host "'ocr-azure' environment not found. Skipping."
            }
        } else {
            Write-Host "conda is not found in your PATH. Skipping."
        }
    } catch {
        Write-Host "An error occurred while updating conda. $_" -ForegroundColor Red
        $failedItems["Conda"] += "General Conda Error - $($_.Exception.Message)"
    }
} else {
    Write-Host "Skipping Conda updates as requested."
}

# --- Update TeX Live ---
if (-not $NoTex) {
    Write-SectionHeader "Updating TeX Live"
    try {
        if (Get-Command tlmgr -ErrorAction SilentlyContinue) {
            Write-Host "Updating TeX Live package manager (tlmgr) and all packages..."
            & tlmgr update --self --all
            $updatedItems["TeX Live"] += "All packages"
        } else {
            Write-Host "TeX Live (tlmgr) is not installed or not in your PATH. Skipping."
        }
    } catch {
        Write-Host "An error occurred while updating TeX Live. Ensure you are running PowerShell as an Administrator. $_" -ForegroundColor Red
        $failedItems["TeX Live"] += "General TeX Live Error - $($_.Exception.Message)"
    }
} else {
    Write-Host "Skipping TeX Live updates as requested."
}

# --- Update WSL ---
if (-not $NoWsl) {
    Write-SectionHeader "Updating Windows Subsystem for Linux (WSL)"
    try {
        if (Get-Command wsl -ErrorAction SilentlyContinue) {
            Write-Host "Updating the WSL kernel..."
            & wsl --update
            Write-Host "Shutting down WSL to apply updates..."
            & wsl --shutdown
            $updatedItems["WSL"] += "WSL Kernel"

            # Now, attempt to update packages within the default WSL distro
            Write-Host "Attempting to update packages within the default WSL distribution..."
<<<<<<< HEAD
            try {
                # Use 'sudo -n true' as a generic check for non-interactive sudo access.
                # If this command fails, it means a password is required.
                Write-Host "Checking for passwordless sudo access..."
                & wsl.exe -e sudo -n true

=======

            # Check for passwordless sudo access by checking the exit code of an external command.
            # A try/catch block will not work for this.
            Write-Host "Checking for passwordless sudo access..."
            & wsl.exe -e sudo -n true 2>$null

            if ($LASTEXITCODE -eq 0) {
>>>>>>> origin/feature/improve-update-script
                Write-Host "Passwordless sudo confirmed. Proceeding with package updates..." -ForegroundColor Green
                & wsl.exe -e sudo apt-get update
                & wsl.exe -e sudo apt-get upgrade -y
                $updatedItems["WSL"] += "Updated packages in default WSL distro"
<<<<<<< HEAD
            } catch {
                # This block will be hit if the sudo command fails, likely due to requiring a password.
=======
            } else {
                # This block is now correctly triggered if the sudo command fails.
>>>>>>> origin/feature/improve-update-script
                Write-Warning "Could not run package updates with sudo automatically. This usually means you need to configure passwordless sudo for your user in WSL."
                Write-Warning "To enable this, run 'wsl' to enter your Linux environment, then get your username with the 'whoami' command."
                Write-Warning "Next, run 'sudo visudo' and add the following line at the end of the file, replacing 'your_linux_username' with the result from 'whoami':"
                Write-Warning "your_linux_username ALL=(ALL) NOPASSWD: /usr/bin/apt-get"
                $failedItems["WSL"] += "Package update failed (sudo configuration needed)"
            }
        } else {
            Write-Host "WSL is not installed. Skipping."
        }
    } catch {
        Write-Host "An error occurred while updating WSL."
        $failedItems["WSL"] += "WSL Update Error - $($_.Exception.Message)"
    }
} else {
    Write-Host "Skipping WSL updates as requested."
}

# --- Update npm Packages ---
if (-not $NoNpm) {
    Write-SectionHeader "Updating npm (Node Package Manager) Packages"
    try {
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            Write-Host "Updating globally installed npm packages..."
            # Get a list of outdated packages first for the summary
            $outdatedNpmPackages = & npm outdated -g --parseable --depth=0
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
            & npm update -g

            if ($updatedItems["npm"].Count -eq 0) {
                $updatedItems["npm"] += "Ran 'npm update -g' (no outdated packages were detected beforehand)."
            }
        } else {
            Write-Host "npm is not installed or not in your PATH. Skipping."
        }
    } catch {
        Write-Host "An error occurred while updating npm packages. $_" -ForegroundColor Red
        $failedItems["npm"] += "General npm Error - $($_.Exception.Message)"
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