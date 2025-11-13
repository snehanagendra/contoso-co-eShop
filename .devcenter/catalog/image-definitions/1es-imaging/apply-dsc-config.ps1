param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to the DSC configuration file")]
    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "Configuration file not found: $_"
        }
        return $true
    })]
    [string]$ConfigFile
)

# Find the DSC executable (dsc.exe) in common locations
$dscPath = Get-ChildItem -Path "C:\ProgramData\Microsoft\DevBoxAgent\1ES" -Recurse -Filter dsc.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

if (-not $dscPath) {
	Write-Error "dsc.exe not found on this system. Please ensure DSC is installed."
	exit 1
}

# Apply the DSC configuration using the full path to dsc.exe and the configuration file
Write-Host "Applying DSC configuration: $ConfigFile"
Write-Host "Using DSC executable: $dscPath"

try {
    # Capture both stdout and stderr
    $result = & $dscPath config set --file $ConfigFile -o pretty-json 2>&1
    
    # Check the exit code
    if ($LASTEXITCODE -eq 0) {
        Write-Host "DSC configuration applied successfully!" -ForegroundColor Green
        Write-Host "Output:" -ForegroundColor Cyan
        Write-Host $result
    } else {
        Write-Error "DSC configuration failed with exit code: $LASTEXITCODE"
        Write-Host "Error Output:" -ForegroundColor Red
        Write-Host $result
        exit $LASTEXITCODE
    }
}
catch {
    Write-Error "Failed to execute DSC command: $_"
    Write-Host "Exception Details:" -ForegroundColor Red
    Write-Host "  - Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "  - Error Message: $($_.Exception.Message)"
    Write-Host "  - Stack Trace: $($_.ScriptStackTrace)"
    exit 1
}
