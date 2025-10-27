# Find the winget executable in common locations
$wingetPath = Get-ChildItem -Path "C:\Program Files\WindowsApps" -Recurse -Filter winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

if (-not $wingetPath) {
	Write-Error "winget.exe not found on this system. Please ensure winget is installed."
	exit 1
}

# Specify the package ID from the Microsoft Store (update as needed)
$packageId = "DesiredStateConfiguration-Preview"

# Install the package using the full path to winget.exe
& $wingetPath install $packageId --source msstore --accept-package-agreements --accept-source-agreements
