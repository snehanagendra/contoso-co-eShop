param(
    [Parameter(Mandatory = $true, HelpMessage = "Directory path where the Bicep configuration file will be created")]
    [string]$DirectoryPath,

    [Parameter(Mandatory = $false, HelpMessage = "Extension reference (registry reference like 'br:...', or URL). If not provided, the extension will be downloaded.")]
    [string]$ExtensionLocation = ""
)

# Hardcoded URI for downloading the DSC extension
$dscExtensionUri = "https://github.com/microsoft/bicep-types-dsc/releases/download/v0.1.0/dsc.tgz"

# Build the full file path
$bicepConfigPath = Join-Path -Path $DirectoryPath -ChildPath "bicepconfig.json"

# Check if directory exists, create only if it doesn't
if (-not (Test-Path -Path $DirectoryPath)) {
    Write-Host "Creating directory: $DirectoryPath" -ForegroundColor Cyan
    New-Item -Path $DirectoryPath -ItemType Directory -Force | Out-Null
    Write-Host "Directory created successfully" -ForegroundColor Green
} else {
    Write-Host "Directory already exists: $DirectoryPath" -ForegroundColor Yellow
}

# Determine the extension location
$extensionLocation = ""
if ([string]::IsNullOrWhiteSpace($ExtensionLocation)) {
    # Download the extension to DirectoryPath/out
    Write-Host "No extension path provided. Downloading DSC extension from: $dscExtensionUri" -ForegroundColor Cyan
    
    $outDirectory = Join-Path -Path $DirectoryPath -ChildPath "out"
    if (-not (Test-Path -Path $outDirectory)) {
        Write-Host "Creating out directory: $outDirectory" -ForegroundColor Cyan
        New-Item -Path $outDirectory -ItemType Directory -Force | Out-Null
    }
    
    $downloadPath = Join-Path -Path $outDirectory -ChildPath "dsc.tgz"
    
    try {
        Invoke-WebRequest -Uri $dscExtensionUri -OutFile $downloadPath
        Write-Host "Extension downloaded successfully to: $downloadPath" -ForegroundColor Green
        $extensionLocation = "./out/dsc.tgz"
    }
    catch {
        Write-Error "Failed to download DSC extension: $_"
        exit 1
    }
} else {
    # Use the provided extension path without validation
    Write-Host "Using provided extension reference: $ExtensionLocation" -ForegroundColor Green
    $extensionLocation = $ExtensionLocation
}

# Build the Bicep config JSON with the determined extension location
$bicepConfig = @{
    experimentalFeaturesEnabled = @{
        desiredStateConfiguration = $true
        moduleExtensionConfigs = $true
    }
    extensions = @{
        dsc = $extensionLocation
    }
    implicitExtensions = @()
}

$bicepConfigJson = $bicepConfig | ConvertTo-Json -Depth 10 -Compress

# Write the Bicep config file
Write-Host "Writing Bicep configuration to: $bicepConfigPath" -ForegroundColor Cyan
Set-Content -Path $bicepConfigPath -Value $bicepConfigJson -Force
Write-Host "Bicep configuration file written successfully" -ForegroundColor Green
