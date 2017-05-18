Configuration vmBootstrap
{
  Import-DscResource -ModuleName PSDesiredStateConfiguration
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
      Script DisableFirewall 
      {
          GetScript = {
              @{
                  GetScript = $GetScript
                  SetScript = $SetScript
                  TestScript = $TestScript
                  Result = -not('True' -in (Get-NetFirewallProfile -All).Enabled)
              }
          }
  
          SetScript = {
              Set-NetFirewallProfile -All -Enabled False -Verbose
          }
  
          TestScript = {
              $Status = -not('True' -in (Get-NetFirewallProfile -All).Enabled)
              $Status -eq $True
          }
      }
  }
}