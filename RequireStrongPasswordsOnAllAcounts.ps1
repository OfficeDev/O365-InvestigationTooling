#This script will require all of your users to use a strong password, including the below criteria:
#The password must contain at least one lowercase letter
#The password must contain at least one uppercase letter
#The password must contain at least one non-alphanumeric character
#The password cannot contain any spaces, tabs, or line breaks
#The length of the password must be 8-16 characters
#The user name cannot be contained in the password

$transcriptpath = ".\" + "RequireStrongPasswordsTranscript" + (Get-Date).ToString('yyyy-MM-dd') + ".txt"
Start-Transcript -Path $transcriptpath

#Import the right module to talk with AAD
import-module MSOnline

#First, let's get us a cred!
$adminCredential = Get-Credential

#This connects to Azure Active Directory
Connect-MsolService -Credential $adminCredential

#Go get all them users
$allUsers = @()
$allUsers = Get-MsolUser -All -EnabledFilter EnabledOnly | select ObjectID, UserPrincipalName, FirstName, LastName, StrongAuthenticationRequirements, StsRefreshTokensValidFrom, StrongPasswordRequired, LastPasswordChangeTimestamp | Where-Object {($_.UserPrincipalName -notlike "*#EXT#*")}

#Iterate through the list and require a strong password
foreach ($User in $allUsers)
{
    $thisUser = $User.UserPrincipalName
    Write-Host "Configuring user to use a strong password: " $thisUser;
    Set-MsolUser -UserPrincipalName $thisUser -StrongPasswordRequired $true
}

Write-Output "And just to double check, here is the current state of strong password enablement in your tenancy: "

#Double checkin'!
foreach ($User in $allUsers)
{
    Get-MsolUser -UserPrincipalName $User.UserPrincipalName | select UserPrincipalName, StrongPasswordRequired
}

Stop-Transcript
