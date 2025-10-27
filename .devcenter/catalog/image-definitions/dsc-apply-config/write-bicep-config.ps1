$bicepConfigJson = '{"experimentalFeaturesEnabled":{"desiredStateConfiguration":true}}'
$bicepConfigPath = "C:\Workspaces\trydsc\bicepconfig.json"
New-Item -Path "C:\Workspaces\trydsc" -ItemType Directory -Force | Out-Null
Set-Content -Path $bicepConfigPath -Value $bicepConfigJson -Force
