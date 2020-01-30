#Import MSOline Module
 import-module MSOnline
 #Import Exchange Online Module
 Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA + "\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse).FullName | ?{ $_ -notmatch "_none_" } | select -First 1)


#Set admin UPN
$UPN = 'user@domain.com'

#This connects to Azure Active Directory & Exchange Online
Connect-MsolService
$EXOSession = New-ExoPSSession -UserPrincipalName $UPN
Import-PSSession $EXOSession -AllowClobber

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

