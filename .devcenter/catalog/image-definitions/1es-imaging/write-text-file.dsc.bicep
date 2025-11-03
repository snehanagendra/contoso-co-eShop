targetScope = 'desiredStateConfiguration'

resource writeTextFile 'Microsoft.Windows/WindowsPowerShell@2025-01-07' = {
  name: 'WriteTextFile'
  properties: {
    resources: [
      {
        name: 'HelloFile'
        type: 'PSDesiredStateConfiguration/File'
        properties: {
          DestinationPath: 'C:\\Temp\\hello.txt'
          Contents: 'Hello from DSC Bicep!'
          Ensure: 'Present'
          Type: 'File'
        }
      }
    ]
  }
}
