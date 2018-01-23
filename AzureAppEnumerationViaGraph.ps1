#Only need to run these if you don't have ADAL installed
Install-PackageProvider -Name "NuGet"
Register-PackageSource -Name NuGet -ProviderName NuGet -location https://www.nuget.org/api/v2/
Get-PackageProvider -Name "NuGet" | Get-PackageSource
Install-Package -Name "Microsoft.IdentityModel.Clients.ActiveDirectory"

param
(
  [Parameter(Mandatory=$true)]
  $TenantName
)

function GetAuthToken
{
       param
       (
              [Parameter(Mandatory=$true)]
              $TenantName
       )
       $adal = "${env:ProgramFiles}\PackageManagement\NuGet\Packages\Microsoft.IdentityModel.Clients.ActiveDirectory.3.17.3\lib\net45\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
       [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
       $clientId = "1950a258-227b-4e31-a9cf-717495945fc2" 
       $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
       $resourceAppIdURI = "https://graph.windows.net"
       $authority = "https://login.windows.net/$TenantName"
       $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
       $authParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList 1
       $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI, $clientId, $redirectUri, $authParameters)

       return $authResult
}

#Go get an auth token for the correct domain
$token = GetAuthToken -TenantName $TenantName

# Building Rest Api header with authorization token
$authHeader = @{
   "Authorization" = $token.Result.CreateAuthorizationHeader()
   "Content-Type" = "application\json"
}

#Get all dem users
$userresource = "users"
$uri = "https://graph.windows.net/myorganization/$($userresource)?api-version=1.6"
$users = (Invoke-RestMethod -Uri $uri –Headers $authHeader –Method Get).value


#For each user, retrieve a list of all the oauth consent grants they have made
$consentgrants = @()
foreach ($user in $users)
{
    Write-Output "Getting consent grants for user: " $user.userPrincipalName
    $oauthconsentgrantresource = 'users/' + $user.userPrincipalName + '/oauth2PermissionGrants'
    $uri = "https://graph.windows.net/myorganization/$($oauthconsentgrantresource)?api-version=1.6"
    $consentgrants += (Invoke-RestMethod -Uri $uri –Headers $authHeader –Method Get).value
}

$appassingments = @()
foreach ($user in $users)
{
    Write-Output "Getting app assignments for user: " $user.userPrincipalName
    $appassignmentresource = 'users/' + $user.userPrincipalName + '/appRoleAssignments'
    $uri = "https://graph.windows.net/myorganization/$($appassignmentresource)?api-version=1.6"
    $appassignments += (Invoke-RestMethod -Uri $uri –Headers $authHeader –Method Get).value
}


#For each of the Assigned Applications, reduce the list to just the unique ones, then go get details about each of those applications
$assignedAppGUIDS = $appassignments.resourceId | sort -Unique

$appDetails = @();
foreach ($app in $assignedAppGUIDS)
{
    Write-Output "Getting app details for: " $app
    $appresource = "servicePrincipals" + "/" + $app
    $uri = "https://graph.windows.net/myorganization/$($appresource)?api-version=1.6"
    $appDetails += (Invoke-RestMethod -Uri $uri –Headers $authHeader –Method Get)
}

#These are all the users we pulled data for
$users | Export-Csv .\allusers_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation

#These are all the consent grant service principals in the directory for your users. Evaluate this to understand excessive scoped applications
$consentgrants | Export-Csv .\allconsentgrants_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation

#these are all the assigned applications privileges in the directory for your users. Evaluate this to understand when an app got access to your user's data
$appassignments | Export-Csv .\appassignments_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation

#These are details about all the apps that have assigned privileges. Evaluate this for suspicious URLs and names
$appDetails | Export-Csv .\allappdetails_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation
