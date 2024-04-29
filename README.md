<b>toolsFor365.ps1</b> contains various Commands that can be used to
  - check which DNS  provider is hosting DNS records
  - Checks the configuration of both 365 and SMX (a Mail filtering service in NZ and AU)
  - Configure 365 connectors and rules for operation with SMX mail filtering

either load the script directly using. .\toolsFor365
or rename the script to <b>toolsFor365.psm1</b>
 - then save the script as a module (check programs\powershell\7\ modules in a new folder also called <b>toolsFor365</b> 
 that script can also be saved as a psm1 (module) in a folder with the same name within the PowerShell modules folder - then the functions within the script will work as CMDLETS
the other files in this repo are just notes or workings

Commands can be listed using <b>Get-365Command</b>

<code>
Function        Connect-365                                        0.0        toolsFor365
Function        Connect-JustToExchange                             0.0        toolsFor365
Function        Disable-365SMXOutboundConnector                    0.0        toolsFor365
Function        Disconnect-365                                     0.0        toolsFor365
Function        Enable-365SMXOutboundConnector                     0.0        toolsFor365
Function        Get-365Admins                                      0.0        toolsFor365
Function        Get-365Command                                     0.0        toolsFor365
Function        Get-365DNSInfo                                     0.0        toolsFor365
Function        Get-365Domains                                     0.0        toolsFor365
Function        Get-365licenses                                    0.0        toolsFor365
Function        Get-365RuleOnlyAcceptInboundMailFromSMX            0.0        toolsFor365
Function        Get-365user                                        0.0        toolsFor365
Function        Get-365UserMFAMethods                              0.0        toolsFor365
Function        Get-365Whoami                                      0.0        toolsFor365
Function        New-365RuleOnlyAcceptInboundMailFromSMX            0.0        toolsFor365
Function        New-365SMXInboundConnector                         0.0        toolsFor365
Function        New-365SMXOutboundConnector                        0.0        toolsFor365
Function        Remove-365SMXRuleConnectionFIlter                  0.0        toolsFor365
Function        Resolve-DNSSummary                                 0.0        toolsFor365
</code>


