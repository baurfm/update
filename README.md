# Windows Development Environment Update Script

## Synopsis

This PowerShell script updates a comprehensive set of development tools and packages on a Windows system. It provides command-line switches to skip specific update sections for greater flexibility.

## Description

The script automates the process of updating:
- PowerShell Modules
- Scoop packages
- Winget packages
- Visual Studio Code extensions
- Miniconda (base and specific environments)
- TeX Live
- WSL (Windows Subsystem for Linux)

The script is designed to be flexible. You can skip any section by providing its corresponding `--No<Section>` parameter when you run the script.

At the end of the execution, a detailed summary is provided, listing all the packages and tools that were checked and updated.

## Parameters

The script accepts the following parameters to skip parts of the update process:

-   `-Help` or `-h` or `-?`: A switch to display the detailed help message and exit.
-   `-NoPowerShell`: A switch to skip updating PowerShell Modules.
-   `-NoScoop`: A switch to skip updating Scoop and its packages.
-   `-NoWinget`: A switch to skip updating Winget and Microsoft Store apps.
-   `-NoVsCode`: A switch to skip updating Visual Studio Code extensions.
-   `-NoConda`: A switch to skip updating Miniconda and its environments.
-   `-NoTex`: A switch to skip updating TeX Live.
-   `-NoWsl`: A switch to skip updating the Windows Subsystem for Linux (WSL).

## Examples

### Run all update tasks
```powershell
.\update.ps1
```

### Skip TeX Live and Miniconda/Conda updates
```powershell
.\update.ps1 -NoTex -NoConda
```

### Display the help message
```powershell
.\update.ps1 -h
```
or
```powershell
Get-Help .\update.ps1 -Full
```

## Prerequisites
- Windows operating system
- PowerShell
- The development tools you wish to update (e.g., Scoop, Winget, VS Code) must be installed and accessible from your system's PATH.
- For some operations, such as updating TeX Live or Winget packages, the script may require administrative privileges.
