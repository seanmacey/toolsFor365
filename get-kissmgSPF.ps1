$domains = get-mgdomain
foreach ($adomain in $domains){
   # write-host "id = $($adomain.id)"
    $domainid = $adomain.id

    $DNSrecs = Get-MgDomainServiceConfigurationRecord -DomainId $domainid
    #$MXrecs = $DNSrecs |Where-Object recordType -eq "Mx"|Select-Object id -ExpandProperty Additionalproperties  @{name = "domain"; e= {$domainid}}
    $MXrecs = $DNSrecs |Where-Object recordType -eq "Txt"#) -and ($true))# ).AdditionalProperties.mailExchange
   # $spf = $MXrecs |Where-Object {$_.$mxrecs.AdditionalProperties.text -like "v=spf1*"}
    $spfs = $mxrecs |Select-Object -ExpandProperty AdditionalProperties

    foreach ($rec in $spfs){
       # $e = $rec |Select-Object -ExpandProperty AdditionalProperties
        $arec = [PSCustomObject]@{
            Name = $domainid
            spf = $rec.text

        }
    }

 $arec


}

