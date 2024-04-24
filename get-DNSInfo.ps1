$domains = get-mgdomain
foreach ($adomain in $domains){
   # write-host "id = $($adomain.id)"
    $domainid = $adomain.id

    $DNSrecs = Get-MgDomainServiceConfigurationRecord -DomainId $domainid
    $DNS2 = $DNSrecs |Where-Object recordType -eq "Txt"#) -and ($true))# ).AdditionalProperties.mailExchange
    $spfs = ($DNS2 |Select-Object -ExpandProperty AdditionalProperties).text -join ", "

    $spfDNS = (Resolve-DnsName -Name $domainid -Type TXT |Where-Object {$_.Strings -Like "*v=spf1*"}).strings -join ", "
    $MxinDNS = (Resolve-DnsName -Name $domainid -Type MX |where-object Name -eq $domainid).NameExchange -join ", "
    $MXrecs = (Get-MgDomainServiceConfigurationRecord -DomainId $domainid | Where-Object recordType -eq "Mx").AdditionalProperties.mailExchange -join ", "


    $arec = [PSCustomObject]@{
        Name = $domainid
        M365spf = $spfs
        DNSspf = $spfDNS
        M365mx = $MXrecs
        DNSmx = $MXinDNS
    }
 $arec


}

