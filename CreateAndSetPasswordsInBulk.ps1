#Load "System.Web" assembly in PowerShell console 
[Reflection.Assembly]::LoadWithPartialName("System.Web") 

#Import the right module to talk with AAD
import-module MSOnline

#Let's get us an admin cred!
$userCredential = Get-Credential

#This connects to Azure Active Directory
Connect-MsolService -Credential $userCredential


#Let's Pull in the list of all GUIDS
$UserGuids = @()
$UserGuids = Import-Csv userguids.csv

#Add a new column in the data to hold the new account password
$UserGuids | Add-Member -MemberType NoteProperty -Name 'NewPassword' -Value $null
foreach ($user in $UserGuids)
{
    $user.NewPassword = ([System.Web.Security.Membership]::GeneratePassword(16,2))
}

$UserGuids | Export-Csv GuidsWithPasswords.csv

foreach ($guid in $UserGuids)
{
    Write-Host "Setting the password for " $guid.ObjectId;
    Set-MsolUserPassword –ObjectId $guid.ObjectId –NewPassword $guid.NewPassword -ForceChangePassword $True
}
