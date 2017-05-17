Configuration vmBootstrap
{
  Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
  Import-DscResource -Module cChoco  
  
  Node localhost
  {
      LocalConfigurationManager
      {
          DebugMode = 'ForceModuleImport'
      }
      cChocoInstaller installChoco
      {
        InstallDir = "c:\choco"
      }
      cChocoPackageInstaller installNginx
      {
        Name        = "nginx-service"
        DependsOn   = "[cChocoInstaller]installChoco"
        Version     = "1.6.2.1"
      }
      Service NginxService
      {
          Name        = "nginx"
          StartupType = "Automatic"
          State       = "Running"
          DependsOn   = "[cChocoPackageInstaller]installNginx"
      } 
  }
} 

vmBootstrap
Start-DscConfiguration .\vmBootstrap -wait -Verbose -force