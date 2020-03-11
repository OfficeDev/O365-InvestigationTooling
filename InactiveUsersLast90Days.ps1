# Set and check for presence of -admin parameter holding admin UPN
param ($UPN)

If ($null -eq $UPN) {
  Write-Host "Script requires a -UPN parameter"
  exit
}

#Import MSOline Module
import-module MSOnline
#Import Exchange Online Module
Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA + "\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse).FullName | Where-Object{ $_ -notmatch "_none_" } | Select-Object -First 1)

#This connects to Azure Active Directory & Exchange Online
Connect-MsolService
$EXOSession = New-ExoPSSession -UserPrincipalName $UPN
Import-PSSession $EXOSession -AllowClobber

$startDate = (Get-Date).AddDays(-90).ToString('MM/dd/yyyy')
$endDate = (Get-Date).ToString('MM/dd/yyyy')

$allUsers = @()
$allUsers = Get-MsolUser -All -EnabledFilter EnabledOnly | Select-Object UserPrincipalName

$loggedOnUsers = @()
$loggedOnUsers = Search-UnifiedAuditLog -StartDate $startDate -EndDate $endDate -Operations UserLoggedIn, PasswordLogonInitialAuthUsingPassword, UserLoginFailed -ResultSize 5000

$inactiveInLastThreeMonthsUsers = @()
$inactiveInLastThreeMonthsUsers = $allUsers.UserPrincipalName | Where-Object {$loggedOnUsers.UserIds -NotContains $_}

Write-Output "The following users have not logged in for the last 90 days:"
Write-Output $inactiveInLastThreeMonthsUsers
