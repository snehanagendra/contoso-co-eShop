# Requires Administrator privileges
#Requires -RunAsAdministrator

# Hardcoded output folder
$OutputFolder = "C:\ProgramData\Microsoft\DevBoxAgent\1ES"

# Function to install application
function Install-Application {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath,
        
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )
    
    Write-Host "Starting application installation using Add-AppxProvisionedPackage..."
    Write-Host "Package path: $PackagePath"
    Write-Host "Package name: $PackageName"

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

        # Use package name with Add-AppxProvisionedPackage
        Write-Host "Using package name '$PackageName' for installation"
        Add-AppxProvisionedPackage -Online -PackagePath $PackagePath -SkipLicense -Verbose

        $installEndTime = Get-Date
        $installDuration = $installEndTime - $installStartTime
        Write-Host "Installation completed at: $installEndTime"
        Write-Host "Installation duration: $($installDuration.TotalSeconds) seconds"
        Write-Host "Application '$PackageName' provisioned successfully for all users."
        
        return $true
    }
    catch {
        Write-Host "Failed to install application '$PackageName': $($_.Exception.Message)"
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
        
        return $false
    }
}

# Function to verify application installation
function Test-ApplicationInstallation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,
        
        [Parameter(Mandatory = $false)]
        [string]$VersionArgument = "--version",
        
        [Parameter(Mandatory = $false)]
        [string]$ApplicationName = $CommandName
    )
    
    Write-Host "Verifying $ApplicationName installation..."
    try {
        $commandPath = Get-Command $CommandName -ErrorAction SilentlyContinue
        if ($commandPath) {
            try {
                $version = & $CommandName $VersionArgument
                Write-Host "$ApplicationName installed successfully! Version: $version"
                return $true
            }
            catch {
                Write-Host "$ApplicationName command found but version check failed: $($_.Exception.Message)"
                return $true  # Command exists even if version check fails
            }
        } else {
            Write-Host "$ApplicationName command '$CommandName' not found in PATH. You may need to restart your session."
            return $false
        }
    }
    catch {
        Write-Host "Could not verify $ApplicationName installation: $($_.Exception.Message)"
        return $false
    }
}

# Main execution starts here
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

# Find the Dependencies ZIP asset
$dependenciesAsset = $release.assets | Where-Object { $_.name -like "*Dependencies*.zip" }
if ($dependenciesAsset) {
    Write-Host "Found dependencies ZIP: $($dependenciesAsset.name)"
} else {
    Write-Host "No dependencies ZIP found in the release assets."
}

# Extract package name from MSIX filename
$packageName = $msixAsset.name -replace '\.msixbundle$', ''
Write-Host "Extracted package name: $packageName"

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
    Invoke-WebRequest -Uri $msixAsset.browser_download_url -OutFile $msixPath -UseBasicParsing

    Write-Host "Download completed successfully." 
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
    exit 1
}

Write-Host "File verification successful - file exists at: $msixPath"
$fileItem = Get-Item $msixPath
$fileSize = $fileItem.Length
Write-Host "Downloaded file size: $([math]::Round($fileSize / 1MB, 2)) MB"
Write-Host "File creation time: $($fileItem.CreationTime)"
Write-Host "File last write time: $($fileItem.LastWriteTime)"

# Download and extract dependencies if available
if ($dependenciesAsset) {
    Write-Host "Downloading dependencies ZIP..."
    $dependenciesPath = Join-Path $OutputFolder $dependenciesAsset.name
    Write-Host "Dependencies download path: $dependenciesPath"
    
    try {
        Invoke-WebRequest -Uri $dependenciesAsset.browser_download_url -OutFile $dependenciesPath -UseBasicParsing
        Write-Host "Dependencies download completed successfully."
        
        # Verify dependencies file
        if (Test-Path $dependenciesPath) {
            $depFileSize = (Get-Item $dependenciesPath).Length
            Write-Host "Dependencies file size: $([math]::Round($depFileSize / 1MB, 2)) MB"
            
            # Extract dependencies
            $dependenciesExtractPath = Join-Path $OutputFolder "Dependencies"
            Write-Host "Extracting dependencies to: $dependenciesExtractPath"
            
            try {
                Expand-Archive -Path $dependenciesPath -DestinationPath $dependenciesExtractPath -Force
                Write-Host "Dependencies extracted successfully."
                
                # List extracted dependencies
                if (Test-Path $dependenciesExtractPath) {
                    Write-Host "Extracted dependency files:"
                    Get-ChildItem $dependenciesExtractPath -Recurse | ForEach-Object {
                        Write-Host "  $($_.FullName)"
                    }
                    
                    # Install dependencies from x64 folder
                    $x64DependenciesPath = Join-Path $dependenciesExtractPath "x64"
                    if (Test-Path $x64DependenciesPath) {
                        Write-Host "Installing dependencies from x64 folder: $x64DependenciesPath"
                        
                        # Find all MSIX/APPX files in the x64 folder
                        $dependencyPackages = Get-ChildItem $x64DependenciesPath -Filter "*.msix" -Recurse
                        $dependencyPackages += Get-ChildItem $x64DependenciesPath -Filter "*.appx" -Recurse
                        
                        if ($dependencyPackages) {
                            Write-Host "Found $($dependencyPackages.Count) dependency package(s) to install:"
                            foreach ($depPackage in $dependencyPackages) {
                                Write-Host "  Installing: $($depPackage.Name)"
                                try {
                                    Add-AppxProvisionedPackage -Online -PackagePath $depPackage.FullName -SkipLicense -Verbose
                                    Write-Host "  Successfully installed: $($depPackage.Name)"
                                }
                                catch {
                                    Write-Host "  Failed to install $($depPackage.Name): $($_.Exception.Message)"
                                    Write-Host "  Continuing with other dependencies..."
                                }
                            }
                            Write-Host "Dependencies installation completed."
                        } else {
                            Write-Host "No MSIX/APPX packages found in x64 dependencies folder."
                        }
                    } else {
                        Write-Host "x64 dependencies folder not found at: $x64DependenciesPath"
                        Write-Host "Available folders in dependencies:"
                        Get-ChildItem $dependenciesExtractPath -Directory | ForEach-Object {
                            Write-Host "  $($_.Name)"
                        }
                    }
                }
            }
            catch {
                Write-Host "Failed to extract dependencies: $($_.Exception.Message)"
            }
        } else {
            Write-Host "Dependencies file not found after download."
        }
    }
    catch {
        Write-Host "Failed to download dependencies: $($_.Exception.Message)"
        Write-Host "Continuing with installation without dependencies..."
    }
} else {
    Write-Host "No dependencies to download."
}

# Install the MSIX bundle using the modular function
$installSuccess = Install-Application -PackagePath $msixPath -PackageName $packageName

if (-not $installSuccess) {
    Write-Host "Installation failed. Exiting..."
    exit 1
}# Verify installation using the modular function
$verificationSuccess = Test-ApplicationInstallation -CommandName "winget" -ApplicationName "WinGet CLI"

Write-Host "WinGet CLI installation process completed."
if ($installSuccess -and $verificationSuccess) {
    Write-Host "Installation and verification both successful!"
    exit 0
} else {
    Write-Host "Installation completed but verification had issues. Check the logs above."
    exit 0
}