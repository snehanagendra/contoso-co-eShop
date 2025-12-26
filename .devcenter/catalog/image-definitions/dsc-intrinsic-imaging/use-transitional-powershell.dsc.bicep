extension dsc
targetScope = 'desiredStateConfiguration'

resource runScriptResourceFile 'Microsoft.DSC.Transitional/PowerShellScript@0.1.0' = {
  setScript: '& "C:\\ProgramData\\Microsoft\\DevBoxAgent\\ImageDefinitions\\dsc-intrinsic-imaging-catalog-01\\dsc-intrinsic-imaging\\myscript.ps1" -FileName "C:\\Temp\\from_resource_file.txt"'
}
 