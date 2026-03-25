

##############################################################
#  
#  All Users licenses report
#
#  This script generates a basic report with the assigned Licenses for all users.
#  
#  Runs on the Mg Graph PS module.
#  Displays the progress count while running.
#
#  Input: Gets all users list using Get-MgUser -All command
#  Output: CSV file with DisplayName, UserPrincipalName, ObjectID & Licenses
#
##############################################################

Connect-MgGraph

$Users =  Get-MgUser -All -Property Id, DisplayName, UserPrincipalName | Select Id, DisplayName, UserPrincipalName
Write-Host "Total no. of users " $Users.count

$report = @()
$i= 1

foreach ($User in $Users) {
    
    $i
    $User.UserPrincipalName
    Write-Host ""

   

    $licenses = ""
    $licenseNames = ""
    $licenses = Get-MgUserLicenseDetail -UserId $User.Id
    $licenseNames = $licenses.SkuPartNumber -join ", "
    

    $report += [PSCustomObject]@{
        
        DisplayName = $User.DisplayName
        UserPrincipalName = $User.UserPrincipalName
        ObjectID = $User.ID
        Licenses = $licenseNames
    }

    $i++
}

$Date = (Get-Date).ToString('yyyyMMdd')

$report | Export-Csv -Path "UserLicenses-Report-$Date.csv" -NoTypeInformation -Encoding UTF8
