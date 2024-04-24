<#
.SYNOPSIS
#returns information about each mail configured dopmain in M365

.DESCRIPTION
    ensure you Connect-MgGraph -Scopes "Domain.Read.All"  first'
    MgGraph can be installed with install-module microsoft.mggraph
    but takes while so make sure it is not already installed before you try to install again'
    
    ensure you Connect-ExchangeOnline 
    (to get the M365 state of DKIM)'
    Exchange-online module can be installed with Install-Module  ExchangeOnlineManagement '


.EXAMPLE
$i = Get-365DNSInfo 
Get-365DNSInfo |fl
Get-365DNSInfo |export-csv -NoTypeInformation M365Mailsetup.csv

.NOTES


Connect-MgGraph -Scopes "User.Read.All","Group.Read.All","AuditLog.Read.All","Mail.Read","Domain.Read.All"


#>
function Get-365DNSInfo {
    [CmdletBinding()]
    param (
      
    )
    

    write-verbose "about to try and get data from MgGraph "
    $domains = get-mgdomain  | where-object Id -NotLike "*.onmicrosoft.com"   #| Where-Object supportedServices -Contains Email



    foreach ($adomain in $domains) {
        $domainid = $adomain.id
        $ConnfiguredForMail = $adomain.supportedServices -Contains "Email"

        $DNSrecs = Get-MgDomainServiceConfigurationRecord -DomainId $domainid
        $DNS2 = $DNSrecs | Where-Object recordType -eq "Txt" -ErrorAction SilentlyContinue #) -and ($true))# ).AdditionalProperties.mailExchange
        $spfs = ($DNS2 | Select-Object -ExpandProperty AdditionalProperties -ErrorAction SilentlyContinue).text -join ", "

        $spfDNS = (Resolve-DnsName -Name $domainid -Type TXT -ErrorAction SilentlyContinue | Where-Object { $_.Strings -Like "*v=spf1*" }).strings -join ", "
        $MxinDNS = (Resolve-DnsName -Name $domainid -Type MX -ErrorAction SilentlyContinue | where-object Name -eq $domainid).NameExchange -join ", " 
        $DKIMsmxinDNS1 = (Resolve-DnsName -Name smx1._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue) 
        $DKIMsmxinDNS2 = (Resolve-DnsName -Name smx2._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)
        $DKIMM365inDNS1 = (Resolve-DnsName -Name selector1._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)
        $DKIMM365inDNS2 = (Resolve-DnsName -Name selector2._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)

        $MXrecs = (Get-MgDomainServiceConfigurationRecord -DomainId $domainid | Where-Object recordType -eq "Mx").AdditionalProperties.mailExchange -join ", "
     
        try { 
            [string]$M365DKIM = (Get-DkimSigningConfig -Identity $domainid -ErrorAction SilentlyContinue ).Enabled
        }
        catch {
            $er = $error[0]
   
            if ($er.FullyQualifiedErrorId -eq "CommandNotFoundException") {
                write-host "You need to Connect-ExchangeOnline (maybe first Install-Module ExchangeOnlineManagement ) before you can get details about M365 based DKIM configuration" -ForegroundColor Red
                $M365DKIM = "ERROR:  Connect-ExchangeOnline in order to see this parameter"
            }
        }
        if (!$M365DKIM) { $M365DKIM = "Not yet configured: $domainid is not configured for DKIM" }

        $arec = [PSCustomObject]@{
            Name                 = $domainid
            M365_MailEnabled     = $ConnfiguredForMail
            M365_spf             = $spfs
            DNS_spf              = $spfDNS
            M365_mx              = $MXrecs
            DNS_mx               = $MXinDNS
            M365_DKIM_Configured = $M365DKIM
            DNS_DKIM_SMX_1       = "" 
            DNS_DKIM_SMX_2       = ""
            DNS_DKIM_M365_1      = ""
            DNS_DKIM_M365_2      = ""

        }
        if ($DKIMsmxinDNS1  ) { $arec.DNS_DKIM_SMX_1 = "$($DKIMsmxinDNS1.Name),  $($DKIMsmxinDNS1.NameHost)" }
        if ($DKIMsmxinDNS2  ) { $arec.DNS_DKIM_SMX_2 = "$($DKIMsmxinDNS2.Name),  $($DKIMsmxinDNS2.NameHost)" }
        if ($DKIMM365inDNS1 ) { $arec.DNS_DKIM_M365_1 = "$($DKIMM365inDNS1.Name),  $($DKIMM365inDNS1.NameHost)" }
        if ($DKIMM365inDNS2 ) { $arec.DNS_DKIM_M365_2 = "$($DKIMM365inDNS2.Name),  $($DKIMM365inDNS2.NameHost)" }
        $arec


    }
}

function  Get-365licenses{
    [CmdletBinding()]
    param (
       
    )
    


$lic = Get-MgSubscribedSku |Where-Object {($_.AppliesTo -eq "User") -and ($_.CapabilityStatus -eq "Enabled") } |Select-Object SkuPartNumber, @{n="Prepaid";e={$_.prepaidUNits.Enabled}}, ConsumedUnits, SkuId
foreach ($l in $lic){
    if ($l.SkuPartNumber -eq "O365_BUSINESS_ESSENTIALS") {$l.SkuPartNumber ='Microsoft 365 Business Basic'}
    if ($l.SkuPartNumber -eq "O365_BUSINESS_PREMIUM") {$l.SkuPartNumber ='Microsoft 365 Business Standard'}
    if ($l.SkuPartNumber -eq "EXCHANGESTANDARD") {$l.SkuPartNumber ='Exchange Online (Plan 1)'}
    if ($l.SkuPartNumber -eq "STANDARDPACK") {$l.SkuPartNumber ='Office 361 E1'}
}
$lic
}

Write-host 'ensure you Connect-MgGraph   first'
write-host 'MgGraph can be installed with install-module microsoft.mggraph, but takes while so make sure it is not already  installed before you try to install'
write-host 'ensure you Connect-ExchangeOnline  also (to get the M365 state of DKIM)'
write-host 'Exchange-online module can be installed with Install-Module  ExchangeOnlineManagement '

write-Host 'then instead of running this script as you did load it, then run the function'
write-host 'Connect-MgGraph -Scopes "Domain.Read.All","Directory.Read.All","Organization.Read.All","User.Read.All"  ' -ForegroundColor green
write-host 'Connect-ExchangeOnline' -ForegroundColor green
write-Host '. .\func-get-DNSinfo' -ForegroundColor green
write-host 'get-365DNSInfo' -ForegroundColor green
write-host 'get-365Licenses' -ForegroundColor green
