#########################################
# AzureAppEnumeration.ps1
# 
# Dumps all users, consent grants, assign apps, and app details in an Office 365 tenancy
# Script requires user with Global Admin role assignment
#
#########################################

#Install the AzureAD module
Install-Module AzureAD
#Prompt the user for a credential of an admin user
$AdminCred = Get-Credential
Connect-AzureAD -Credential $AdminCred

#Get all users in order to figure out which users have which app permissions assigned
$users = Get-AzureADUser

#Retrieve a list of all the oauth consent grants that have been made in the tenancy
$allconsentgrants = Get-AzureADOAuth2PermissionGrant

# This will retrieve consent grants for each individual, but will end up missing the admin consent grants.
#$consentgrants = @()
#foreach ($user in $users)
#{
#    Write-Output "Getting consent grants for user: " $user.userPrincipalName
#    $consentgrants += Get-AzureADUserOAuth2PermissionGrant -ObjectId $user.UserPrincipalName
#}

#For each user, go get a list of all the app permission assignments for that user
$appassignments = @()
foreach ($user in $users)
{
    Write-Output "Getting app assignments for user: " $user.userPrincipalName
    $appassignments += Get-AzureADUserAppRoleAssignment -ObjectId $user.UserPrincipalName
}


#For each of the Assigned Applications, reduce the list to just the unique ones, then go get details about each of those applications
$assignedAppGUIDS = $appassignments.resourceId | sort -Unique

#For each application with permissions, go get details about that application
$appDetails = @();
foreach ($app in $assignedAppGUIDS)
{
    Write-Output "Getting app details for: " $app
    $appDetails += Get-AzureADServicePrincipal -ObjectId $app
}

#These are all the users we pulled data for
$users | Export-Csv .\allusers_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation

#These are all the consent grant service principals in the directory for your users. Evaluate this to understand excessive scoped applications
$allconsentgrants | Export-Csv .\allconsentgrants_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation

#these are all the assigned applications privileges in the directory for your users. Evaluate this to understand when an app got access to your user's data
$appassignments | Export-Csv .\appassignments_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation

#These are details about all the apps that have assigned privileges. Evaluate this for suspicious URLs and names
$appDetails | Export-Csv .\allappdetails_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation
