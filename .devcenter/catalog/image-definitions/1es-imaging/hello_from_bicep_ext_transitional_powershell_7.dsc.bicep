extension dsc
targetScope = 'desiredStateConfiguration'

resource runScript 'Microsoft.DSC.Transitional/PowerShellScript@0.1.0' = {
  setScript: '& "C:\\ProgramData\\Microsoft\\DevBoxAgent\\ImageDefinitions\\1es-imaging-catalog-01\\1es-imaging\\myscript.ps1"'
}
 