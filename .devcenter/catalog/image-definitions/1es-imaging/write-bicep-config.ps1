$bicepConfigJson = '{"experimentalFeaturesEnabled":{"desiredStateConfiguration":true}}'
$bicepConfigPath = "C:\ProgramData\Microsoft\DevBoxAgent\ImageDefinitions\1es-imaging-catalog-01\1es-imaging\bicepconfig.json"
New-Item -Path (Split-Path $bicepConfigPath -Parent) -ItemType Directory -Force | Out-Null
Set-Content -Path $bicepConfigPath -Value $bicepConfigJson -Force
