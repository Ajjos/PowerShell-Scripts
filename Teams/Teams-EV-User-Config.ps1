

##############################################################
#  Enterprise Voice user configuration script
#  
#  Requires PSTN license assigned to the account
#  Requires MS Graph and Teams PS module connections
#  Browse and select the input CSV file
#  Uses Get-MgUser for updating Usage Location
#  Input: Sample CSV file with UPN,Phone,VoiceRoutingPolicy,CallHoldPolicy,Teams License,UsageLocation,VoicemailPolicy,CallParkPolicy,CallerIDPolicy,CallingPolicy,DialPlan
#  Output: DisplayName,User,Email,Phone,VoicemailPolicy,CallHoldPolicy,CallParkPolicy,CallerIDPolicy,CallingPolicy,VoiceRoutingPolicy,DialPlan,UsageLocation

##############################################################


#$ErrorActionPreference = 'SilentlyContinue'

Connect-MgGraph
Connect-MicrosoftTeams

#$Users = Import-CSV .\FR_Number_Assignment.csv

# Function for browsing the input file
Function Get-FilePath{
[CmdletBinding()]
Param(
    [String]$Filter = "|*.*",
    [String]$InitialDirectory = (Get-Location))
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $InitialDirectory
    $OpenFileDialog.filter = $Filter
    [void]$OpenFileDialog.ShowDialog()
    $OpenFileDialog.filename
}

Write-Output "Please 'Browse' the CSV file containing the Groups"
$filepath = Get-FilePath

Write-host $filepath "has been selected and the processing will start now" -ForegroundColor Yellow

$Users = Import-csv $filepath

$Results = @()

Foreach($User in $Users){
    
    #$UPN = (Get-AzureADUser -ObjectId $User.UPN).Userprincipalname
    $UPN = (Get-MgUser -UserId $User.UPN).Userprincipalname
    
    #Set-AzureADUser -ObjectId $UPN -UsageLocation "FR"
    Update-MgUser -UserId $UPN -UsageLocation $User.UsageLocation 
      
    Set-CsPhoneNumberAssignment -Identity $UPN -PhoneNumber "+$($User.Phone)" -PhoneNumberType DirectRouting 
    #Set-CsPhoneNumberAssignment -Identity $UPN -PhoneNumber $User.Phone -PhoneNumberType DirectRouting

    Grant-CsOnlineVoicemailPolicy -Identity $UPN -PolicyName $User.VoicemailPolicy
    Grant-CsTeamsCallHoldPolicy -Identity $UPN -PolicyName $User.CallHoldPolicy
    Grant-CsTeamsCallParkPolicy -Identity $UPN -PolicyName $User.CallParkPolicy
    Grant-CsCallingLineIdentity -Identity $UPN -PolicyName $User.CallerIDPolicy
    Grant-CsTeamsCallingPolicy -identity $UPN -PolicyName $User.CallingPolicy
    Grant-CsOnlineVoiceRoutingPolicy -Identity $UPN -PolicyName $User.VoiceRoutingPolicy
    Grant-CsTenantDialPlan -Identity $UPN -PolicyName $User.DialPlan 

    $UserDetails = Get-CsOnlineUser -Identity $UPN | Select UsageLocation, DisplayName, UserPrincipalName, LineURI, OnlineVoicemailPolicy, TeamsCallHoldPolicy, TeamsCallParkPolicy, CallingLineIdentity, TeamsCallingPolicy, TenantDialPlan, OnlineVoiceRoutingPolicy

    $Results += [PSCustomObject]@{
    
        "DisplayName" = $UserDetails.DisplayName
        "User" = $UserDetails.UserPrincipalName
        "Email" = $User.Email
        "Phone" = ($UserDetails.LineURI -split ':')[1]
        "VoicemailPolicy" = $UserDetails.OnlineVoicemailPolicy
        "CallHoldPolicy" = $UserDetails.TeamsCallHoldPolicy
        "CallParkPolicy" = $UserDetails.TeamsCallParkPolicy
        "CallerIDPolicy" = $UserDetails.CallingLineIdentity
        "CallingPolicy" = $UserDetails.TeamsCallingPolicy
        "VoiceRoutingPolicy" = $UserDetails.OnlineVoiceRoutingPolicy
        "DialPlan" = $UserDetails.TenantDialPlan
        "UsageLocation" = $UserDetails.UsageLocation

    }

}

$Date = (Get-Date).ToString("yyyyMMdd")

$Results | Export-CSV EV-Config-Report-$Date.csv -NoTypeInformation -Encoding UTF8
