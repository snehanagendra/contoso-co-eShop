#Requires -Version 5.1
<#
.SYNOPSIS
    Downloads and installs Azure Bicep CLI from GitHub releases.

.DESCRIPTION
    This script automatically detects the operating system and architecture,
    downloads the appropriate Bicep executable from GitHub releases, and
    installs it to the specified path for 1ES imaging.

.EXAMPLE
    .\download-install-bicep.ps1
    Downloads the latest Bicep release
#>



# Set error action preference
$ErrorActionPreference = "Stop"

# Configuration
$GitHubRepo = "Azure/bicep"
$InstallPath = "C:\ProgramData\Microsoft\DevBoxAgent\1ES"
$BicepExecutable = "bicep.exe"
$FullInstallPath = Join-Path $InstallPath $BicepExecutable



# Function to detect Windows architecture
function Get-WindowsArchitecture {
    Write-Host "Detecting Windows architecture..."
    
    # Get processor architecture from environment variable
    $processorArch = $env:PROCESSOR_ARCHITECTURE
    
    # Fallback to WMI if environment variable is not available
    if (-not $processorArch) {
        try {
            $processorArch = (Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1).Architecture
            # Convert WMI architecture codes to strings (only x64 and ARM64 supported)
            switch ($processorArch) {
                9 { $processorArch = "AMD64" }
                12 { $processorArch = "ARM64" }
                default { 
                    throw "Unsupported WMI architecture code: $processorArch. Only x64 (9) and ARM64 (12) are supported."
                }
            }
        }
        catch {
            throw "Could not determine architecture from WMI and environment variable is not available. Only x64 and ARM64 are supported."
        }
    }
    
    # Normalize architecture names for Bicep asset matching (only x64 and arm64 supported)
    $arch = switch -Regex ($processorArch.ToString().ToUpper()) {
        "AMD64|X64" { "x64" }
        "ARM64" { "arm64" }
        default { 
            throw "Unsupported architecture: $processorArch. Only x64 and ARM64 are supported."
        }
    }
    
    Write-Host "Detected Windows Architecture: $arch"
    return $arch
}

# Function to get the latest or specific release information
function Get-BicepRelease {
    param(
        [string]$Version
    )
    
    Write-Host "Fetching release information from GitHub..."
    
    try {
        $headers = @{
            'User-Agent' = 'PowerShell-BicepInstaller'
            'Accept' = 'application/vnd.github.v3+json'
        }
        
        if ($Version) {
            Write-Host "Fetching all releases to find specific version: $Version"
            $releaseUrl = "https://api.github.com/repos/$GitHubRepo/releases"
            $allReleases = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -TimeoutSec 30
            
            # Search for the specific version by tag_name
            $release = $allReleases | Where-Object { $_.tag_name -eq $Version }
            
            if (-not $release) {
                Write-Host "Available releases:"
                $allReleases | ForEach-Object { Write-Host "  - $($_.tag_name)" }
                throw "Version '$Version' not found in releases"
            }
            
            Write-Host "Found specific release: $($release.tag_name)"
        } else {
            Write-Host "Fetching latest release"
            $releaseUrl = "https://api.github.com/repos/$GitHubRepo/releases/latest"
            $release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -TimeoutSec 30
            Write-Host "Found latest release: $($release.tag_name)"
        }
        
        return $release
    }
    catch {
        if ($Version) {
            throw "Failed to fetch release information for version '$Version': $_"
        } else {
            throw "Failed to fetch latest release information: $_"
        }
    }
}

# Function to find the appropriate Windows asset
function Get-BicepWindowsAsset {
    param(
        [object]$Release,
        [string]$Architecture
    )
    
    Write-Host "Looking for Windows Bicep asset for $Architecture architecture..."
    
    # Build expected asset name for Windows
    $expectedAssetName = "bicep-win-$Architecture.exe"
    
    Write-Host "Looking for asset: $expectedAssetName"
    
    # Find exact matching asset
    $matchingAsset = $Release.assets | Where-Object { $_.name -eq $expectedAssetName }
    
    if (-not $matchingAsset) {
        # Fallback: try to find any Windows asset that contains the architecture
        $matchingAsset = $Release.assets | Where-Object { 
            $_.name -match "win" -and $_.name -match $Architecture -and $_.name -match "\.exe$"
        }
    }
    
    if (-not $matchingAsset) {
        # Final fallback: look for any Windows executable
        $matchingAsset = $Release.assets | Where-Object { 
            $_.name -match "win.*\.exe$"
        }
        if ($matchingAsset) {
            Write-Host "Using fallback Windows asset: $($matchingAsset.name)"
        }
    }
    
    if (-not $matchingAsset) {
        Write-Host "Available assets:"
        $Release.assets | ForEach-Object { Write-Host "  - $($_.name)" }
        throw "No suitable Windows asset found for $Architecture architecture"
    }
    
    Write-Host "Found matching asset: $($matchingAsset.name)"
    return $matchingAsset
}

# Function to download and install Bicep
function Install-Bicep {
    param(
        [object]$Asset,
        [string]$InstallDirectory,
        [string]$ExecutableName
    )
    
    Write-Host "Starting Bicep installation..."
    
    # Create install directory if it doesn't exist
    if (-not (Test-Path $InstallDirectory)) {
        Write-Host "Creating install directory: $InstallDirectory"
        New-Item -Path $InstallDirectory -ItemType Directory -Force | Out-Null
    }
    
    $tempFile = Join-Path $env:TEMP "bicep-temp-$([System.Guid]::NewGuid().ToString('N')[0..7] -join '')"
    $finalPath = Join-Path $InstallDirectory $ExecutableName
    
    try {
        Write-Host "Downloading $($Asset.name) from $($Asset.browser_download_url)..."
        
        # Download with progress
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add('User-Agent', 'PowerShell-BicepInstaller')
        
        $webClient.DownloadFile($Asset.browser_download_url, $tempFile)
        $webClient.Dispose()
        
        Write-Host "Download completed successfully"
        
        # Move to final location
        Write-Host "Installing to: $finalPath"
        Move-Item -Path $tempFile -Destination $finalPath -Force
        
        Write-Host "Installation completed successfully"
        
        # Verify installation
        if (Test-Path $finalPath) {
            $fileSize = (Get-Item $finalPath).Length
            Write-Host "Installed file size: $([math]::Round($fileSize / 1MB, 2)) MB"
            
            # Try to get version (may not work if dependencies are missing)
            try {
                $versionOutput = & $finalPath --version 2>$null
                if ($versionOutput) {
                    Write-Host "Bicep version: $versionOutput"
                }
            }
            catch {
                Write-Host "Bicep installed but version check failed (this may be normal in some environments)"
            }
        } else {
            throw "Installation verification failed - file not found at $finalPath"
        }
    }
    catch {
        # Cleanup temp file if it exists
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
        throw "Installation failed: $_"
    }
}

# Main execution
try {
    Write-Host "Starting Bicep installation process for Windows..."
    
    # Check if already installed and show current version
    if (Test-Path $FullInstallPath) {
        Write-Host "Bicep is already installed at $FullInstallPath - will overwrite"
        
        # Try to show current version
        try {
            $currentVersion = & $FullInstallPath --version 2>$null
            if ($currentVersion) {
                Write-Host "Current version: $currentVersion"
            }
        }
        catch {
            Write-Host "Could not determine current version"
        }
    }
    
    # Get Windows architecture
    $architecture = Get-WindowsArchitecture
    
    # Get release information
    $Version = "v0.36.177"
    $release = Get-BicepRelease -Version $Version
    
    # Find appropriate Windows asset
    $asset = Get-BicepWindowsAsset -Release $release -Architecture $architecture
    
    # Install Bicep
    Install-Bicep -Asset $asset -InstallDirectory $InstallPath -ExecutableName $BicepExecutable
    
    Write-Host "Bicep installation completed successfully!"
    Write-Host "Bicep executable location: $FullInstallPath"
}
catch {
    Write-Host "Installation failed with error: $_"
    Write-Host "Error details:"
    Write-Host "  - Script Name: $($MyInvocation.MyCommand.Name)"
    Write-Host "  - Error Line: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "  - Error Position: $($_.InvocationInfo.PositionMessage)"
    Write-Host "  - Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "  - Stack Trace: $($_.ScriptStackTrace)"
    Write-Host "  - Target Repository: $GitHubRepo"
    Write-Host "  - Install Path: $InstallPath"
    if ($architecture) {
        Write-Host "  - Detected Architecture: $architecture"
    }
    if ($release) {
        Write-Host "  - Release Version: $($release.tag_name)"
    }
    if ($asset) {
        Write-Host "  - Asset Name: $($asset.name)"
        Write-Host "  - Asset URL: $($asset.browser_download_url)"
    }
    Write-Host "Installation process terminated due to error."
    exit 1
}