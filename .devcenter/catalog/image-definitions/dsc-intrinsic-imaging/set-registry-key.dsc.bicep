extension dsc
targetScope = 'desiredStateConfiguration'

resource runScript 'Microsoft.Windows/Registry@1.0.0' = {
  keyPath: 'HKEY_LOCAL_MACHINE\\SOFTWARE\\MyCompany'
  valueName: 'MyTestSetting'
  valueData: {
    String: 'MyTestValue'
  }
}

