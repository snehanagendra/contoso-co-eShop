

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

try {
    Invoke-WebRequest -Uri $msixAsset.browser_download_url -OutFile $msixPath -UseBasicParsing
    Write-Host "Download completed successfully."
}
catch {
    Write-Host "Failed to download MSIX bundle: $($_.Exception.Message)"
    exit 1
}

# Verify the downloaded file
if (-not (Test-Path $msixPath)) {
    Write-Host "Downloaded file not found at: $msixPath"
    exit 1
}

$fileSize = (Get-Item $msixPath).Length
Write-Host "Downloaded file size: $([math]::Round($fileSize / 1MB, 2)) MB"

# Install the MSIX bundle using Add-AppxProvisionedPackage
Write-Host "Installing WinGet CLI using Add-AppxProvisionedPackage..."

try {
    # Mount the default Windows image (assuming we're provisioning for the system)
    # Note: This command is typically used for offline Windows images
    # For online installation, we might need to use Add-AppxPackage instead
    
    # Use Add-AppxProvisionedPackage to install for all users (system-wide)
    Write-Host "Using Add-AppxProvisionedPackage for system-wide installation..."
    Add-AppxProvisionedPackage -Online -PackagePath $msixPath -SkipLicense
    Write-Host "WinGet CLI provisioned successfully for all users."
}
catch {
    Write-Host "Failed to install WinGet CLI: $($_.Exception.Message)"
    Write-Host "You may need to install dependencies first (Visual C++ Redistributable, etc.)"
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
