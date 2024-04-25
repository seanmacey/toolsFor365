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

Get-MgEnvironment

https://learn.microsoft.com/en-us/graph/aad-advanced-queries?tabs=http

extended search
 Use the $filter query parameter with the ne operator. This request isn't supported by default because the ne operator is only supported in advanced queries. Therefore, you must add the ConsistencyLevel header set to eventual and use the $count=true query string.
https://learn.microsoft.com/en-us/graph/aad-advanced-queries?tabs=http
GET https://graph.microsoft.com/v1.0/users?$filter=accountEnabled ne true&$count=true ConsistencyLevel: eventual
#>

