#Import the right module to talk with AAD
import-module MSOnline

#Let's get us an admin cred!
$userCredential = Get-Credential

#This connects to Azure Active Directory
Connect-MsolService -Credential $userCredential

#Connecting to Exchange Online
$ExoSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $userCredential -Authentication Basic -AllowRedirection
Import-PSSession $ExoSession -DisableNameChecking | Out-Null


#Let's Pull in the list of all GUIDS
$UserGuids = @()
$UserGuids = Import-Csv userguids.csv

$allUsers = @()

foreach ($guid in $UserGuids)
{
    $allUsers += Get-MsolUser -ObjectID $guid.ObjectId | select-Object ObjectID, UserPrincipalName, FirstName, LastName, StrongAuthenticationRequirements, StsRefreshTokensValidFrom, StrongPasswordRequired, LastPasswordChangeTimestamp 
}

$UserInboxRules = @()
$UserDelegates = @()

foreach ($User in $allUsers)
{
    Write-Host "Checking inbox rules and delegates for user: " $User.UserPrincipalName;
    $UserInboxRules += Get-InboxRule -Mailbox $User.UserPrincipalname | Select-Object @{Name='Mailbox';Expression={$user.UserPrincipalName}}, Name, Description, Enabled, Priority, ForwardTo, ForwardAsAttachmentTo, RedirectTo, DeleteMessage | Where-Object {($_.ForwardTo -ne $null) -or ($_.ForwardAsAttachmentTo -ne $null) -or ($_.RedirectsTo -ne $null)}
    $UserDelegates += Get-MailboxPermission -Identity $User.UserPrincipalName | Where-Object {($_.IsInherited -ne "True") -and ($_.User -notlike "*SELF*")}
}

$UserInboxRules | Export-Csv MailForwardingRulesToExternalDomains.csv
$UserDelegates | Export-Csv MailboxDelegatePermissions.csv
