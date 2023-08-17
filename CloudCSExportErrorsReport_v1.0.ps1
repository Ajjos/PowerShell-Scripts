<#

.VERSION
    1.0
    16 August 2023 


.DESCRIPTION

    This script intends to extract out the affected Users and the corresponding error details from the Cloud Connector's Export errors XML file.

    It is provided as is without any support gauaratee of any sort.

    Please feel to make changes as required.

    Created By - Ajay Joshi 
    Github - https://github.com/Ajjos


.EXAMPLE
    
    Change the directory to the Script's location and run this:-
    ./CloudCSExportErrorsReport_v1.0.ps1

#>


<# Export the XML file from the AD Connect Server
cd  "C:\Program Files\Microsoft Azure AD Sync\bin"
.\CSExport.exe “CPGPLC - AAD” Errors-Export.xml /f:x

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

Write-Output "Please 'Browse' the CSV file with list of users"
$filepath = Get-FilePath
#>


# Load the XML into a PS variable
[XML]$ErrorsCloud = Get-Content .\Errors-Cloud.xml


#Declare custom PS Object
$Results=@()


$CSObjects = $ErrorsCloud.'cs-objects'.'cs-object'


For($i=0;$i -lt $CSObjects.Count;$i++){

$A = $CSObjects[$i].'synchronized-hologram'.'entry'.'attr' | Select name, value

$B = $CSObjects[$i].'export-errordetail'.'export-status'.'cd-error'.'error-name' 

$C = $CSObjects[$i].'export-errordetail'.'export-status'.'cd-error'.'error-literal'

$Results += [PSCustomObject]@{
		"Display Name" = ($A| ?{$_.name -eq "displayName"}).value
		"UPN" = ($A| ?{$_.name -eq "userPrincipalName"}).value
        "Email" = ($A| ?{$_.name -eq "mail"}).value
        "ObjectGUID" = ($A| ?{$_.name -eq "cloudAnchor"}).value
        "Error Type" = $B
        "Error Verbatim" = $C
	}
}

$Results | Export-Csv CloudCSExportErrorsReport.csv -NoTypeInformation