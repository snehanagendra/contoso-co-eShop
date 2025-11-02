# Find the DSC executable (dsc.exe) in common locations
$dscPath = Get-ChildItem -Path "C:\ProgramData\Microsoft\DevBoxAgent\1ES" -Recurse -Filter dsc.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

if (-not $dscPath) {
	Write-Error "dsc.exe not found on this system. Please ensure DSC is installed."
	exit 1
}

# Path to the DSC JSON configuration file (update as needed)
$jsonPath = "C:\ProgramData\Microsoft\DevBoxAgent\ImageDefinitions\1es-imaging-catalog-01\1es-imaging\install-insomnia.dsc.json"

if (-not (Test-Path $jsonPath)) {
	Write-Error "DSC configuration JSON file not found: $jsonPath"
	exit 1
}

# Apply the DSC configuration using the full path to dsc.exe and the JSON file
& $dscPath config set --file $jsonPath -o pretty-json
