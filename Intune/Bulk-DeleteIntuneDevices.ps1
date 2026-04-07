
##############################################################
#  Intune Device Deletion Script
#  Covers:
#   - Intune device entries
#   - Entra device entries
#
#  Uses Get-MgDeviceManagementManagedDevice to get both Intune & Entra device entries using Device name.
#  Cleans up device entries across Intune & Entra except for Autopilot devices. 
#  Input: Browse CSV file with "Device" column. 
#  Output: CSV Report with Name, Intune DeviceID, Intune Status, Entra DeviceID & Entra Status columns
##############################################################



param (
    [Parameter(Mandatory = $false)]
    [switch]$Delete
)

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


$i=1
$IntuneStatus = "N.A."
$EntraStatus = "N.A."
$Results = @()

$Devices = Import-Csv $filepath

Foreach($Device in $Devices){
    
    $Error.Clear()
    Write-Host $i $Device.Device

    $md = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$($Device.Device)'"
    
    if($Delete){
        Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $md.Id    
            
            If($Error){
                $IntuneStatus = $Error[0].Exception
            }else{
                $IntuneStatus = "Intune device entry has been deleted."
            }
        }

    <#
    $ap = Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -Filter "serialNumber eq 'PC04FTHD'"
    Remove-MgDeviceManagementWindowsAutopilotDeviceIdentity `
      -WindowsAutopilotDeviceIdentityId $ap.Id
    #>

    $entraDeviceId = $md.AzureAdDeviceId
    
    if($Delete){

        Remove-MgDevice -DeviceId $entraDeviceId
        If($Error){
            $EntraStatus = $Error[0].Exception
        }else{
            $EntraStatus = "Entra device entry has been deleted."
        }
    }

    $i++

    $Results += [PSCustomObject]@{
        
        Name = $Device.Device
        "Intune DeviceID" = $md.Id
        "Intune Status" = $IntuneStatus
        "Entra DeviceID" = $entraDeviceId
        "Entra Status" = $EntraStatus
    
    }
}

$Date = (Get-Date).ToString('yyyy-MM-dd')
$Results | Export-Csv IntuneDeviceDeletedReport-$Date.csv -NoTypeInformation -Encoding UTF8
