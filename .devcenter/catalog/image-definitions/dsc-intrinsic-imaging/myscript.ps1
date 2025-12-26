param(
    [Parameter(Mandatory=$true)]
    [string]$FileName
)

(New-Item -Path $FileName -ItemType File -Force).FullName