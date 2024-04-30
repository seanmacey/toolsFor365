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
.PARAMETER Domain
Optional: and if used will return information ONLY on the specific Name (and only if it is also within the 365 Account)
the FQN of the domain (e.g. imatec.co.nz)

    .EXAMPLE
$i = Get-365DNSInfo 
Get-365DNSInfo |fl
Get-365DNSInfo |export-csv -NoTypeInformation M365Mailsetup.csv

get-365DNSInfo -Domain imatec.co.nz
Connect-365: you are connected to MgGraph with userPrincipleName = sean.macey@imatec.co.nz

Name                 : imatec.co.nz
M365_MailEnabled     : True
SOA                  : 1stDomains
M365_spf             : v=spf1 include:spf.protection.outlook.com -all
DNS_spf              : v=spf1 include:spf.protection.outlook.com include:spf.nz.smxemail.com ip4:125.236.231.136 include:autotask.net ~all
M365_mx              : imatec-co-nz.mail.protection.outlook.com
DNS_mx               : mx1.nz.smxemail.com, mx2.nz.smxemail.com
M365_DKIM_Configured : True
DNS_DKIM_SMX         : smx1.imatec-co-nz-694f55df.dkim.smxemail.com, smx2.imatec-co-nz-694f55df.dkim.smxemail.com
DNS_DKIM_M365        : selector1-imatec-co-nz._domainkey.kissitnz.onmicrosoft.com, selector2-imatec-co-nz._domainkey.kissitnz.onmicrosoft.com
#>
function Get-365DNSInfo {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName)]
    [Alias("Name")]
    [Alias("id")]
    [string[]]$Domain 
  )
  begin {
    Connect-365
    # if (!(get-365whoami).)  
    if (!(get-365Whoami -checkIfSignedInTo Exchange)) {
      write-host "You need to Connect-ExchangeOnline  before you can get details about M365 based DKIM configuration" -ForegroundColor Red
      Connect-JustToExchange -UserPrincipalName (get-365Whoami -checkIfSignedInTo MgGraph)
    }
  }

  Process {
    write-verbose "about to try and get data from MgGraph "
    if ($Domain) {
      $domains = get-mgdomain  | where-object Id -in $domain
    }
    else {
      $domains = get-mgdomain  | where-object Id -NotLike "*.onmicrosoft.com"   #| Where-Object supportedServices -Contains Email
    }



    
    foreach ($adomain in $domains) {
      $domainid = $adomain.id
      $ConnfiguredForMail = $adomain.supportedServices -Contains "Email"

      $DNSrecs = Get-MgDomainServiceConfigurationRecord -DomainId $domainid
      $spfs = ($DNSrecs | Where-Object recordType -eq "Txt"  | Select-Object -ExpandProperty AdditionalProperties -ErrorAction SilentlyContinue).text -join ", "
      $MXrecs = ($DNSrecs | Where-Object recordType -eq "Mx").AdditionalProperties.mailExchange -join ", "

      # $spfDNS = (Resolve-DnsName -Name $domainid -Type TXT -ErrorAction SilentlyContinue | Where-Object { $_.Strings -Like "*v=spf1*" }).strings -join ", "
      # $MxinDNS = (Resolve-DnsName -Name $domainid -Type MX -ErrorAction SilentlyContinue | where-object Name -eq $domainid).NameExchange -join ", " 

      # $DKIMsmxinDNS1 = (Resolve-DnsName -Name smx1._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue) 
      # $DKIMsmxinDNS2 = (Resolve-DnsName -Name smx2._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)
      # $DKIMM365inDNS1 = (Resolve-DnsName -Name selector1._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)
      # $DKIMM365inDNS2 = (Resolve-DnsName -Name selector2._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)
    
      [string]$M365DKIM = (Get-DkimSigningConfig -Identity $domainid -ErrorAction SilentlyContinue ).Enabled

      $resolvedDNS = Resolve-DNSSummary -Domain $domainid


      if (!$M365DKIM) { $M365DKIM = "Not yet configured: $domainid is not configured for DKIM" }

      $arec = [PSCustomObject]@{
        Name                 = $domainid
        M365_MailEnabled     = $ConnfiguredForMail
        SOA                  = $resolvedDNS.Provider
        M365_spf             = $spfs
        DNS_spf              = $resolvedDNS.SPF #$spfDNS
        M365_mx              = $MXrecs
        DNS_mx               = $resolvedDNS.MX #$MXinDNS
        M365_DKIM_Configured = $M365DKIM
        DNS_DKIM_SMX         = $resolvedDNS.DKIM_SMX
        DNS_DKIM_M365        = $resolvedDNS.DKIM_365

      }
      # if ($DKIMsmxinDNS1  ) { $arec.DNS_DKIM_SMX_1 = "$($DKIMsmxinDNS1.Name),  $($DKIMsmxinDNS1.NameHost)" }
      # if ($DKIMsmxinDNS2  ) { $arec.DNS_DKIM_SMX_2 = "$($DKIMsmxinDNS2.Name),  $($DKIMsmxinDNS2.NameHost)" }
      # if ($DKIMM365inDNS1 ) { $arec.DNS_DKIM_M365_1 = "$($DKIMM365inDNS1.Name),  $($DKIMM365inDNS1.NameHost)" }
      # if ($DKIMM365inDNS2 ) { $arec.DNS_DKIM_M365_2 = "$($DKIMM365inDNS2.Name),  $($DKIMM365inDNS2.NameHost)" }
      $arec
    }
  }
  end {}
}

<#
.SYNOPSIS
Query DNS for a specific Domain - return a SUmmary

.DESCRIPTION
Query DNS for a specific Domain - return a SUmmary
provides summary of MX, HOme IP (usually also WWW), www, SPF and identifies if DKIM is configured for our commonly used systems

.PARAMETER Domain
has an alias of Name
has an alias of id
the FQN (Domain) that needs to be resolve
The MUST be the DOMAIN suffix only, do not include the hostname
i.e use imatec.co.nz , and not wwww.imatec.co.nz
 
.EXAMPLE
Resolve-DNSSummary -Domain imatec.co.nz   
Resolve-DNSSummary -Name imatec.co.nz       
#>
function Resolve-DNSSummary {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName)]
    [Alias("Name")]
    [Alias("id")]
    [string[]]
    $Domain
  
  )
  begin {}
  Process {
    foreach ($adomain in $Domain) {

  
      $SOA = (Resolve-DnsName -Name $adomain -Type SOA -ErrorAction SilentlyContinue).PrimaryServer
      $spfDNS = (Resolve-DnsName -Name $adomain -Type TXT -ErrorAction SilentlyContinue | Where-Object { $_.Strings -Like "*v=spf1*" }).strings -join ", "
      $MxinDNS = (Resolve-DnsName -Name $adomain -Type MX -ErrorAction SilentlyContinue | where-object Name -eq $adomain).NameExchange -join ", " 
      $dnsroot = (Resolve-DnsName -Name $adomain -ErrorAction SilentlyContinue | where-object Name -eq $adomain).IP4Address -join ", " 
      $www = (Resolve-DnsName -Name www.$adomain -ErrorAction SilentlyContinue | where-object Name -eq $adomain).IP4Address -join ", " 


      $arec = [PSCustomObject]@{
        Name     = $adomain
        Home     = $dnsroot
        www      = $www
        Provider = $SOA
        MX       = $MxinDNS
        DKIM_SMX = ""
        DKIM_365 = ""
        SPF_SMX  = ""
        SPF_365  = ""
        SPF      = $spfDNS
      }

      switch ($SOA) {
        { $SOA -Like "*1stDomains*" } { $arec.Provider = "1stDomains" }
        { $SOA -Like "*cms-tool*" } { $arec.Provider = "WebsiteWorld" }
        { $SOA -Like "*cloudflare*" } { $arec.Provider = "CloudFlare" }
        { $SOA -Like "*crazydomains*" } { $arec.Provider = "CrazyDomains" }
        { $SOA -Like "*domaincontrol*" } { $arec.Provider = "Bluehost.com (domaincontrol.com)" }
        { $SOA -Like "*cpanel.com*" } { $arec.Provider = "Domainz.co.nz (server-cpanel.com)" }
        { $SOA -Like "*onlydomains.com*" } { $arec.Provider = "OnlyDomains" }
        { $SOA -Like "*omninet.co.nz*" } { $arec.Provider = "OmniNet" }
        { $SOA -Like "*nameserverz.com*" } { $arec.Provider = "RimuHost NZ (nameserverz.com)" }
      }

      if ($spfDNS -Like "*include:spf.nz.smxemail.com*all") { $arec.SPF_SMX = $true }
      if ($spfDNS -Like "*include:spf.protection.outlook.com*all") { $arec.SPF_365 = $true }

      $DKIMsmxinDNS1 = (Resolve-DnsName -Name smx1._domainkey.$adomain -Type CNAME -ErrorAction SilentlyContinue) | Select-Object  NameHost
      $DKIMsmxinDNS2 = (Resolve-DnsName -Name smx2._domainkey.$adomain -Type CNAME -ErrorAction SilentlyContinue) | Select-Object  NameHost
      if ($DKIMsmxinDNS1 -or $DKIMsmxinDNS2) {
        # $arec.DKIM_SMX = @($DKIMsmxinDNS1,$DKIMsmxinDNS2) |ConvertTo-Json -Compress
        $arec.DKIM_SMX = "$($DKIMsmxinDNS1.NameHost), $($DKIMsmxinDNS2.nameHost)"
      }

      $DKIMM365inDNS1 = (Resolve-DnsName -Name selector1._domainkey.$adomain -Type CNAME -ErrorAction SilentlyContinue) | Select-Object  NameHost
      $DKIMM365inDNS2 = (Resolve-DnsName -Name selector2._domainkey.$adomain -Type CNAME -ErrorAction SilentlyContinue) | Select-Object  NameHost
      if ($DKIMM365inDNS1 -or $DKIMM365inDNS2) {
        $arec.DKIM_365 = "$($DKIMM365inDNS1.NameHost), $($DKIMM365inDNS2.nameHost)" #) |ConvertTo-Json -Compress
      }
      if ($arec.Home) { $arec }
      else {
        write-host "Resoive-DNSSummary: Did not records for domain: adomain" -ForegroundColor Red
      }
    }
  }
  end {

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
#>
function  Get-365licenses {
  [CmdletBinding()]
  param (
       
  )
  Connect-365 -SilentifAlreadyConnected


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
#>
function  Get-365user {
  [CmdletBinding()]
  param(
    #[Parameter(Mandatory = $true, ParameterSetName = 'Name', ValueFromPipeline = $true, ValueFromPipelineByPropertyName)]
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName)]
    [alias('Name')]
    [string[]]$userPrincipalName,

#    [Parameter(Mandatory = $true, ParameterSetName = 'id', ValueFromPipeline = $true, ValueFromPipelineByPropertyName)]
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName)]
    [alias('id')]
    [string]$userid,

    [switch]$basicInfoOnly,
    [switch]$ShowMFA,
    [switch]$showMailBox,
    [switch]$EnablebUsersOnly
  )

  begin {
    Connect-365 -SilentifAlreadyConnected
    if ($showMailBox) {
      Connect-JustToExchange
      Connect-JustToExchange -UserPrincipalName (get-365Whoami -checkIfSignedInTo MgGraph)
    }
  }

  process {

  

    $filterfor = ""
    if ($userPrincipalName) {
      # $filterfor = '&$filter=userPrincipalName eq '
      # $filterfor = "$filterfor'$userPrincipalName'"
      $filterfor = '&$filter=userPrincipalName in '
      $filterfor = "$filterfor('$($userPrincipalName -join ("','"))')"
      write-debug "Get-365User: filter Name $filterfor"
    
    }
    if ($userid) {
      # $filterfor = '&$filter=id eq '
      # $filterfor = "$filterfor'$userid'"
      $filterfor = '&$filter=id in '
      $filterfor = "$filterfor('$($userid -join ("','"))')"
    }



    if ($basicInfoOnly) {
      $basicpoll = 'https://graph.microsoft.com/v1.0/users?$select=id,displayName,userPrincipalName,Mail,accountEnabled,onPremisesSamAccountName,userType'
      $result = Invoke-MgGraphRequest -Method GET "$basicpoll$filterfor" -OutputType PSObject
      if ($result){
        if ($EnablebUsersOnly -and $result.value) {$result.value = $result.value |Where-Object accountEnabled -eq "True"}
        $result.value
      }
      
      return
    }

    # $ConnectedtoExchange = (get-365Whoami -DontElaborate).ExhangeOnline
    $needsB2C = $null
    $basicpoll = 'https://graph.microsoft.com/v1.0/users?$select=id,displayName,userPrincipalName,Mail,proxyAddresses,licenseAssignmentStates,accountEnabled,lastPasswordChangeDateTime,onPremisesSyncEnabled,onPremisesDomainName,onPremisesDistinguishedName,onPremisesSamAccountName,userType'
        
    try {
      $result = Invoke-MgGraphRequest -Method GET "$basicpoll,signInActivity$filterfor" -OutputType PSObject
      $result.value | Add-Member -NotePropertyName get_errors -NotePropertyValue "No errors getting this information from M365"

    }
    catch {
      $er = $error[0]
      $needsB2C = $er.ErrorDetails -like "*tenant is neither B2C nor has premium license*"
     # if ($needsB2C) {
      #  write-host "HELL $basicpoll$filterfor"
        $result = Invoke-MgGraphRequest -Method GET "$basicpoll$filterfor" -OutputType PSObject
        $result.value | Add-Member -NotePropertyName signInActivity -NotePropertyValue ""
        $result.value | Add-Member -NotePropertyName get_errors -NotePropertyValue "Can not get signInActivity, since tenant is neither B2C or has premium license"
     # }
    }

    if ($result) {
      $users = $result.value
      if ($EnablebUsersOnly -and $users) {$users = $users|Where-Object accountEnabled -eq "True"}
      if ($showMailBox) {
        $users | Add-Member -NotePropertyName "MailSize" -NotePropertyValue ""
        $users | Add-Member -NotePropertyName "MailSizeLimit" -NotePropertyValue ""
        $users | Add-Member -NotePropertyName "MailBoxType" -NotePropertyValue ""
        $users | Add-Member -NotePropertyName "LastUserMailAction" -NotePropertyValue ""

      }
      if ($ShowMFA) {
        $users | Add-Member -NotePropertyName "MFAInfo" -NotePropertyValue ""
      }

      $lic = Get-365licenses
      foreach ($user in $users) {
        $userskus = @()
        $user.proxyAddresses = ($user.proxyAddresses | Where-Object { $_ -like "SMTP*" }) -replace ("SMTP:", "") | ConvertTo-Json -Compress

        foreach ($userlic in $user.licenseAssignmentStates ) {
          $alic = ($lic | Where-Object skuid -eq $userlic.skuid).SkuPartNumber #?? $userlic.skuid
          if (!$alic) { $alic = $userlic.skuid }
          if ($userlic.state -ne "Active") { $alic = "$alic <$($userlic.state)>" }
          $userskus += $alic
        }
        $user.licenseAssignmentStates = $userskus | ConvertTo-Json -Compress

        if ($user.signInActivity) { $user.signInActivity = $user.signInActivity | Select-Object lastSignInDateTime, lastNonInteractiveSignInDateTime | ConvertTo-Json -Compress }
        write-verbose " this next section checks exchangeonline"
            
        if ($showMailBox -and $user.mail ) {
          #  try{
          #  $maildetail = Get-MailboxStatistics -Identity $user.mail -ErrorAction SilentlyContinue |Select-Object DisplayName, TotalItemSize, SystemMessageSizeShutoffQuota, MailboxTypeDetail,LastUserActionTime -ErrorAction SilentlyContinue
          $maildetail = Get-exomailboxStatistics  -UserPrincipalName $user.mail -Properties MailboxTypeDetail, SystemMessageSizeShutoffQuota, LastUserActionTime -ErrorAction SilentlyContinue
          if ($maildetail.MailboxTypeDetail) {
            $user.MailSize = $maildetail.TotalItemSize
            $user.MailSizeLimit = $maildetail.SystemMessageSizeShutoffQuota
            $user.MailBoxType = $maildetail.MailboxTypeDetail
            $user.LastUserMailAction = $maildetail.LastUserActionTime
          }
          else {
            <# Action when all if and elseif conditions are false #>
            $user.mail = ""
            $user.proxyAddresses = "" 
          }
        }
        # catch{
        #   $user.mail =""
        #   $user.proxyAddresses ="" 
        # }
        # }       
        if ($ShowMFA) {
          $user.MFAInfo = Get-365UserMFAMethods -userId $user.id | ConvertTo-Json -Compress
        } 
        $user
      }
    }
      else {
        write-host "Get-365user: Did not find any user entries based on $filterfor"
      }

      # $users
    
  }
  end {}
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

.PARAMETER DontElaborate
 use this when checking connection from within another function - else this function will write-host extra detail abot scope or other auth settings.
 get-365Whoami -DontElaborate
returns just the list of connection : with no sundry detail about scopes
MgGraph                 ExhangeOnline AZureAD MSoline
-------                 ------------- ------- -------
******@*.co.nz                       Not checked

get-365Whoami
returns..
MgGraph Scopes are
["AuditLog.Read.All","AuthenticationContext.Read.All","Directory.Read.All","Domain.Read.All","Group.Read.All","Group.ReadWrite.All","Mail.Read","openid","Organization.Read.All","Policy.Read.All","profile","RoleAssignmentSchedule.Read.Directory","RoleManagement.Read.All","User.Read","User.Read.All","User.ReadWrite.All","UserAuthenticationMethod.Read.All","email"]
MgGraph                 ExhangeOnline AZureAD MSoline
-------                 ------------- ------- -------
******@*.co.nz                       Not checked

.parameter checkIfSignedInTo
use this when checking is a specific tool is signed in to to - 
allowed values == "MgGraph","Exchange","AzureAD"
then this function will return $null if not signed in, or will return the UserPrincipaName

returns somehting like
*@*.co.nz

.EXAMPLE

get-365Whoami -DontElaborate
returns just the list of connection : with no sundry detail about scopes
MgGraph                 ExhangeOnline AZureAD MSoline
-------                 ------------- ------- -------
******@*.co.nz                       Not checked

get-365Whoami
returns..
MgGraph Scopes are
["AuditLog.Read.All","AuthenticationContext.Read.All","Directory.Read.All","Domain.Read.All","Group.Read.All","Group.ReadWrite.All","Mail.Read","openid","Organization.Read.All","Policy.Read.All","profile","RoleAssignmentSchedule.Read.Directory","RoleManagement.Read.All","User.Read","User.Read.All","User.ReadWrite.All","UserAuthenticationMethod.Read.All","email"]
MgGraph                 ExhangeOnline AZureAD MSoline
-------                 ------------- ------- -------
******@*.co.nz                       Not checked


get-365Whoami -checkIfSignedInTo MgGraph 
returns just the UserPrincipalName signed into MgGraph (if any)
returns
*@*.co.nz


#>
function Get-365Whoami {
  [CmdletBinding()]
  param(
    [switch]
    $DontElaborate,
    [ValidateSet("MgGraph", "Exchange", "AzureAD")]
    [string] $checkIfSignedInTo
  )

  # Connect-365 
  $uExchange = ""
  $uAZure = ""
  $uMgGraph = ""
    
  try {
    Write-Verbose "about to check login for MgGraph"
    $result = Invoke-MgGraphRequest -Method GET 'https://graph.microsoft.com/v1.0/me?$select=userPrincipalName' -OutputType PSObject 
    $uMgGraph = $result.userPrincipalName  
  }
  catch { }
  if ($checkIfSignedInTo -eq "MgGraph" ) {
    return  $uMgGraph 
  }
  try {
    Write-Verbose "about to check login for ExchangeOnline"

    $result = Get-ConnectionInformation -ErrorAction SilentlyContinue
    if ($result) {
      $uExchange = "$($result.UserPrincipalName)  <$($result.State)>"
    }
  }
  catch { }
  if ($checkIfSignedInTo -eq "Exchange" ) {
    return $uExchange
  }


  if ($checkIfSignedInTo -eq "AzureAD" ) {
  try {
    Write-Verbose "about to check login for AZureAD"

    $result = Get-AzureADCurrentSessionInfo -ErrorAction SilentlyContinue
    $uAzure = $result.Account.ID
  }
  catch { }

    return $uAzure
  }

  [PSCustomObject]@{
    MgGraph       = $uMgGraph
    ExhangeOnline = $uExchange
    AZureAD       = "Not-Checked"#$uAzure
    MSoline       = "Not checked"
  }

  if ($uMgGraph -and ($DontElaborate -ne $true)) {
    $mgCOntext = Get-MgContext
    write-host "MgGraph Scopes are"
    write-host "$($mgCOntext.scopes |ConvertTo-Json -Compress)"
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
function Get-365Domains {
  [CmdletBinding()]
  param (
        [switch]$EmailEnabled
  )
  Connect-365 
  #get list of domains in M365
  $domains = get-mgdomain | Select-Object id, isdefault, isverified, supportedServices
  if ($EmailEnabled)
  {
    $domains = $domains |Where-Object supportedServices -contains "Email"
  }
  return $domains

}

<#
.SYNOPSIS
connects to MgGraph (using MS prompt)

.DESCRIPTION
connects to MgGraph
WARNING: depending oon your workstation setup it may just autoconnect you with your prior credentials without prompting for new
if you need to login with different credential then Disconnect-365 first !
some scripts may need to connect to ExchangeOnline Also - in that case the script will prompt when required

.EXAMPLE
disconnect-365 
Connect-365
#>
Function Connect-365 {
  [CmdletBinding()]
  param(
    [Switch]$SilentifAlreadyConnected
  )
  # Check if MS Graph module is installed
  if (-not(Get-InstalledModule Microsoft.Graph)) { 
    Write-Host "Microsoft Graph module not found" -ForegroundColor Black -BackgroundColor Yellow
    $install = Read-Host "Do you want to install the Microsoft Graph Module?"
  
    if ($install -match "[yY]") {
      Install-Module Microsoft.Graph -Repository PSGallery -Scope CurrentUser -AllowClobber -Force
    }
    else {
      Write-Host "Microsoft Graph module is required." -ForegroundColor Black -BackgroundColor Yellow
      exit
    } 
  }
  
  $connections = (get-365Whoami -DontElaborate).MgGraph
  # Connect to Graph
  if ($connections) {
    if (!$SilentifAlreadyConnected) { write-host "Connect-365: you are connected to MgGraph with userPrincipleName = $connections" }
    $mgCOntext = Get-MgContext 
    write-verbose "Scopes are $($mgCOntext.scopes|ConvertTo-Json -Compress)"
    return
  }
  # $signinID = read-host "ENter the Signin ID for MS Graph"

  Write-Host "Connecting to Microsoft Graph" -ForegroundColor Cyan
  Connect-MgGraph -Scopes "User.Read.All,Group.Read.All,AuditLog.Read.All,Mail.Read,Domain.Read.All,RoleManagement.Read.All,Policy.Read.All,Directory.Read.All,Organization.Read.All,UserAuthenticationMethod.Read.All,AuthenticationContext.Read.All"  -NoWelcome
  $connections = (get-365Whoami -DontElaborate).MgGraph
  write-host "Connect-365: you are connected to MgGraph with userPrincipleName = $connections"

}
  
<#
.SYNOPSIS
disconnects from MgGraph, AND ExchangeOnline

.DESCRIPTION
disconnects from MgGraph, AND ExchangeOnline

.EXAMPLE
connects to MgGraph
#>
function Disconnect-365 {
  disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
  if (get-365Whoami -checkIfSignedInTo Exchange) { Disconnect-ExchangeOnline }
}


<#
.SYNOPSIS
gets detail showing admin roles assigned to any user

.DESCRIPTION
gets detail showing admin roles assigned to any user
#>
Function Get-365Admins {
  [CmdletBinding()]
  param (
  )

  begin {
    Connect-365 
  }
  process {

      $adminRoies = Get-MgDirectoryRole | Select-Object DisplayName, Id, Description
    ForEach ($role in $adminRoies) {    
      $users = Get-MgDirectoryRoleMember -DirectoryRoleId $role.id | Where-Object { $_.AdditionalProperties."@odata.type" -eq "#microsoft.graph.user" } | Get-365user -basicInfoOnly -EnablebUsersOnly
      if ($users) {
        foreach ($user in $users) {
          if ($user)
          {
          $result = [PSCustomObject]@{
           Role              = $role.DisplayName
           userPrincipalName = $user.UserPrincipalName
           userDisplayname    = $user.DisplayName
           Descripion        = $role.Description
           # roleid            = $role.Id
          }
          $result
        }
        }
      }
     }
     
  }
}


<#
  .SYNOPSIS
  Get the MFA status of the user
  
  .DESCRIPTION
  Long description
  
  .PARAMETER userId
  either the UserPrincipalName or the ID of a 365 user
  
  .EXAMPLE
  Get-365UserMFAMethods -userId sean.macey@imatec.co.nz -verbose

  Get-365UserMFAMethods -userId fe636523-5608-438d-83f5-41b5c9a7fe95
  #>
Function Get-365UserMFAMethods {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName)]
    [alias('Name')]
    [string[]] $userId
  )
  begin {
    Connect-365

  }
  process {
    # Get MFA details for each user
    #[array]

    foreach ($auser in $userId) {
      write-verbose "Get-365UserMFAMethods: getting MFA for user  $auser"
      try {
        [array]$mfaData = Get-MgUserAuthenticationMethod -UserId $auser  -ErrorAction SilentlyContinue
      }
      catch {
        return
      }
    
      if (!$mfaData) { return }
  
      # Create MFA details object
      $mfaMethods = [PSCustomObject][Ordered]@{
        Name                  = $auser
        status                = ""
        authApp               = ""
        phoneAuth             = ""
        fido                  = ""
        helloForBusiness      = ""
        helloForBusinessCount = 0
        emailAuth             = ""
        tempPass              = ""
        passwordLess          = ""
        softwareAuth          = ""
        authDevice            = ""
        authPhoneNr           = ""
        SSPREmail             = ""
        OtherInfo             = ""
        
      }
  
      ForEach ($method in $mfaData) {
        Switch ($method.AdditionalProperties["@odata.type"]) {
          "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" { 
            # Microsoft Authenticator App
            $mfaMethods.authApp = $true
            $mfaMethods.authDevice += "$($method.AdditionalProperties["displayName"]),"
            $mfaMethods.status = "enabled"
          } 
          "#microsoft.graph.phoneAuthenticationMethod" { 
            # Phone authentication
            $mfaMethods.phoneAuth = $true
            $mfaMethods.authPhoneNr = $method.AdditionalProperties["phoneType", "phoneNumber"] -join ' '
            $mfaMethods.status = "enabled"
          } 
          "#microsoft.graph.fido2AuthenticationMethod" { 
            # FIDO2 key
            $mfaMethods.fido = $true
            $mfaMethods.otherInfo += "Fido-Model:$($method.AdditionalProperties["model"]),"
            $mfaMethods.status = "enabled"
          } 
          "#microsoft.graph.passwordAuthenticationMethod" { 
            # Password
            # When only the password is set, then MFA is disabled.
            if ($mfaMethods.status -ne "enabled") { $mfaMethods.status = "disabled" }
          }
          "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" { 
            # Windows Hello
            $mfaMethods.helloForBusiness = $true
            $mfaMethods.otherInfo += "Hello-Device:$($method.AdditionalProperties["displayName"]),"
            $mfaMethods.status = "enabled"
            $mfaMethods.helloForBusinessCount++
          } 
          "#microsoft.graph.emailAuthenticationMethod" { 
            # Email Authentication
            $mfaMethods.emailAuth = $true
            $mfaMethods.SSPREmail = $method.AdditionalProperties["emailAddress"] 
            $mfaMethods.status = "enabled"
          }               
          "microsoft.graph.temporaryAccessPassAuthenticationMethod" { 
            # Temporary Access pass
            $mfaMethods.tempPass = $true
            $mfaMethods.otherInfo += "TempPass-LifeTime:$($method.AdditionalProperties["lifetimeInMinutes"]),"
            $mfaMethods.status = "enabled"
          }
          "#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod" { 
            # Passwordless
            $mfaMethods.passwordLess = $true
            $mfaMethods.otherInfo += "passwordless-devicve:$($method.AdditionalProperties["displayName"]),"
            $mfaMethods.status = "enabled"
          }
          "#microsoft.graph.softwareOathAuthenticationMethod" { 
            # ThirdPartyAuthenticator
            $mfaMethods.softwareAuth = $true
            $mfaMethods.status = "enabled"
          }
        }
      }
      $mfaMethods.authDevice = $mfaMethods.authDevice.trim(",", " ")
      $mfaMethods.otherInfo = $mfaMethods.otherInfo.trim(",", " ")

      $mfaMethods
    }
  }
}


<#
.SYNOPSIS
connects to ExchangeOnline - which is needed by some scripts

.DESCRIPTION
connects to ExchangeOnline - which is needed by some scripts
if exchangeonlineManagement module is not installed, then it will first install it

.EXAMPLE
Connect-JustToExchange
#>
function Connect-JustToExchange {
  if (!(get-365Whoami -checkIfSignedInTo Exchange)) {
    write-host "You need to Connect-ExchangeOnline  before you can get details about M365 based DKIM configuration" -ForegroundColor Red
  
    if (-not(Get-InstalledModule ExchangeOnlineManagement)) { 
      Write-Host "Microsoft ExchangeOnlineManagement module not found" -ForegroundColor Black -BackgroundColor Yellow
      $install = Read-Host "Do you want to install the Microsoft Graph Module?"
  
      if ($install -match "[yY]") {
        Install-Module ExchangeOnlineManagement -Repository PSGallery -Scope CurrentUser -AllowClobber -Force
      }
      else {
        Write-Host "ExchangeOnlineManageManagement module is only required if you want to see which domains are configured for DKIM." -ForegroundColor Black -BackgroundColor Yellow
      } 
    }
    Connect-ExchangeOnline -UserPrincipalName (get-365Whoami -checkIfSignedInTo MgGraph)
  }
}

<#
.SYNOPSIS
creates a new SMX to 365 mail connector

.DESCRIPTION
creates a new SMX to 365 mail connector
this enables mail to transit from SMX towards 365

this CMD also configured the Skip listing (also needed by SMX)

ANd also creates a DISABLED Mail handing rule that rejects mail messages that are not sent via SMX
- that rule should only be enabled when you are sure that no systems will send directly to 365 MAil-Gateways, and must also be disabled if the SMX Inbount Connector is disabled.
   To Enable SMX Mail transport rules, pipe the output of the Commmand => Get-365RuleOnlyAcceptInboundMailFromSMX | Enable-TransportRule
   To DISABLE SMX Mail transport rules, pipe the output of the Commmand => Get-365RuleOnlyAcceptInboundMailFromSMX | Disable-TransportRule

.EXAMPLE
An example
#>
function New-365SMXInboundConnector {
  [CmdletBinding()]
  param ()
  connect-365
  Connect-JustToExchange -UserPrincipalName (get-365Whoami -checkIfSignedInTo MgGraph)

  Remove-365SMXRuleConnectionFIlter
  New-365RuleOnlyAcceptInboundMailFromSMX 
  $prev = Get-InboundConnector |Where-Object SenderIPAddresses -like "*113.197.64.0*"
  if ($prev) {#.SenderIPAddresses -contains "113.197.67.0/24") {
    write-host "An inbound Connector for SMX already exits, If you wish to recreate it first delete '$($prev.Identity)'"
    return
  }
  $senderIps = "113.197.64.0/24", "113.197.65.0/24", "113.197.66.0/24", "113.197.67.0/24", "203.84.134.0/24", "203.84.135.0/24"
  New-InboundConnector -Name "SMX-inbound-365" -ConnectorType Partner -Enabled $true -RequireTls $True -SenderIPAddresses $senderIps -EFSkipIPs $senderIps -SenderDomains "smtp:*"
  Write-Host "SMX Inbound Connector Created and Enabled, Remember should you disable this; make sure to also DISABLE the MAIL rule: Only accept inbound mail from SMX"

}

<#
.SYNOPSIS
create a new SMX outbound Connector (in a disabled state)

.DESCRIPTION
this is SAFE to use - since the created connector must be seperately enabled
before enabling make sure that SMX, DNS, SPF, DKIM are correctly configured
you must seperate enabled using Enable-365SMXOutboundConnector

.PARAMETER Country
default is NZ for NZ, can also be configured AU for Australia
this defines what interface to SMX filtering is used
NZ = 365.nz.smxemail.com
AU => 365.au.smxemail.com
.EXAMPLE
New-365SMXInboundConnector
#>
function New-365SMXOutboundConnector {
  [CmdletBinding()]
  param (
    [ValidateSet("NZ", "AU")]
    [string]$Country = "NZ"
  )
  connect-365
  #connect-JustToExchange
  Connect-JustToExchange -UserPrincipalName (get-365Whoami -checkIfSignedInTo MgGraph)

  switch ($Country) {
    "NZ" { $countrySring = "365.nz.smxemail.com" }
    "AU" { $countrySring = "365.au.smxemail.com" }
    default { $countrySring = "365.nz.smxemail.com" }
  }
  $prev = Get-OutboundConnector | Where-Object SmartHosts -like  "*.smxemail.com"
  if ($prev) {
    write-host "365 SMX outbound connector was already created,"
    return  $prev 
  }
  #New-OutboundConnector -name "SMX-Outbound-365" -Enabled $false -RecipientDomains * -ConnectorType Partner -SmartHosts "365.nz.smxemail.com"
  New-OutboundConnector -name "SMX-Outbound-365" -Enabled $false -RecipientDomains * -ConnectorType Partner -SmartHosts $countrySring -UseMXRecord $false
  write-Host "Only enable this connector when SMX, SPF, DKIM are configured to avoid problems, the connector is created as DISABLED, You must seperately enable it!"
  Write-host "When this connector is enabled all email traffic will be sent to it -=> so you better make sure the SMX, SPF,DKIM configurations are correct first " -ForegroundColor Yellow

  write-host ""
  write-Host "IMPORTANT: to avoid production impacts this script does not ENABLE the connector, once you are certain that all SPF, MX, DKIM and SMX configuration is correct( and only then) "
  Write-host "To Enable SMX Inbound Mail COnnector ==> Enable-365SMXOutboundConnector" -ForegroundColor   DarkYellow
  Write-host "To DISABLE SMX Inbound Mail COnnector==> Disable-365SMXOutboundConnector | Disable-TransportRule" -ForegroundColor     Green

}


<#
.SYNOPSIS
Make 365 send ALL its email through SMX filtering.
If SMX is not configured then 365 email will fail delivery!

.DESCRIPTION
Make 365 send all its email through SMX filtering.
Only Enable the outbound connector once you are sure SMX, DKIM, SPF and MX records are properly configured.
failiure to ensure SMX etc are properly configured before youe nable this will cause 365 mail delivery to fail

.EXAMPLE
An example
#>
function Enable-365SMXOutboundConnector {
  [CmdletBinding()]
  param ()
  connect-365
  #connect-JustToExchange
  Connect-JustToExchange -UserPrincipalName (get-365Whoami -checkIfSignedInTo MgGraph)

  $prev = Get-OutboundConnector | Where-Object SmartHosts -like "365.*.smxemail.com"
  if (!$prev) {
    write-host "Unable to find the SMX utbound connector: so can't enable it "
    return
  }

  If ($prev.Enabled -eq $false) {
    write-host "Enabling SMX outbound"
    Write-host "You better make sure the SMX, SPF,DKIM configurations are correct first, else disbale this! " -ForegroundColor Yellow
    $prev | Set-OutboundConnector -Enabled $true
  }
  else {
    write-Host "the SMX Connector was already enabled"
  }
  Get-OutboundConnector | Where-Object SmartHosts -like "365.*.smxemail.com"

}


<#
.SYNOPSIS
disables the 365 connector to SMX mail filtering

.DESCRIPTION
disables the 365 connector to SMX mail filtering
use this when you want to to M365 from sending emails through SMX filtering

.EXAMPLE
Disable-365SMXOutboundConnector
#>
function Disable-365SMXOutboundConnector {
  [CmdletBinding()]
  param ()
  connect-365
  #connect-JustToExchange
  Connect-JustToExchange -UserPrincipalName (get-365Whoami -checkIfSignedInTo MgGraph)

  $prevs = Get-OutboundConnector | Where-Object SmartHosts -like "365.*.smxemail.com"
  if (!$prevs) {
    write-host "Unable to find the SMX otbound connector: so can't Disable it " -ForegroundColor Yellow
    return
  }
  
  $prevs | Set-OutboundConnector -Enabled $false

  write-host "DisabledSMX outbounfConnector $($prevs.Name )"
  Get-OutboundConnector | Where-Object SmartHosts -like "365.*.smxemail.com"

}



<#
.SYNOPSIS
generates a list of CMDlets within this script/module

.DESCRIPTION
generates a list of CMDlets within this script/module
FYI: if this script is renamed as  a *.psm1 (instead of a *.ps1) 
 then installed within a folder "toolsFor365" under the powershell\modules
 the result will be you can call these commands without first manaully importing the script.

.EXAMPLE
Get-365Command
#>
function Get-365Command {
  param (
    
  )
     $c = Get-Command -Module toolsFor365
    if ($c) {$c ; return}
    write-host "Get-365Command: will only show you the Full list of commands when toolFor365 is installed as a Module (*.psm1)"
    write-host "since you ran this script as . ./toolsFor365.ps1 function the list below is manual and may be inaccurate"
    write-Host "
    CommandType     Name                                               Version    Source
    -----------     ----                                               -------    ------
    Function        Connect-365                                        0.0        toolsFor365
    Function        Connect-JustToExchange                             0.0        toolsFor365
    Function        Disable-365SMXOutboundConnector                    0.0        toolsFor365
    Function        Disconnect-365                                     0.0        toolsFor365
    Function        Enable-365SMXOutboundConnector                     0.0        toolsFor365
    Function        Get-365Admins                                      0.0        toolsFor365
    Function        Get-365Commands                                    0.0        toolsFor365
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
    "

 }

<#
.SYNOPSIS
removes any IP associated with SMX from the email spam MS allow list

.DESCRIPTION
removes any IP associated with SMX from the email spam MS allow list
 Reaason: To ensure SMX 365 & Office 365 works in a dual filtering mode, you must remove the SMX IP addresses,
since leaving the connection filter IPs in place will bypass EOP scanning for messages originating from SMX. 
- this is called by the New-365SMXInboundConnector     

.EXAMPLE
Remove-365SMXRuleConnectionFIlter
#>
function Remove-365SMXRuleConnectionFIlter {
  [CmdletBinding()]
  param (
   )
   $senderIps = "113.197.64.0/24", "113.197.65.0/24", "113.197.66.0/24", "113.197.67.0/24", "203.84.134.0/24", "203.84.135.0/24","113.197.64.0/22","203.84.134.0/25"
   $cfilter =  Get-HostedConnectionFilterPolicy

   $IPAllowList = $cfilter.IPAllowList
  $newIpFilter = @()
  $wasFound = ""
   foreach ($anAllow in  $IPAllowList)
   {

    if (!($anAllow -in $senderIps))
    {
    $newIpFilter += $anAllow
    $wasFound
    }
   }
$newIpFilter
if ($wasFound){
  write-host "365 Hosted Connection Filter contained IP ranges for SMX - these have been removed"
  write-host "Reaason: To ensure SMX 365 & Office 365 works in a dual filtering mode, you must remove the SMX IP addresses,"
  write-Host "since leaving the connection filter IPs in place will bypass EOP scanning for messages originating from SMX. "
}
    $cfilter | set-HostedConnectionFilterPolicy -IPAllowList $newIpFilter
  
}

<#
.SYNOPSIS
Creates a MAIL handling rule to ensure ONLY SMX can deliver mail to 365

.DESCRIPTION
Creates a MAIL handling rule to ensure ONLY SMX can deliver mail to 365
be careful when enabling this rule, sice if you have any system that send mail directly to the 365 Mail relays, then they will FAIL
For safety reasons this rule is created in DISABLED mode
   To Enable SMX Mail transport rules, pipe the output of the Commmand => Get-365RuleOnlyAcceptInboundMailFromSMX | Enable-TransportRule
   To DISABLE SMX Mail transport rules, pipe the output of the Commmand => Get-365RuleOnlyAcceptInboundMailFromSMX | Disable-TransportRule

.PARAMETER DontElaborate
Parameter description

.EXAMPLE
New-365RuleOnlyAcceptInboundMailFromSMX
New-365RuleOnlyAcceptInboundMailFromSMX -DontElaborate  
#>
function New-365RuleOnlyAcceptInboundMailFromSMX {

   param(
    [switch]$DontElaborate
   )

   $Rules = Get-365RuleOnlyAcceptInboundMailFromSMX -DontElaborate
      if ($rules) {if (!$DontElaborate) {Write-Host "The MAIL transport rule to Prevent email delivery from any source aother than SMX already exists"}}
   else {
    New-TransportRule -Name "Only accept inbound mail from SMX" -ExceptIfSenderIpRanges "113.197.64.0/24", "113.197.65.0/24", "113.197.66.0/24", "113.197.67.0/24", "203.84.134.0/24", "203.84.135.0/24" -SetAuditSeverity DoNotAudit -ExceptIfMessageTypeMatches Calendaring -FromScope NotInOrganization -Enabled $false -DeleteMessage $true |Out-Null
   }
   Get-365RuleOnlyAcceptInboundMailFromSMX -DontElaborate:$DontElaborate
}

<#
.SYNOPSIS
Gets detail about any MAIL handling rules that force mail only via SMX

.DESCRIPTION
Gets detail about any MAIL handling rules that force mail only via SMX
   To Enable SMX Mail transport rules, pipe the output of the Commmand => Get-365RuleOnlyAcceptInboundMailFromSMX | Enable-TransportRule
   To DISABLE SMX Mail transport rules, pipe the output of the Commmand => Get-365RuleOnlyAcceptInboundMailFromSMX | Disable-TransportRule

.PARAMETER DontElaborate
if used then the CMDLet will provide feedback (other than any rule(s) if found)

.EXAMPLE
 Get-365RuleOnlyAcceptInboundMailFromSMX
 Get-365RuleOnlyAcceptInboundMailFromSMX -DontElaborate
#>
function Get-365RuleOnlyAcceptInboundMailFromSMX {
 # [CmdletBinding()]
  param(
   [switch]$DontElaborate
  )
   $rules = Get-TransportRule  |Where-Object {($_.FromScope -like "NotInOrganization") -and ($_.Description -like "*Delete the message without notifying the recipient*113.197.64.0*" )}

  if ($DontElaborate -ne $True) {
    write-host "Rules were found, If enabled they will prevent mail from from ANY SOURCE other than SMX" -ForegroundColor Yellow
    $rules | ForEach-Object {
      write-host "$($_.Description)"
    }
    Write-host "To Enable SMX Mail transport rules, pipe the output of the Commmand => Get-365RuleOnlyAcceptInboundMailFromSMX | Enable-TransportRule" -ForegroundColor   DarkYellow
    Write-host "To DISABLE SMX Mail transport rules, pipe the output of the Commmand => Get-365RuleOnlyAcceptInboundMailFromSMX | Disable-TransportRule" -ForegroundColor     Green
  }
  
  $rules
}

Get-365Command




