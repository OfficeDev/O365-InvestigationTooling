#This script requires the AzureAD and ExchangeOnlineManagement modules
#install them like this:
# Install-Module -Name AzureAD
# Install-Module -Name ExchangeOnlineManagement -RequiredVersion 1.0.1

#Import AzureAD Module
Import-Module AzureAD
#Import Exchange Online Module
Import-Module ExchangeOnlineManagement

#Set admin UPN
$UPN = 'user@domain.com'

#This connects to Azure Active Directory & Exchange Online
Connect-AzureAD -AccountID $UPN
$EXOSession = Connect-ExchangeOnline -UserPrincipalName $UPN

$startDate = (Get-Date).AddDays(-90).ToString('MM/dd/yyyy')
$endDate = (Get-Date).ToString('MM/dd/yyyy')

$allUsers = @()
$allUsers = Get-AzureADUser -All $true -Filter "AccountEnabled eq true" | Select UserPrincipalName

$loggedOnUsers = @()
$loggedOnUsers = Search-UnifiedAuditLog -StartDate $startDate -EndDate $endDate -Operations UserLoggedIn, PasswordLogonInitialAuthUsingPassword, UserLoginFailed -ResultSize 5000

$inactiveInLastThreeMonthsUsers = @()
$inactiveInLastThreeMonthsUsers = $allUsers.UserPrincipalName | where {$loggedOnUsers.UserIds -NotContains $_}

Write-Output "The following users have no logged in for the last 90 days:"
Write-Output $inactiveInLastThreeMonthsUsers

#Disconnect from EXO
Disconnect-ExchangeOnline
