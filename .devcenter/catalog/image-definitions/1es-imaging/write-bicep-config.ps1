$bicepConfigJson = '{"experimentalFeaturesEnabled":{"desiredStateConfiguration":true}}'
$bicepConfigPath = "C:\ProgramData\Microsoft\DevBoxAgent\ImageDefinitions\1es-imaging-catalog-01\1es-imaging\_generated_minimal_bicepconfig.json"

$bicepConfigWithExtensionsJson = '{"experimentalFeaturesEnabled":{"desiredStateConfiguration":true,"moduleExtensionConfigs":true},"extensions":{"dsc":"./out/dsc.tgz"},"implicitExtensions":[]}'
$bicepConfigWithExtensionsPath = "C:\ProgramData\Microsoft\DevBoxAgent\ImageDefinitions\1es-imaging-catalog-01\1es-imaging\_generated_extension_bicepconfig.json"

New-Item -Path (Split-Path $bicepConfigPath -Parent) -ItemType Directory -Force | Out-Null
Set-Content -Path $bicepConfigPath -Value $bicepConfigJson -Force

New-Item -Path (Split-Path $bicepConfigWithExtensionsPath -Parent) -ItemType Directory -Force | Out-Null
Set-Content -Path $bicepConfigWithExtensionsPath -Value $bicepConfigWithExtensionsJson -Force