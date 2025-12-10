<#
.SYNOPSIS
This script installs PowerShell 7, Bicep CLI, and DSC v3, and applies a DSC configuration file.

.PARAMETER ConfigurationFile
The path to the DSC configuration file. The file must be located on the local machine.

.DESCRIPTION
The script supports provisioning a system by applying a DSC configuration file. If PowerShell 7, Bicep CLI, or DSC v3 are missing, it installs them as well.
This script works in both system (SYSTEM account) and user contexts.

#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ConfigurationFile
)

$InstallScope = "CurrentUser"
if ($(whoami.exe) -eq "nt authority\system") {
    $InstallScope = "AllUsers"
}

# Fixed installation path for both Bicep and DSC
$script:InstallPath = "C:\ProgramData\Microsoft\DevBoxAgent\DSC"

# Set the progress preference to silently continue
# in order to avoid progress bars in the output
# as this makes web requests very slow
# Reference: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables
$ProgressPreference = 'SilentlyContinue'

function WithRetry {
    Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position = 1, Mandatory = $false)]
        [int]$Maximum = 5,

        [Parameter(Position = 2, Mandatory = $false)]
        [int]$Delay = 100,

        [Parameter(Position = 3, Mandatory = $false)]
        [string]$FailureNotification = $null
    )

    $iterationCount = 0
    $lastException = $null
    do {
        $iterationCount++
        try {
            Invoke-Command -Command $ScriptBlock
            return
        }
        catch {
            $lastException = $_
            Write-Host $_

            # Sleep for a random amount of time with exponential backoff
            $randomDouble = Get-Random -Minimum 0.0 -Maximum 1.0
            $k = $randomDouble * ([Math]::Pow(2.0, $iterationCount) - 1.0)
            Start-Sleep -Milliseconds ($k * $Delay)
        }
    } while ($iterationCount -lt $Maximum)

    Write-Host $FailureNotification
    throw $lastException
}

function InstallPS7 {
    if (!(Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host "Installing PowerShell 7"
        $installPowershellUri = "https://aka.ms/install-powershell.ps1"
        $code = Invoke-RestMethod -Uri $installPowershellUri
        $null = New-Item -Path function:Install-PowerShell -Value $code
        WithRetry -ScriptBlock {
            if ("$($InstallScope)" -eq "CurrentUser") {
                Install-PowerShell -UseMSI
            }
            else {
                # The -Quiet flag requires admin permissions
                Install-PowerShell -UseMSI -Quiet
            }
        } -Maximum 5 -Delay 100 -FailureNotification "Failed to install PowerShell from $installPowershellUri"
        # Need to update the path post install
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User") + ";C:\Program Files\PowerShell\7"
        Write-Host "Done Installing PowerShell 7"
    }
    else {
        Write-Host "PowerShell 7 is already installed"
    }
}

function Get-WindowsArchitecture {
    Write-Host "Detecting Windows architecture..."
    
    # Try to get architecture from environment variable first
    $processorArch = $env:PROCESSOR_ARCHITECTURE
    
    if (-not $processorArch) {
        # Fallback to WMI
        try {
            $processorArch = (Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1).Architecture
            
            # Convert WMI architecture codes to strings
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
    
    # Normalize architecture names for asset matching
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

function InstallBicepCLI {
    $bicepInstalled = $false
    
    # Check if bicep is already in PATH
    if (Get-Command bicep -ErrorAction SilentlyContinue) {
        try {
            $currentVersion = & bicep --version 2>$null
            if ($currentVersion) {
                Write-Host "Bicep CLI is already installed: $currentVersion"
            }
        }
        catch {
            Write-Host "Bicep CLI is already installed"
        }
        $bicepInstalled = $true
    }
    
    if (-not $bicepInstalled) {
        Write-Host "Installing Bicep CLI"
        
        try {
            # Create installation directory if it doesn't exist
            if (-not (Test-Path -Path $script:InstallPath)) {
                New-Item -ItemType Directory -Path $script:InstallPath -Force | Out-Null
            }
            
            $bicepExePath = Join-Path -Path $script:InstallPath -ChildPath "bicep.exe"
            
            # Get architecture
            $architecture = Get-WindowsArchitecture
            
            # Map architecture to Bicep release naming convention
            $bicepArchMap = @{
                "x64" = "x64"
                "arm64" = "arm64"
            }
            
            if (-not $bicepArchMap.ContainsKey($architecture)) {
                throw "Unsupported architecture for Bicep: $architecture. Only x64 and arm64 are supported."
            }
            
            $bicepArch = $bicepArchMap[$architecture]
            Write-Host "Using Bicep architecture: $bicepArch"
            
            # Use specific version for Bicep
            $bicepVersion = "v0.36.177"
            Write-Host "Fetching Bicep version: $bicepVersion"
            
            # Build download URL for specific version using Bicep naming convention
            $bicepUrl = "https://github.com/Azure/bicep/releases/download/$bicepVersion/bicep-win-$bicepArch.exe"
            
            Write-Host "Downloading Bicep from: $bicepUrl"
            Write-Host "Installing to: $bicepExePath"
            
            # Remove existing file if it exists
            if (Test-Path $bicepExePath) {
                Write-Host "Removing existing file: $bicepExePath"
                Remove-Item -Path $bicepExePath -Force
            }
            
            WithRetry -ScriptBlock {
                Invoke-WebRequest -Uri $bicepUrl -OutFile $bicepExePath
            } -Maximum 5 -Delay 100 -FailureNotification "Failed to download Bicep CLI from $bicepUrl"
            
            Write-Host "Download completed successfully"
            
            # Verify installation
            if (Test-Path $bicepExePath) {
                $fileSize = (Get-Item $bicepExePath).Length
                Write-Host "Installed file size: $([math]::Round($fileSize / 1MB, 2)) MB"
            }
            else {
                throw "Installation verification failed - file not found at $bicepExePath"
            }
            
            # Add to PATH
            if ($InstallScope -eq "AllUsers") {
                $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
                if ($currentPath -notlike "*$script:InstallPath*") {
                    [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$script:InstallPath", "Machine")
                }
            }
            else {
                $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
                if ($currentPath -notlike "*$script:InstallPath*") {
                    [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$script:InstallPath", "User")
                }
            }
            
            # Update current session PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            
            Write-Host "Done Installing Bicep CLI to $bicepExePath"
            
            # Try to get version
            try {
                $versionOutput = & $bicepExePath --version 2>$null
                if ($versionOutput) {
                    Write-Host "Bicep version: $versionOutput"
                }
            }
            catch {
                Write-Host "Bicep installed but version check failed (this may be normal in some environments)"
            }
        }
        catch {
            Write-Host "Failed to install Bicep CLI"
            Write-Host $_
            throw
        }
    }
}

function InstallDSCv3 {
    $dscInstalled = $false
    
    # Check if DSC v3 is already installed
    if (Get-Command dsc -ErrorAction SilentlyContinue) {
        try {
            $dscVersion = & dsc --version 2>&1
            if ($dscVersion -match "3\.") {
                Write-Host "DSC v3 is already installed: $dscVersion"
                $dscInstalled = $true
            }
        }
        catch {
            Write-Host "DSC command found but version check failed"
        }
    }
    
    if (-not $dscInstalled) {
        Write-Host "Installing DSC v3"
        
        try {
            # Create installation directory if it doesn't exist
            if (-not (Test-Path -Path $script:InstallPath)) {
                New-Item -ItemType Directory -Path $script:InstallPath -Force | Out-Null
            }
            
            # Get architecture
            $architecture = Get-WindowsArchitecture
            
            # Map architecture to DSC release naming convention
            $dscArchMap = @{
                "x64" = "x86_64"
                "arm64" = "aarch64"
            }
            
            if (-not $dscArchMap.ContainsKey($architecture)) {
                throw "Unsupported architecture for DSC: $architecture. Only x64 and arm64 are supported."
            }
            
            $dscArch = $dscArchMap[$architecture]
            Write-Host "Using DSC architecture: $dscArch"
            
            $platform = "pc-windows-msvc"
            Write-Host "Platform: $platform"
            
            # Use CDN URL for DSC v3.2.0-preview.9
            $dscVersion = "v3.2.0-preview.9"
            $dscVersionNumber = "3.2.0-preview.9"
            $dscUrl = "https://github.com/PowerShell/DSC/releases/download/$dscVersion/DSC-$dscVersionNumber-$dscArch-$platform.zip"
            
            Write-Host "Downloading DSC $dscVersion from: $dscUrl"
            
            $zipPath = Join-Path -Path $env:TEMP -ChildPath "dsc-v3.zip"
            
            WithRetry -ScriptBlock {
                Invoke-WebRequest -Uri $dscUrl -OutFile $zipPath
            } -Maximum 5 -Delay 100 -FailureNotification "Failed to download DSC v3 from $dscUrl"
            
            Write-Host "Download completed successfully"
            
            # Extract the zip file
            Write-Host "Extracting DSC v3 to $script:InstallPath"
            Expand-Archive -Path $zipPath -DestinationPath $script:InstallPath -Force
            
            Write-Host "DSC runtime downloaded and extracted successfully to $script:InstallPath"
            
            # Clean up zip file
            Remove-Item -Path $zipPath -Force
            
            # Verify installation
            $dscExePath = Join-Path -Path $script:InstallPath -ChildPath "dsc.exe"
            if (Test-Path $dscExePath) {
                $fileSize = (Get-Item $dscExePath).Length
                Write-Host "Installed DSC executable size: $([math]::Round($fileSize / 1MB, 2)) MB"
            }
            else {
                throw "Installation verification failed - dsc.exe not found at $dscExePath"
            }
            
            # Add to PATH
            if ($InstallScope -eq "AllUsers") {
                $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
                if ($currentPath -notlike "*$script:InstallPath*") {
                    [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$script:InstallPath", "Machine")
                }
            }
            else {
                $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
                if ($currentPath -notlike "*$script:InstallPath*") {
                    [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$script:InstallPath", "User")
                }
            }
            
            # Update current session PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            
            Write-Host "Done Installing DSC v3"
            
            # Try to get version
            try {
                $versionOutput = & $dscExePath --version 2>$null
                if ($versionOutput) {
                    Write-Host "DSC version: $versionOutput"
                }
            }
            catch {
                Write-Host "DSC installed but version check failed (this may be normal in some environments)"
            }
        }
        catch {
            Write-Host "Failed to install DSC v3"
            Write-Host $_
            throw
        }
    }
}

# Install all prerequisites
Write-Host "Installing prerequisites..."
InstallPS7
InstallBicepCLI
InstallDSCv3
Write-Host "All prerequisites installed successfully"

# Verify configuration file exists

if (-not (Test-Path -Path $ConfigurationFile)) {
    Write-Host "Error: Configuration file not found: $ConfigurationFile"
    exit 1
}

Write-Host "Applying DSC configuration file: $ConfigurationFile"

# Use the full path to dsc.exe instead of relying on PATH
$dscExePath = Join-Path -Path $script:InstallPath -ChildPath "dsc.exe"

if (-not (Test-Path -Path $dscExePath)) {
    Write-Host "Error: DSC executable not found at: $dscExePath"
    exit 1
}

# Prepare output and error files
$tempOutFile = [System.IO.Path]::GetTempFileName() + ".out.json"
$tempErrFile = [System.IO.Path]::GetTempFileName() + ".err.txt"

try {
    # Build the DSC command using full executable path
    $dscCommand = "`"$dscExePath`" config set --path `"$ConfigurationFile`" --format json"
    
    Write-Host "Applying DSC configuration: $dscCommand"
    
    # Execute DSC configuration using full path
    $output = & cmd /c "$dscCommand 2>&1"
    $exitCode = $LASTEXITCODE
    
    # Write output to file and console
    $output | Out-String | Tee-Object -FilePath $tempOutFile | Write-Host
    
    if ($exitCode -ne 0) {
        Write-Host "DSC configuration failed with exit code: $exitCode"
        exit 1
    }
    
    # Parse and validate output
    try {
        $outputJson = $output | ConvertFrom-Json
        
        # Check for any failures in the results
        if ($outputJson.results) {
            $failures = $outputJson.results | Where-Object { $_.result -and $_.result.afterState -and $_.result.afterState.error }
            if ($failures) {
                Write-Host "There were errors applying the DSC configuration:"
                $failures | ForEach-Object { Write-Host $_.result.afterState.error }
                exit 1
            }
        }
    }
    catch {
        Write-Host "Warning: Could not parse DSC output as JSON. Output may not be in expected format."
        Write-Host $_
    }
    
    Write-Host "DSC configuration applied successfully"
}
catch {
    Write-Host "Error applying DSC configuration"
    Write-Host $_
    exit 1
}
finally {
    # Clean up temp files
    if (Test-Path -Path $tempOutFile) {
        Remove-Item -Path $tempOutFile -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -Path $tempErrFile) {
        Remove-Item -Path $tempErrFile -Force -ErrorAction SilentlyContinue
    }
}

exit 0
