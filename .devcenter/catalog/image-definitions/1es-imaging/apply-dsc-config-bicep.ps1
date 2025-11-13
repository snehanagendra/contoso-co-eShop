# Find the DSC executable (dsc.exe) in common locations
$dscPath = Get-ChildItem -Path "C:\ProgramData\Microsoft\DevBoxAgent\1ES" -Recurse -Filter dsc.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

if (-not $dscPath) {
	Write-Error "dsc.exe not found on this system. Please ensure DSC is installed."
	exit 1
}

# Path to the DSC BICEP configuration file (update as needed)
$bicepPath = "C:\ProgramData\Microsoft\DevBoxAgent\ImageDefinitions\1es-imaging-catalog-01\1es-imaging\hello_from_bicep_ext_transitional_powershell_7.dsc.bicep"

if (-not (Test-Path $bicepPath)) {
	Write-Error "DSC configuration BICEP file not found: $bicepPath"
	exit 1
}

# Apply the DSC configuration using the full path to dsc.exe and the BICEP file
& $dscPath config set --file $bicepPath -o pretty-json
