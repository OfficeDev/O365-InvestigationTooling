import-module MSOnline
 
#Let's get us an admin cred!
$userCredential = Get-Credential
 
#This connects to Azure Active Directory and passes admincreds
Connect-MsolService -Credential $userCredential
$ExoSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $userCredential -Authentication Basic -AllowRedirection
Import-PSSession $ExoSession
# Minus 90 Days from Today (Can Change to lower value)
$startDate = (Get-Date).AddDays(-90).ToString('MM/dd/yyyy')
#Todays current date
$endDate = (Get-Date).ToString('MM/dd/yyyy')
#Creates Array for Users
$allUsers = @()
#Uses Get-MsolUser cmdlet to get UPN
$allUsers = Get-MsolUser -All -EnabledFilter EnabledOnly | Select UserPrincipalName
#Creates another Array for dates
$loggedOnUsers = @()
$loggedOnUsers = Search-UnifiedAuditLog -StartDate $startDate -EndDate $endDate -Operations UserLoggedIn, PasswordLogonInitialAuthUsingPassword, UserLoginFailed -ResultSize 5000
#Creates Array for UPNs not included.
$inactiveUsers = @()
$inactiveUsers = $allUsers.UserPrincipalName | where {$loggedOnUsers.UserIds -NotContains $_}
#Prints Results
Write-Output "The following users have not logged in for the last 90 days:"
