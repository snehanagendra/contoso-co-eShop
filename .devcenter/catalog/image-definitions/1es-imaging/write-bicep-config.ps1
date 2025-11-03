$bicepConfigJson = '{"experimentalFeaturesEnabled":{"desiredStateConfiguration":true}}'
$bicepConfigPath = "C:\ProgramData\Microsoft\DevBoxAgent\ImageDefinitions\1es-imaging-catalog-01\1es-imagingbicepconfig.json"
New-Item -Path "C:\Workspaces\trydsc" -ItemType Directory -Force | Out-Null
Set-Content -Path $bicepConfigPath -Value $bicepConfigJson -Force
