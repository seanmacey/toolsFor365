<#
.SYNOPSIS
  returns information about each mail configured dopmain in M365
.DESCRIPTION
    ensure you Connect-MgGraph -Scopes "Domain.Read.All"  first
    MgGraph can be installed with install-module microsoft.mggraph
    but takes while so make sure it is not already installed before you try to install again
    
    [Optional] to retrieve DKIM settiings from 365
       Connect-ExchangeOnline 
       Exchange-online module can be installed with Install-Module  ExchangeOnlineManagement 

    requires at least
    Connect-MgGraph -Scopes "AuditLog.Read.All","Mail.Read","Domain.Read.All"
   
    or try
    Connect-MgGraph -Scopes "User.Read.All","Group.Read.All","AuditLog.Read.All","Mail.Read","Domain.Read.All","RoleManagement.Read.All","Policy.Read.All","Directory.Read.All","Organization.Read.All"
.EXAMPLE
$i = Get-365DNSInfo 
Get-365DNSInfo |fl
Get-365DNSInfo |export-csv -NoTypeInformation M365Mailsetup.csv
.NOTES
#>
function Get-365DNSInfo {
    [CmdletBinding()]
    param (
        $Domain 
    )
 
    write-verbose "about to try and get data from MgGraph "
    if ($Domain) {
        $domains = get-mgdomain  | where-object Id -eq $domain
    }
    else {
        $domains = get-mgdomain  | where-object Id -NotLike "*.onmicrosoft.com"   #| Where-Object supportedServices -Contains Email
    }
    
    foreach ($adomain in $domains) {
        $domainid = $adomain.id
        $ConnfiguredForMail = $adomain.supportedServices -Contains "Email"

        $DNSrecs = Get-MgDomainServiceConfigurationRecord -DomainId $domainid
        #$DNS2 = $DNSrecs | Where-Object recordType -eq "Txt"  #) -and ($true))# ).AdditionalProperties.mailExchange
        $spfs = ($DNSrecs | Where-Object recordType -eq "Txt"  | Select-Object -ExpandProperty AdditionalProperties -ErrorAction SilentlyContinue).text -join ", "
        $MXrecs = ($DNSrecs | Where-Object recordType -eq "Mx").AdditionalProperties.mailExchange -join ", "

        $spfDNS = (Resolve-DnsName -Name $domainid -Type TXT -ErrorAction SilentlyContinue | Where-Object { $_.Strings -Like "*v=spf1*" }).strings -join ", "
 

        $MxinDNS = (Resolve-DnsName -Name $domainid -Type MX -ErrorAction SilentlyContinue | where-object Name -eq $domainid).NameExchange -join ", " 
        $DKIMsmxinDNS1 = (Resolve-DnsName -Name smx1._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue) 
        $DKIMsmxinDNS2 = (Resolve-DnsName -Name smx2._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)
        $DKIMM365inDNS1 = (Resolve-DnsName -Name selector1._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)
        $DKIMM365inDNS2 = (Resolve-DnsName -Name selector2._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)

        #$MXrecs = (Get-MgDomainServiceConfigurationRecord -DomainId $domainid | Where-Object recordType -eq "Mx").AdditionalProperties.mailExchange -join ", "
     
      
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

<#
.SYNOPSIS
returns a summary of all MS subscription / license that are configured

.DESCRIPTION
 returns a decription of subscriptions used within the account, 
 AND it also shows the amount of available licenses left in each subscription

 requires at least
 Connect-MgGraph -Scopes "Organization.Read.All"

.EXAMPLE
Get-365licenses

.NOTES

#>
function  Get-365licenses {
    [CmdletBinding()]
    param (
       
    )
    


    $lic = Get-MgSubscribedSku | Where-Object { ($_.AppliesTo -eq "User") -and ($_.CapabilityStatus -eq "Enabled") } | Select-Object SkuPartNumber, @{n = "Prepaid"; e = { $_.prepaidUNits.Enabled } }, ConsumedUnits, SkuId
    foreach ($l in $lic) {
        if ($l.SkuPartNumber -eq "O365_BUSINESS_ESSENTIALS") { $l.SkuPartNumber = 'Microsoft 365 Business Basic' }
        if ($l.SkuPartNumber -eq "O365_BUSINESS_PREMIUM") { $l.SkuPartNumber = 'Microsoft 365 Business Standard' }
        if ($l.SkuPartNumber -eq "EXCHANGESTANDARD") { $l.SkuPartNumber = 'Exchange Online (Plan 1)' }
        if ($l.SkuPartNumber -eq "STANDARDPACK") { $l.SkuPartNumber = 'Office 361 E1' }
        $l | Add-Member -NotePropertyName "avail" -NotePropertyValue ([int]($l.Prepaid) - [int]($l.ConsumedUnits) ) 
    }
    $lic
}

<#
.SYNOPSIS
get details about users within a 365 account

.DESCRIPTION
gets information about all users in a 365 account
provides a list of licenses used by each user - 

Collections such as Licenses, email-alias' signInActivity are in JSON format (so you can export output of this function to CSV)

Requires at least the following rights
Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All"
Or try
Connect-MgGraph -Scopes "User.Read.All","Group.Read.All","AuditLog.Read.All","Mail.Read","Domain.Read.All","RoleManagement.Read.All","Policy.Read.All","Directory.Read.All","Organization.Read.All"

If you want to see mail statistics - then also
connect-exchangeonline

.PARAMETER userPrincipalName
allows you to retrieve data about just ONE user

.EXAMPLE
get-365user

get-365user -userPrincipalName info@hinterlandtours.co.nz

get-365user |export-csv -NoTypeInformation listOfUsers.csv

$variable = get-365user

.NOTES
General notes
#>
function  Get-365user {
    [CmdletBinding()]
    param(
        [string]$userPrincipalName
    )

    $ConnectedtoExchange = (get-365Whoami -DontElaborate).ExhangeOnline


    $filterfor = ""
    if ($userPrincipalName) {
        $filterfor = '&$filter=userPrincipalName eq '
        $filterfor = "$filterfor'$userPrincipalName'"
    }
    $needsB2C = $null
    $basicpoll = 'https://graph.microsoft.com/v1.0/users?$select=id,displayName,userPrincipalName,Mail,proxyAddresses,licenseAssignmentStates,accountEnabled,lastPasswordChangeDateTime,onPremisesSyncEnabled,onPremisesDomainName,onPremisesDistinguishedName,onPremisesSamAccountName,userType'
        
    try {
        $result = Invoke-MgGraphRequest -Method GET "$basicpoll,signInActivity$filterfor" -OutputType PSObject
        $result.value | Add-Member -NotePropertyName get_errors -NotePropertyValue "No errors getting this information from M365"

    }
    catch {
        $er = $error[0]
        $needsB2C = $er.ErrorDetails -like "*Neither tenant is B2C or tenant doesn't have premium license*"
        if ($needsB2C) {
            $result = Invoke-MgGraphRequest -Method GET "$basicpoll$filterfor" -OutputType PSObject
            $result.value | Add-Member -NotePropertyName signInActivity -NotePropertyValue ""
            $result.value | Add-Member -NotePropertyName get_errors -NotePropertyValue "Can not get signInActivity, since tenant is neither B2C or has premium license"
        }
    }
    if ($result) {
        $users = $result.value
        if ($ConnectedtoExchange ){
            $users |Add-Member -NotePropertyName "MailSize" -NotePropertyValue ""
            $users |Add-Member -NotePropertyName "MailSizeLimit" -NotePropertyValue ""
            $users |Add-Member -NotePropertyName "MailBoxType" -NotePropertyValue ""
            $users |Add-Member -NotePropertyName "LastUserMailAction" -NotePropertyValue ""
        }
        $lic = Get-365licenses
        foreach ($user in $users) {
            $userskus = @()
            $user.proxyAddresses = ($user.proxyAddresses | Where-Object { $_ -like "SMTP*" }) -replace ("SMTP:", "") | ConvertTo-Json

            foreach ($userlic in $user.licenseAssignmentStates ) {
                $alic = ($lic | Where-Object skuid -eq $userlic.skuid).SkuPartNumber #?? $userlic.skuid
                if (!$alic) { $alic = $userlic.skuid }
                if ($userlic.state -ne "Active") { $alic = "$alic <$($userlic.state)>" }
                $userskus += $alic
            }
            $user.licenseAssignmentStates = $userskus | ConvertTo-Json

            if ($user.signInActivity) { $user.signInActivity = $user.signInActivity | Select-Object lastSignInDateTime, lastNonInteractiveSignInDateTime | ConvertTo-Json }
            write-verbose " this next section checks exchangeonline"
            if ($ConnectedtoExchange -and $user.mail) {
                     $maildetail = Get-MailboxStatistics -Identity $user.mail -ErrorAction SilentlyContinue |Select-Object DisplayName, TotalItemSize, SystemMessageSizeShutoffQuota, MailboxTypeDetail,LastUserActionTime -ErrorAction SilentlyContinue
                    if ($maildetail.MailboxTypeDetail){
                    $user.MailSize = $maildetail.TotalItemSize
                    $user.MailSizeLimit= $maildetail.SystemMessageSizeShutoffQuota
                    $user.MailBoxType = $maildetail.MailboxTypeDetail
                    $user.LastUserMailAction = $maildetail.LastUserActionTime
                    }
                    else {
                        <# Action when all if and elseif conditions are false #>
                        $user.mail =""
                        $user.proxyAddresses ="" 
                    }
            }       
        }
        $users
        if (!$ConnectedtoExchange){
            write-host "if you want to see 365 Mailbox statistics, then rerun this AFTER first connect-exchangeOnline" -ForegroundColor green
        }
    }
}

<#
.SYNOPSIS
this checks MgGraph to identify whichj UserPrincipalName you are connected with
this also checks AZureAD and ExhangeOnline : But NOte 

.DESCRIPTION
this checks MgGraph to identify whichj UserPrincipalName you are connected with

it also checks AZureAD and and ExchnageOnlins
* Both AZureAD and ExhangeOnline modules are being deprecated in 2024 
* currently the get-365DNSInfo function needs to also use the exchangeonlinemodule
  - but only if you need to check the DFKIM status within 365 - else the function will still run and show blanks in that property

.EXAMPLE
get-365Whoami

.NOTES

#>
function get-365Whoami {
    [CmdletBinding()]
    param(
        [switch]$DontElaborate
    )
    $uExchange = ""
    $uAZure = ""
    $uMgGraph = ""
    
    try {
        $result = Invoke-MgGraphRequest -Method GET 'https://graph.microsoft.com/v1.0/me?$select=userPrincipalName' -OutputType PSObject 
        $uMgGraph = $result.userPrincipalName     
    }
    catch { }
    try {
        $result = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if ($result) {
            $uExchange = "$($result.UserPrincipalName)  <$($result.State)>"
        }
    }
    catch { }
    try {
        $result = Get-AzureADCurrentSessionInfo
        $uAzure = $result.Account.ID
    }
    catch { }

    [PSCustomObject]@{
        MgGraph       = $uMgGraph
        ExhangeOnline = $uExchange
        AZureAD       = $uAzure
    }

    if ($uMgGraph -and ($DontElaborate -ne $true)) {
        $mgCOntext = Get-MgContext
        write-host "MgGraph Scopes are"
        write-host "$($mgCOntext.scopes |ConvertTo-Json)"
    }
}

<#
.SYNOPSIS
Gets a sumarised list of domains

.DESCRIPTION
Gets a sumarised list of domains
    requires at least

    Connect-MgGraph -Scopes "Domain.Read.All"
    or try Connect-MgGraph -Scopes "User.Read.All","Group.Read.All","AuditLog.Read.All","Mail.Read","Domain.Read.All","RoleManagement.Read.All","Policy.Read.All","Directory.Read.All","Organization.Read.All"

.EXAMPLE
get-365Domains 

.NOTES
this is a very simple summary of get-mgdomain 
#>
function get-365Domains {
    [CmdletBinding()]
    param (
        
    )
    #get list of domains in M365
    $domains = get-mgdomain | Select-Object id, isdefault, isverified, supportedServices
    return $domains

}

Write-host 'ensure you Connect-MgGraph   first'
write-host 'MgGraph can be installed with install-module microsoft.mggraph, but takes while so make sure it is not already  installed before you try to install'
write-host 'ensure you Connect-ExchangeOnline  also (to get the M365 state of DKIM)'
write-host 'Exchange-online module can be installed with Install-Module  ExchangeOnlineManagement '

write-Host 'then instead of running this script as you did load it, then run the function'
write-host 'Connect-MgGraph -Scopes "User.Read.All","Group.Read.All","AuditLog.Read.All","Mail.Read","Domain.Read.All","RoleManagement.Read.All","Policy.Read.All","Directory.Read.All","Organization.Read.All"  ' -ForegroundColor green
write-host 'Connect-ExchangeOnline' -ForegroundColor green
write-Host '. .\func-get-DNSinfo' -ForegroundColor green
write-host 'get-365DNSInfo' -ForegroundColor green
write-host 'get-365Licenses' -ForegroundColor green
write-host 'get-365User' -ForegroundColor green
write-host 'get-365whoami' -ForegroundColor green
write-host 'get-365Domains' -ForegroundColor green
