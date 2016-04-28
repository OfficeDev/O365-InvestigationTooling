#Import the right module to talk with AAD
import-module MSOnline

#Let's get us an admin cred!
$userCredential = Get-Credential

#This connects to Azure Active Directory
Connect-MsolService -Credential $userCredential

############### Used to Generate list of test GUIDs to work with ####################################
#Let's go get all the real users and their attributes from AAD
$MyGuids = @()
$MyGuids = Get-MsolUser -All -EnabledFilter EnabledOnly | select ObjectID | Where-Object {($_.UserPrincipalName -notlike "*#EXT#*")}
#Let's DUmp a list of all GUIDs in the tenancy
$MyGuids | Export-Csv userguids.csv
#####################################################################################################

#Let's Pull in the list of all GUIDS
$UserGuids = @()
$UserGuids = Import-Csv userguids.csv

$AllUsers = @()

foreach ($guid in $UserGuids)
{
    $AllUsers += Get-MsolUser -ObjectID $guid.ObjectId | select ObjectID, UserPrincipalName, FirstName, LastName, StrongAuthenticationRequirements, StsRefreshTokensValidFrom, StrongPasswordRequired, LastPasswordChangeTimestamp 
}

#Dump the Full Fidelity List of Users to a CSV
$AllUsers | Export-Csv UserDetail.csv
