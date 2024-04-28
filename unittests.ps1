$domains =  "imatec.co.nz","jobe.co.nz","kissit.co.nz"
$adomain = "kissit.co.nz"
$auser = "sean.macey@imatec.co.nz"
$users = @("sean.macey@imatec.co.nz","pravinesh.nadan@kissit.co.nz")


try {
 Resolve-DNSSUmmary -Domain $domains
Resolve-DNSSummary -name $adomain
$adomain |Resolve-DNSSummary
$domains |Resolve-DNSSummary

write-host "----------------------"

Get-365DNSInfo
Get-365DNSInfo -Domain $adomain
Get-365DNSInfo -Name $domains
$domains |Get-365DNSInfo     

write-host "Get-365UserMFAMethods -userId $users----------------------" -ForegroundColor DarkYellow
Get-365UserMFAMethods -userId $users
write-host "Get-365UserMFAMethods -Name $auser----------------------" -ForegroundColor DarkYellow
Get-365UserMFAMethods -Name $auser
write-host "$users | Get-365UserMFAMethods----------------------" -ForegroundColor DarkYellow
$users | Get-365UserMFAMethods 

write-host "Get-365Admins----------------------" -ForegroundColor DarkYellow
Get-365Admins
write-host "Get-365Domains----------------------" -ForegroundColor DarkYellow
get-365Domains
write-host "Get-365Domains -EmailEnabled----------------------" -ForegroundColor DarkYellow
get-365Domains


}
catch {

    Write-Host "One of the CMDlets Failed"
    $error[0]
}

