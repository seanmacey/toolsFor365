#Connect-MgGraph -Scopes "User.Read.All","Group.Read.All","AuditLog.Read.All","Mail.Read","Domain.Read.All"


# Invoke-MgGraphRequest -Method GET 'https://graph.microsoft.com/v1.0/domains?$select=id,supportedServices' -OutputType Json
#Invoke-MgGraphRequest -Method GET 'https://graph.microsoft.com/v1.0/domains?$select=id,supportedServices' -OutputType Json

#Invoke-MgGraphRequest#  -OutputType Json -Headers ConsistencyLevel:eventual

#

$domains = get-mgdomain |where Id -NotLike "*.onmicrosoft.com"
$MXrecords=@()
foreach ($adomain in $domains){
    $domainid = $adomain.id
    $MXrecs = Get-MgDomainServiceConfigurationRecord -DomainId $domainid | Where-Object recordType -eq "Mx"# ).AdditionalProperties.mailExchange
    
    foreach ($rec in $MXrecs){
        $arec = [PSCustomObject]@{
            Domain = $domainid
            MailRelayHost = $rec.AdditionalProperties.mailExchange
           # preference = $rec.AdditionalProperties.preference
        }
    }
 $mxrecords += $arec 
}
$MXrecords  |Sort-Object name |FL
# .\get-kissmgMX.ps1 |Sort-Object name |fl
