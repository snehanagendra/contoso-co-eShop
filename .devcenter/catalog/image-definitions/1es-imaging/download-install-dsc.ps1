
# Hardcoded output folder
$OutputFolder = "$env:Temp\DSC_Install"
$OutputFolder = "C:\ProgramData\Microsoft\DevBoxAgent\1ES"

# Detect OS and architecture with detailed logging
Write-Host "=== OS and Architecture Detection ==="

# Log environment information
Write-Host "PSVersionTable.OS: '$($PSVersionTable.OS)'"
Write-Host "Environment.OSVersion: '$([Environment]::OSVersion)'"
Write-Host "Environment.Is64BitOperatingSystem: '$([Environment]::Is64BitOperatingSystem)'"
Write-Host "PROCESSOR_ARCHITECTURE env var: '$($env:PROCESSOR_ARCHITECTURE)'"

$arch = if ([Environment]::Is64BitOperatingSystem) { "x86_64" } else { "x86" }
Write-Host "Initial arch detection: $arch"

if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { 
    $arch = "aarch64" 
    Write-Host "ARM64 detected, arch changed to: $arch"
}

# Hardcode arch for troubleshooting
$arch = "x86_64"
Write-Host "Architecture hardcoded to: $arch"

$os = $PSVersionTable.OS
Write-Host "OS string to match against: '$os'"

# Hardcode to Windows platform for troubleshooting
$platform = "pc-windows-msvc"
Write-Host "Platform hardcoded to: $platform"

Write-Host "Final detected architecture: $arch"
Write-Host "Final detected platform: $platform"
Write-Host "=== End Detection ==="

# GitHub API URL for releases
$targetVersion = "v3.1.2"
$apiUrl = "https://api.github.com/repos/PowerShell/DSC/releases"

Write-Host "Fetching DSC release info for version $targetVersion..."
$releases = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
$release = $releases | Where-Object { $_.tag_name -eq $targetVersion }

if (-not $release) {
    Write-Host "Release version $targetVersion not found. Available versions:"
    $releases | Select-Object -First 10 tag_name | ForEach-Object { Write-Host "  $($_.tag_name)" }
    exit 1
}

Write-Host "Found release: $($release.name) (published: $($release.published_at))"

# Find matching asset
$asset = $release.assets | Where-Object { $_.name -match "$arch-$platform" -and $_.name -like "*.zip" }
if (-not $asset) { Write-Host "No matching asset found."; exit 1 }

Write-Host "Found asset: $($asset.name)"

# Create output folder if not exists
if (-not (Test-Path $OutputFolder)) { New-Item -ItemType Directory -Path $OutputFolder | Out-Null }

# Download asset
$zipPath = Join-Path $OutputFolder $asset.name
Write-Host "Downloading to $zipPath..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath

# Extract ZIP
Write-Host "Extracting ZIP to $OutputFolder..."
Expand-Archive -Path $zipPath -DestinationPath $OutputFolder -Force

Write-Host "DSC runtime downloaded and extracted successfully to $OutputFolder."
