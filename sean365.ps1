# Invoke-MgGraphRequest -Method GET https://graph.microsoft.com/v1.0/me

<#
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Install-Module Microsoft.Graph -Scope AllUsers
Get-InstalledModule Microsoft.Graph
Get-InstalledModule

# get the required permissions 
Find-MgGraphCommand -command Get-MgUser | Select -First 1 -ExpandProperty Permissions
Find-MgGraphCommand looks up uri and give equivalent command
find-mgGraphCommand -Uri 'https://graph.microsoft.com/v1.0/subscribedSkus'


Connect-MgGraph -Scopes "User.Read.All","Group.Read.All","AuditLog.Read.All","Mail.Read","Domain.Read.All","RoleManagement.Read.All","Policy.Read.All"
Get-MgEnvironment
Get-MgContext

#get M365 suggested service configurations
https://graph.microsoft.com/v1.0/domains/kissit.co.nz/serviceConfigurationRecords


exchange powershell DKIM
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -UserPrincipalName
Get-DkimSigningConfig 
PS C:\Users\SeanMacey> Get-DkimSigningConfig -Identity imatec.co.nz
Domain       Enabled
------       -------
imatec.co.nz True

https://learn.microsoft.com/en-us/graph/aad-advanced-queries?tabs=http
#>


<#
extended search
 Use the $filter query parameter with the ne operator. This request isn't supported by default because the ne operator is only supported in advanced queries. Therefore, you must add the ConsistencyLevel header set to eventual and use the $count=true query string.
https://learn.microsoft.com/en-us/graph/aad-advanced-queries?tabs=http
GET https://graph.microsoft.com/v1.0/users?$filter=accountEnabled ne true&$count=true ConsistencyLevel: eventual
#>

#get a list of  users that have EMAIL (even if blocked from signin)
$result = Invoke-MgGraphRequest -Method GET 'https://graph.microsoft.com/v1.0/users?$select=displayName,userPrincipalName,Mail,proxyAddresses,assignedLicenses,accountEnabled,onPremisesDistinguishedName,onPremisesSamAccountName' -OutputType PSObject
$usersWithMail = $result.value |Where-Object mail

#Get a list of users that are enabled (can log in)
$result = Invoke-MgGraphRequest -Method GET 'https://graph.microsoft.com/v1.0/users?$select=displayName,userPrincipalName,Mail,proxyAddresses,assignedLicenses,accountEnabled,lastPasswordChangeDateTime,onPremisesSyncEnabled,onPremisesDomainName,onPremisesDistinguishedName,onPremisesSamAccountName,signInActivity,userType' -OutputType PSObject
$usersWithMail = $result.value |Where-Object accountEnabled -eq $True

#get mailbox report
$result = Invoke-MgGraphRequest -Method GET 'https://graph.microsoft.com/v1.0/reports/getMailboxUsageQuotaStatusMailboxCounts(period="D7")' -OutputType PSObject

#get list of domains in M365
get-mgdomain |Select-Object id,isdefault,isverified,supportedServices

#get list of domains in M365, that have email services defined
get-mgdomain |Where-Object supportedServices -Contains Email  |Select-Object id,isdefault,isverified

#get a list of subscriptions (Licenses)
Get-MgSubscribedSku 

