#Connect-MgGraph -Scopes "User.Read.All","Group.ReadWrite.All","AuditLog.Read.All","Mail.Read","Domain.Read.All"

$domains = get-mgdomain
foreach ($adomain in $domains){
    $domainid = $adomain.id
    $MXrecs = Get-MgDomainServiceConfigurationRecord -DomainId $domainid | Where-Object recordType -eq "Mx"# ).AdditionalProperties.mailExchange
    
    foreach ($rec in $MXrecs){
        $arec = [PSCustomObject]@{
            Name = $domainid
            MX = $rec.AdditionalProperties.mailExchange
           # preference = $rec.AdditionalProperties.preference
        }
    }
 $arec
}

