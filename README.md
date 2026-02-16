# Windows Development Environment Update Script

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A comprehensive PowerShell script that automates the update process for multiple development tools and package managers on Windows systems. This script provides granular control over which components to update, making it perfect for maintaining a clean and up-to-date development environment.

## 🚀 Features

- **Comprehensive Coverage**: Updates 7 different development tool categories
- **Selective Updates**: Skip specific sections using command-line parameters
- **Error Handling**: Robust error handling with detailed reporting
- **Progress Tracking**: Real-time progress updates and final summary
- **Administrative Support**: Handles elevated privileges when needed, including the new Windows `sudo`.
- **Cross-Platform Tools**: Supports both Windows-native and cross-platform tools

## 📦 Supported Tools

| Category | Tools Updated | Command Used |
|----------|---------------|--------------|
| **PowerShell** | All installed modules | `Update-Module` |
| **Scoop** | Scoop itself + all packages | `scoop update` |
| **Winget** | All Microsoft Store apps | `winget upgrade --all` |
| **VS Code** | All installed extensions | `code --install-extension` |
| **Conda** | Base environment + ocr-azure | `conda update` |
| **npm** | All globally installed packages | `npm update -g` |
| **TeX Live** | All TeX packages | `tlmgr update --self --all` |
| **WSL** | WSL kernel + distro packages | `wsl --update`, `apt-get upgrade` |

## 🛠️ Installation

1. **Clone or download** this repository to your local machine
2. **Ensure PowerShell execution policy** allows script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
3. **Verify prerequisites** are installed (see Prerequisites section below)

## 📖 Usage

### Basic Usage

```powershell
# Update all tools
.\update.ps1

# Skip specific sections
.\update.ps1 -NoTex -NoConda

# Display help
.\update.ps1 -h
```

### Advanced Usage

```powershell
# Update only PowerShell modules and VS Code extensions
.\update.ps1 -NoScoop -NoWinget -NoConda -NoTex -NoWsl

# Update everything except TeX Live (requires admin privileges)
.\update.ps1 -NoTex

# Get detailed help information
Get-Help .\update.ps1 -Full
```

## ⚙️ Parameters

| Parameter | Alias | Description |
|-----------|-------|-------------|
| `-Help` | `-h`, `-?` | Display detailed help message and exit |
| `-NoPowerShell` | - | Skip updating PowerShell Modules |
| `-NoScoop` | - | Skip updating Scoop and its packages |
| `-NoWinget` | - | Skip updating Winget and Microsoft Store apps |
| `-NoVsCode` | - | Skip updating Visual Studio Code extensions |
| `-NoConda` | - | Skip updating Miniconda and its environments |
| `-NoNpm` | - | Skip updating global npm packages |
| `-NoTex` | - | Skip updating TeX Live |
| `-NoWsl` | - | Skip updating Windows Subsystem for Linux (WSL) |

## 📋 Prerequisites

### Required
- **Windows 10/11** (or Windows Server 2019+)
- **PowerShell 5.1+** (Windows PowerShell) or **PowerShell 7+** (PowerShell Core)
- **Administrative privileges** (for some operations like TeX Live and Winget)

### Optional (Install as needed)
- **Scoop** - Windows package manager
- **Winget** - Microsoft's package manager (Windows 10 1709+)
- **Visual Studio Code** - Code editor
- **Miniconda/Anaconda** - Python package manager
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

The script now automatically updates packages within your default WSL distribution using `apt-get`. This requires `sudo` access. To allow the script to run `sudo` without a password prompt, you need to add a configuration file to your WSL instance.

**How to Configure Passwordless `sudo` for `apt-get`**

1.  Open your WSL terminal (e.g., by running `wsl` in PowerShell).
2.  Find your exact Linux username by running the command: `whoami`.
3.  Open the `sudoers` configuration file with the command: `sudo visudo`. This will open the file in a terminal-based editor like `nano` or `vim`.
4.  Add the following line to the very end of the file. **It is critical to replace `your_linux_username` with the actual username you found in step 2.**

    ```
    your_linux_username ALL=(ALL) NOPASSWD: /usr/bin/apt-get
    ```
5.  Save the file and exit the editor (in `nano`, press `Ctrl+X`, then `Y`, then `Enter`). The script will now be able to update your WSL packages without a password prompt.

### Sample Output

```
==================================================
  Updating PowerShell Modules
==================================================

Checking for installed PowerShell modules and updating them...
Updating module: Pester...
PowerShell module update check completed.

==================================================
  Update Summary
==================================================

--- Successfully Ran: PowerShell Modules ---
- Pester
- PSReadLine

No failures were reported during this run.
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

## 📈 Version History

- **v9.5** - Fixed winget/scoop retry bug, removed dead code, cleanup
- **v9.4** - Removed dry-run option, added retry logic to all sections, proper exit codes
- **v9.3** - Improved WSL updates with retry logic and better sudo handling
- **v9.2** - Added support for the new Windows `sudo` command.
- **v9.1** - Fixed PSScriptAnalyzer warning for unused variable
- **v9.0** - Added comprehensive error handling and summary reporting
- **v8.x** - Previous versions with incremental improvements

---

**Note**: This script is designed for Windows development environments. For Linux or macOS, consider using similar tools like `apt`, `brew`, or `yum` with appropriate scripts.
