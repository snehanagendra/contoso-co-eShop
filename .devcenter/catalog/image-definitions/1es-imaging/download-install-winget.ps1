

# Hardcoded output folder
$OutputFolder = "$env:Temp\WinGet_Install"
$OutputFolder = "C:\ProgramData\Microsoft\DevBoxAgent\1ES"

# Requires Administrator privileges
#Requires -RunAsAdministrator

Write-Host "Starting WinGet CLI download and installation..."

# GitHub API URL for WinGet CLI releases
$targetVersion = "v1.12.350"
$apiUrl = "https://api.github.com/repos/microsoft/winget-cli/releases"

Write-Host "Fetching WinGet CLI release info for version $targetVersion..."
$releases = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
$release = $releases | Where-Object { $_.tag_name -eq $targetVersion }

if (-not $release) {
    Write-Host "Release version $targetVersion not found. Available versions:"
    $releases | Select-Object -First 10 tag_name | ForEach-Object { Write-Host "  $($_.tag_name)" }
    exit 1
}

Write-Host "Found release: $($release.name) (published: $($release.published_at))"

# Find the MSIX bundle asset
$msixAsset = $release.assets | Where-Object { $_.name -like "*.msixbundle" }
if (-not $msixAsset) {
    Write-Host "No MSIX bundle found in the release assets."
    exit 1
}

Write-Host "Found MSIX bundle: $($msixAsset.name)"

# Create output folder if not exists
try {
    if (-not (Test-Path $OutputFolder)) {
        Write-Host "Creating directory: $OutputFolder"
        New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    }
}
catch {
    Write-Host "Failed to create output directory: $($_.Exception.Message)"
    exit 1
}

# Download the MSIX bundle
$msixPath = Join-Path $OutputFolder $msixAsset.name
Write-Host "Downloading MSIX bundle to: $msixPath"
Write-Host "Download URL: $($msixAsset.browser_download_url)"
Write-Host "File size from GitHub: $([math]::Round($msixAsset.size / 1MB, 2)) MB"

Write-Host "Starting download with Invoke-WebRequest..."
try {
    $downloadStartTime = Get-Date
    Write-Host "Download started at: $downloadStartTime"
    
    Invoke-WebRequest -Uri $msixAsset.browser_download_url -OutFile $msixPath -UseBasicParsing
    
    $downloadEndTime = Get-Date
    $downloadDuration = $downloadEndTime - $downloadStartTime
    
    Write-Host "Download completed successfully at: $downloadEndTime"
    Write-Host "Download duration: $($downloadDuration.TotalSeconds) seconds"
}
catch {
    Write-Host "Failed to download MSIX bundle: $($_.Exception.Message)"
    Write-Host "Exception type: $($_.Exception.GetType().FullName)"
    if ($_.Exception.InnerException) {
        Write-Host "Inner exception: $($_.Exception.InnerException.Message)"
    }
    Write-Host "Failed at: $(Get-Date)"
    exit 1
}

# Verify the downloaded file
Write-Host "Verifying downloaded file..."
if (-not (Test-Path $msixPath)) {
    Write-Host "ERROR: Downloaded file not found at: $msixPath"
    Write-Host "Checking if directory exists: $(Test-Path $OutputFolder)"
    if (Test-Path $OutputFolder) {
        Write-Host "Directory contents:"
        Get-ChildItem $OutputFolder | ForEach-Object { Write-Host "  $($_.Name)" }
    }
    exit 1
}

Write-Host "File verification successful - file exists at: $msixPath"
$fileItem = Get-Item $msixPath
$fileSize = $fileItem.Length
Write-Host "Downloaded file size: $([math]::Round($fileSize / 1MB, 2)) MB"
Write-Host "File creation time: $($fileItem.CreationTime)"
Write-Host "File last write time: $($fileItem.LastWriteTime)"

# Verify file is not corrupted (basic check)
if ($fileSize -lt 1MB) {
    Write-Host "WARNING: File size seems too small for an MSIX bundle"
}
Write-Host "File verification completed successfully."

# Install the MSIX bundle using Add-AppxProvisionedPackage
Write-Host "Starting WinGet CLI installation using Add-AppxProvisionedPackage..."
Write-Host "Installation method: Add-AppxProvisionedPackage -Online"
Write-Host "Package path: $msixPath"

try {
    # Check if running as administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-Host "Running as Administrator: $isAdmin"
    
    if (-not $isAdmin) {
        Write-Host "WARNING: Not running as administrator - this may cause the installation to fail"
    }
    
    Write-Host "Executing Add-AppxProvisionedPackage command..."
    Write-Host "Current PowerShell version: $($PSVersionTable.PSVersion)"
    Write-Host "PowerShell edition: $($PSVersionTable.PSEdition)"
    
    $installStartTime = Get-Date
    Write-Host "Installation started at: $installStartTime"
    
    # Try to run in PowerShell 7 inline and capture output
    if (Get-Command "pwsh.exe" -ErrorAction SilentlyContinue) {
        Write-Host "PowerShell 7 found, attempting installation with pwsh.exe..."
        
        # Run the installation command and capture all output
        $pwshResult = & pwsh.exe -Command "
            try {
                Write-Host 'PowerShell 7 - Starting Add-AppxProvisionedPackage...'
                Write-Host 'Package path: $msixPath'
                Add-AppxProvisionedPackage -Online -PackagePath '$msixPath' -SkipLicense -Verbose
                Write-Host 'PowerShell 7 - Installation completed successfully'
            }
            catch {
                Write-Host 'PowerShell 7 - Installation failed:'
                Write-Host 'Error message:' `$_.Exception.Message
                Write-Host 'Exception type:' `$_.Exception.GetType().FullName
                Write-Host 'HRESULT:' `$_.Exception.HResult
                throw `$_.Exception
            }
        " 2>&1
        
        Write-Host "=== PowerShell 7 Command Output ==="
        if ($pwshResult) {
            $pwshResult | ForEach-Object {
                Write-Host "PWSH7: $_"
            }
        } else {
            Write-Host "PWSH7: No output captured"
        }
        Write-Host "=== End PowerShell 7 Output ==="
        Write-Host "PowerShell 7 exit code: $LASTEXITCODE"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Installation succeeded via PowerShell 7"
        } else {
            Write-Host "Installation failed via PowerShell 7, exit code: $LASTEXITCODE"
            
            # Parse the error output for more details
            $errorLines = $pwshResult | Where-Object { $_ -match "Error message:|Exception type:|HRESULT:" }
            if ($errorLines) {
                Write-Host "Parsed error details from PowerShell 7:"
                $errorLines | ForEach-Object { Write-Host "  $_" }
            }
            
            throw "PowerShell 7 installation failed with exit code: $LASTEXITCODE"
        }
    } else {
        Write-Host "PowerShell 7 not available, using current session..."
        Add-AppxProvisionedPackage -Online -PackagePath $msixPath -SkipLicense -Verbose
    }
    
    $installEndTime = Get-Date
    $installDuration = $installEndTime - $installStartTime
    Write-Host "Installation completed at: $installEndTime"
    Write-Host "Installation duration: $($installDuration.TotalSeconds) seconds"
    Write-Host "WinGet CLI provisioned successfully for all users."
}
catch {
    Write-Host "Failed to install WinGet CLI: $($_.Exception.Message)"
    Write-Host "Exception type: $($_.Exception.GetType().FullName)"
    if ($_.Exception.InnerException) {
        Write-Host "Inner exception: $($_.Exception.InnerException.Message)"
    }
    Write-Host "HRESULT (if available): $($_.Exception.HResult)"
    Write-Host "You may need to install dependencies first (Visual C++ Redistributable, etc.)"
    Write-Host "Failed at: $(Get-Date)"
    
    # Additional troubleshooting info
    Write-Host "System information for troubleshooting:"
    Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
    Write-Host "OS version: $($PSVersionTable.OS)"
    Write-Host "Current user: $($env:USERNAME)"
    
    exit 1
}

# Verify installation
Write-Host "Verifying WinGet installation..."
try {
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetPath) {
        $wingetVersion = & winget --version
        Write-Host "WinGet CLI installed successfully! Version: $wingetVersion"
    } else {
        Write-Host "WinGet command not found in PATH. You may need to restart your session."
    }
}
catch {
    Write-Host "Could not verify WinGet installation: $($_.Exception.Message)"
}

Write-Host "WinGet CLI installation process completed."
