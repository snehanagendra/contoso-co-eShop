#Requires -Version 5.1
<#
.SYNOPSIS
    Builds DSC Bicep files to JSON using the installed Bicep CLI.

.DESCRIPTION
    This script uses the Bicep CLI installed at C:\ProgramData\Microsoft\DevBoxAgent\1ES
    to build the specified DSC Bicep file to JSON format.

.EXAMPLE
    .\build-dsc-bicep.ps1
    Builds the DSC Bicep file to JSON
#>

# Set error action preference
$ErrorActionPreference = "Stop"

# Configuration
$BicepExecutable = "C:\ProgramData\Microsoft\DevBoxAgent\1ES\bicep.exe"
$BicepFile = "C:\ProgramData\Microsoft\DevBoxAgent\ImageDefinitions\1es-imaging-catalog-01\1es-imaging\write-text-file.dsc.bicep"

# Main execution
try {
    Write-Host "Starting DSC Bicep build process..."
    
    # Verify Bicep executable exists
    if (-not (Test-Path $BicepExecutable)) {
        throw "Bicep executable not found at: $BicepExecutable"
    }
    
    Write-Host "Found Bicep executable at: $BicepExecutable"
    
    # Verify Bicep file exists
    if (-not (Test-Path $BicepFile)) {
        throw "Bicep file not found at: $BicepFile"
    }
    
    Write-Host "Found Bicep file at: $BicepFile"
    
    # Get Bicep version
    try {
        $versionOutput = & $BicepExecutable --version 2>$null
        if ($versionOutput) {
            Write-Host "Using Bicep version: $versionOutput"
        }
    }
    catch {
        Write-Host "Could not determine Bicep version (proceeding anyway)"
    }
    
    # Build the Bicep file
    Write-Host "Building Bicep file to JSON..."
    Write-Host "Source: $BicepFile"
    Write-Host "Output: Using default naming convention"
    
    # Execute bicep build command
    $buildArgs = @("build", $BicepFile)
    Write-Host "Executing: $BicepExecutable $($buildArgs -join ' ')"
    
    & $BicepExecutable @buildArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "Bicep build failed with exit code: $LASTEXITCODE"
    }
    
    # Determine expected output file (Bicep default naming)
    $expectedOutputFile = $BicepFile -replace '\.bicep$', '.json'
    
    # Verify output file was created
    if (Test-Path $expectedOutputFile) {
        $outputSize = (Get-Item $expectedOutputFile).Length
        Write-Host "Build completed successfully!"
        Write-Host "Output file size: $([math]::Round($outputSize / 1KB, 2)) KB"
        Write-Host "Output location: $expectedOutputFile"
    } else {
        throw "Build completed but output file was not created at: $expectedOutputFile"
    }
}
catch {
    Write-Host "Build failed with error: $_"
    Write-Host "Error details:"
    Write-Host "  - Script Name: $($MyInvocation.MyCommand.Name)"
    Write-Host "  - Error Line: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "  - Error Position: $($_.InvocationInfo.PositionMessage)"
    Write-Host "  - Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "  - Bicep Executable: $BicepExecutable"
    Write-Host "  - Bicep File: $BicepFile"
    if ($LASTEXITCODE) {
        Write-Host "  - Exit Code: $LASTEXITCODE"
    }
    Write-Host "Build process terminated due to error."
    exit 1
}
