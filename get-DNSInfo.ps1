<#

Connect-MgGraph -Scopes "User.Read.All","Group.Read.All","AuditLog.Read.All","Mail.Read","Domain.Read.All"

#>
Write-host 'ensure you Connect-MgGraph -Scopes "Domain.Read.All"  first'
$domains = get-mgdomain |where-object Id -NotLike "*.onmicrosoft.com"
foreach ($adomain in $domains){
   # write-host "id = $($adomain.id)"
    $domainid = $adomain.id 

    $DNSrecs = Get-MgDomainServiceConfigurationRecord -DomainId $domainid
    $DNS2 = $DNSrecs |Where-Object recordType -eq "Txt"#) -and ($true))# ).AdditionalProperties.mailExchange
    $spfs = ($DNS2 |Select-Object -ExpandProperty AdditionalProperties).text -join ", "

    $spfDNS = (Resolve-DnsName -Name $domainid -Type TXT |Where-Object {$_.Strings -Like "*v=spf1*"}).strings -join ", "
    $MxinDNS = (Resolve-DnsName -Name $domainid -Type MX |where-object Name -eq $domainid).NameExchange -join ", " 
    $DKIMsmxinDNS1 = (Resolve-DnsName -Name smx1._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue) 
    $DKIMsmxinDNS2 = (Resolve-DnsName -Name smx2._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)
    $DKIMM365inDNS1 = (Resolve-DnsName -Name selector1._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)
    $DKIMM365inDNS2 = (Resolve-DnsName -Name selector2._domainkey.$domainid -Type CNAME -ErrorAction SilentlyContinue)

    $MXrecs = (Get-MgDomainServiceConfigurationRecord -DomainId $domainid | Where-Object recordType -eq "Mx").AdditionalProperties.mailExchange -join ", "


    $arec = [PSCustomObject]@{
        Name = $domainid
        M365_spf = $spfs
        DNS_spf = $spfDNS
        M365_mx = $MXrecs
        DNS_mx = $MXinDNS
        DNS_DKIM_SMX_1 = "$($DKIMsmxinDNS1.Name),  $($DKIMsmxinDNS1.NameHost)"
        DNS_DKIM_SMX_2 = "$($DKIMsmxinDNS2.Name),  $($DKIMsmxinDNS2.NameHost)"
        DNS_DKIM_M365_1 = "$($DKIMM365inDNS1.Name),  $($DKIMM365inDNS1.NameHost)"
        DNS_DKIM_M365_2 = "$($DKIMM365inDNS2.Name),  $($DKIMM365inDNS2.NameHost)"

    }
 $arec


}

