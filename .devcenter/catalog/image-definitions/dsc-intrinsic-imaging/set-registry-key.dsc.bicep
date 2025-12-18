extension dsc
targetScope = 'desiredStateConfiguration'

resource runScript 'Microsoft.Windows/Registry@1.0.0' = {
  keyPath: 'HKEY_LOCAL_MACHINE\\SOFTWARE\\MyCompany'
  valueName: 'MyTestSetting'
  valueData: {
    String: 'MyTestValue'
  }
}

resource setTaskBarSearchButton 'Microsoft.Windows/Registry@1.0.0' = {
  keyPath: 'HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Search'
  valueName: 'SearchboxTaskbarMode'
  valueData: {
    DWord: 1 //Search box mode (= = no search icon, 1=small icon, 2=large box)
  }
}
