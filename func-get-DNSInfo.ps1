<#
.SYNOPSIS
#returns information about each mail configured dopmain in M365

.DESCRIPTION
    ensure you Connect-MgGraph -Scopes "Domain.Read.All"  first'
    MgGraph can be installed with install-module microsoft.mggraph, but takes while so make sure it is not already  installed before you try to install'
    ensure you Connect-ExchangeOnline  also (to get the M365 state of DKIM)'
    Exchange-online module can be installed with Install-Module  ExchangeOnlineManagement '


.EXAMPLE
An example

.NOTES


Connect-MgGraph -Scopes "User.Read.All","Group.Read.All","AuditLog.Read.All","Mail.Read","Domain.Read.All"


#>
function Get-DNSInfo {
    [CmdletBinding()]
    param (
      
    )
    

    write-verbose "about to try and get data from MgGraph "
   $domains = get-mgdomain | where-object Id -NotLike "*.onmicrosoft.com"



     foreach ($adomain in $domains) {
        # write-host "id = $($adomain.id)"
        $domainid = $adomain.id 

        $DNSrecs = Get-MgDomainServiceConfigurationRecord -DomainId $domainid
        $DNS2 = $DNSrecs | Where-Object recordType -eq "Txt"#) -and ($true))# ).AdditionalProperties.mailExchange
        $spfs = ($DNS2 | Select-Object -ExpandProperty AdditionalProperties).text -join ", "

        $spfDNS = (Resolve-DnsName -Name $domainid -Type TXT | Where-Object { $_.Strings -Like "*v=spf1*" }).strings -join ", "
        $MxinDNS = (Resolve-DnsName -Name $domainid -Type MX | where-object Name -eq $domainid).NameExchange -join ", " 
        $DKIMsmxinDNS1 = (Resolve-DnsName -Name smx1._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue) 
        $DKIMsmxinDNS2 = (Resolve-DnsName -Name smx2._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)
        $DKIMM365inDNS1 = (Resolve-DnsName -Name selector1._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)
        $DKIMM365inDNS2 = (Resolve-DnsName -Name selector2._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)

        $MXrecs = (Get-MgDomainServiceConfigurationRecord -DomainId $domainid | Where-Object recordType -eq "Mx").AdditionalProperties.mailExchange -join ", "
try{
        $M365DKIM = (Get-DkimSigningConfig -Identity $domainid).Enabled
}
catch{
    $er = $error[0]
    if ( $er.Exception.Message -like "*ManagementObjectNotFoundException*") {
         $M365DKIM = "N/A as DKIM or Mail Not Configured" 
          }

    switch ($er.FullyQualifiedErrorId)
    {
        "CommandNotFoundException" { write-host "You need to Install-Module ExchangeOnlineManagement , then Connect-ExchangeOnline before you can get details about M365 based DKIM configuration" -ForegroundColor Red; break}
       
        default {
          
         }
    }
}
        $arec = [PSCustomObject]@{
            Name                 = $domainid
            M365_spf             = $spfs
            DNS_spf              = $spfDNS
            M365_mx              = $MXrecs
            DNS_mx               = $MXinDNS
            M365_DKIM_Configured = $M365DKIM
            DNS_DKIM_SMX_1       = "$($DKIMsmxinDNS1.Name),  $($DKIMsmxinDNS1.NameHost)"
            DNS_DKIM_SMX_2       = "$($DKIMsmxinDNS2.Name),  $($DKIMsmxinDNS2.NameHost)"
            DNS_DKIM_M365_1      = "$($DKIMM365inDNS1.Name),  $($DKIMM365inDNS1.NameHost)"
            DNS_DKIM_M365_2      = "$($DKIMM365inDNS2.Name),  $($DKIMM365inDNS2.NameHost)"

        }
        $arec


    }
}

Write-host 'ensure you Connect-MgGraph   first'
write-host 'MgGraph can be installed with install-module microsoft.mggraph, but takes while so make sure it is not already  installed before you try to install'
write-host 'ensure you Connect-ExchangeOnline  also (to get the M365 state of DKIM)'
write-host 'Exchange-online module can be installed with Install-Module  ExchangeOnlineManagement '

write-Host 'then instead of running this script as you did load it, then run the function'
write-host 'Connect-MgGraph -Scopes "Domain.Read.All" ' -ForegroundColor green
write-host 'Connect-ExchangeOnline' -ForegroundColor green
write-Host '. .\func-get-DNSinfo' -ForegroundColor green
write-host 'get-DNSinfo' -ForegroundColor green
