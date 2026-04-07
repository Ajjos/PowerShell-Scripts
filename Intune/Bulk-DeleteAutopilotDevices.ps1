##############################################################
#  Intune Device Deletion Script
#  Covers:
#   - Intune device entries
#   - Entra device entries
#   - Autopilot device entries
#
#  Uses Get-MgDeviceManagementManagedDevice to get Intune & Entra device entries using Device name.
#  Uses Get-MgDeviceManagementWindowsAutopilotDeviceIdentity to get the Autopilot entry using Entra Device Id
#  Cleans up device entries across Intune >> Autopilot >> Entra devices in this exact order. 
#
#  Input: Browse CSV file with "Device" column. 
#  Output: CSV Report with Name, Intune DeviceID, Intune Status, AutopilotId, AutopilotStatus, Entra DeviceID & Entra Status columns
##############################################################


param (
    [Parameter(Mandatory = $true)]
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

$devices = Import-Csv $filepath
$results = @()

foreach ($item in $devices) {

    $deviceName = $item.Device
    Write-Host "`n=== Processing device: $deviceName ===" -ForegroundColor Cyan

    $row = [ordered]@{
        DeviceName = $deviceName

        IntuneStatus     = "Not Found"
        IntuneDeviceId   = ""

        AutopilotStatus  = "Not Found"
        AutopilotId      = ""

        EntraStatus      = "Not Found"
        EntraDeviceId    = ""
    }

    # -------------------------------
    # Intune Managed Device
    # -------------------------------
    $md = Get-MgDeviceManagementManagedDevice `
            -Filter "deviceName eq '$deviceName'" `
            -ErrorAction SilentlyContinue

    if ($md) {
        $row.IntuneDeviceId = $md.Id
        $row.EntraDeviceId  = $md.AzureAdDeviceId
        $row.IntuneStatus   = "Found"

        if ($Delete) {
            Remove-MgDeviceManagementManagedDevice `
                -ManagedDeviceId $md.Id `
                -ErrorAction Stop
            $row.IntuneStatus = "Deleted"
        }
    }

    # -------------------------------
    # Autopilot Device (linked via Entra ID)
    # -------------------------------
    if ($row.EntraDeviceId) {
        $ap = Get-MgDeviceManagementWindowsAutopilotDeviceIdentity `
                -Filter "AzureActiveDirectoryDeviceId eq '$($row.EntraDeviceId)'" `
                -ErrorAction SilentlyContinue

        if ($ap) {
            $row.AutopilotId = $ap.Id
            $row.AutopilotStatus = "Found"

            if ($Delete) {
                Remove-MgDeviceManagementWindowsAutopilotDeviceIdentity `
                    -WindowsAutopilotDeviceIdentityId $ap.Id `
                    -ErrorAction Stop
                $row.AutopilotStatus = "Deleted"
            }
        }
    }

    # -------------------------------
    # Entra Device (exact corresponding)
    # -------------------------------
    if ($row.EntraDeviceId) {
        $entra = Get-MgDevice `
                    -DeviceId $row.EntraDeviceId `
                    -ErrorAction SilentlyContinue

        if ($entra) {
            $row.EntraStatus = "Found"

            if ($Delete) {
                Remove-MgDevice `
                    -DeviceId $entra.Id `
                    -ErrorAction Stop
                $row.EntraStatus = "Deleted"
            }
        }
    }

    $results += New-Object psobject -Property $row
}

# -------------------------------
# Final report
# -------------------------------
Write-Host "`n=== Cleanup Summary ===" -ForegroundColor Green
$results | Format-Table -AutoSize

# Optional: export report
$Date = (Get-Date).ToString('yyyy-MM-dd')
$results | Export-Csv ".\AutopilotDeletionReport-$Date.csv" -NoTypeInformation
