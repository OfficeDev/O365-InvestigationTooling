Install-Module AzureAD
$AdminCred = Get-Credential
Connect-AzureAD -Credential $AdminCred

$users = Get-AzureADUser

$consentgrants = @()
foreach ($user in $users)
{
    Write-Output "Getting consent grants for user: " $user.userPrincipalName
    $consentgrants += Get-AzureADUserOAuth2PermissionGrant -ObjectId $user.UserPrincipalName
}

$appassignments = @()
foreach ($user in $users)
{
    Write-Output "Getting app assignments for user: " $user.userPrincipalName
    $appassignments += Get-AzureADUserAppRoleAssignment -ObjectId $user.UserPrincipalName
}


#For each of the Assigned Applications, reduce the list to just the unique ones, then go get details about each of those applications
$assignedAppGUIDS = $appassignments.resourceId | sort -Unique

$appDetails = @();
foreach ($app in $assignedAppGUIDS)
{
    Write-Output "Getting app details for: " $app
    $appDetails += Get-AzureADServicePrincipal -ObjectId $app
}

#These are all the users we pulled data for
$users | Export-Csv .\allusers_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation

#These are all the consent grant service principals in the directory for your users. Evaluate this to understand excessive scoped applications
$consentgrants | Export-Csv .\allconsentgrants_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation

#these are all the assigned applications privileges in the directory for your users. Evaluate this to understand when an app got access to your user's data
$appassignments | Export-Csv .\appassignments_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation

#These are details about all the apps that have assigned privileges. Evaluate this for suspicious URLs and names
$appDetails | Export-Csv .\allappdetails_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation






