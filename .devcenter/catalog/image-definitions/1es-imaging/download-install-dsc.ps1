
# Hardcoded output folder
$OutputFolder = "$env:Temp\DSC_Install"
$OutputFolder = "C:\ProgramData\Microsoft\DevBoxAgent\1ES"

# Detect OS and architecture
$arch = if ([Environment]::Is64BitOperatingSystem) { "x86_64" } else { "x86" }
if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { $arch = "aarch64" }

$os = $PSVersionTable.OS
if ($os -match "Windows") { $platform = "pc-windows-msvc" }
elseif ($os -match "Darwin") { $platform = "apple-darwin" }
elseif ($os -match "Linux") { $platform = "pc-linux-gnu" }
else { Write-Host "Unsupported OS"; exit 1 }

Write-Host "Detected architecture: $arch"
Write-Host "Detected platform: $platform"

# GitHub API URL for releases
$targetVersion = "v3.2.0-preview.7"
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
