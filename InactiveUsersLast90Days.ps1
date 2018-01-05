import-module MSOnline

#Let's get us an admin cred!
$userCredential = Get-Credential

#This connects to Azure Active Directory
Connect-MsolService -Credential $userCredential
$ExoSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $userCredential -Authentication Basic -AllowRedirection
Import-PSSession $ExoSession

$startDate = (Get-Date).AddDays(-90).ToString('MM/dd/yyyy')
$endDate = (Get-Date).ToString('MM/dd/yyyy')

$allUsers = @()
$allUsers = Get-MsolUser -All -EnabledFilter EnabledOnly | Select UserPrincipalName

$PageCounter=1 #Set it to 1 initially since we will start with the first page.
$loggedOnUsers = @()
Do{
    Write-Verbose -Message "Pulling Page $PageCounter"
    $loggedOnUsers += Search-UnifiedAuditLog -StartDate $startDate -EndDate $endDate -Operations UserLoggedIn, PasswordLogonInitialAuthUsingPassword, UserLoginFailed -ResultSize 5000 -SessionId "Inactive Users Report - 90 days" -SessionCommand ReturnNextPreviewPage
    $PageCounter++
}While($loggedOnUsers.count%5000 -eq 0) #Since the command will return 5000 results at once, the modulo should always be 0 until we get the last set.

$inactiveInLastThreeMonthsUsers = @()
$inactiveInLastThreeMonthsUsers = $allUsers.UserPrincipalName | where {$loggedOnUsers.UserIds -NotContains $_}

Write-Output "The following users have no logged in for the last 90 days:"
Write-Output $inactiveInLastThreeMonthsUsers

