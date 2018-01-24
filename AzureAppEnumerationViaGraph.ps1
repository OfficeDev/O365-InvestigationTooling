#########################################
# AzureAppEnumerationViaGraph.ps1
# 
# Dumps all users, consent grants, assign apps, and app details in an Office 365 tenancy
# Script requires user with Global Admin role assignment
#
#########################################
param
(
  [Parameter(Mandatory=$true)]
  $TenantName
)

#Let's see if you have ADAL installed and if not, give you some commands to run to get it installed
$p = Get-Package -Name "Microsoft.IdentityModel.Clients.ActiveDirectory"
if ($p -ne $null) { Write-Output "Great, looks like you have the correct package dependencies installed."}
else 
{
    Write-Output "Looks like you need to install the Active Directory Authentication Library. Please run the following commands in an admininstrator elevated powershell window: "
    Write-Output 'Install-PackageProvider -Name NuGet"'
    Write-Output 'Register-PackageSource -Name NuGet -ProviderName NuGet -location https://www.nuget.org/api/v2/'
    Write-Output 'Get-PackageProvider -Name "NuGet" | Get-PackageSource'
    Write-Output 'Install-Package -Name "Microsoft.IdentityModel.Clients.ActiveDirectory"'
}


       
#This function will acquire an OAuth token to authorize the graph api calls
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

#Get all users in order to figure out which users have which app permissions assigned
$userresource = "users"
$uri = "https://graph.windows.net/myorganization/$($userresource)?api-version=1.6"
$users = (Invoke-RestMethod -Uri $uri –Headers $authHeader –Method Get).value


#Retrieve a list of all the oauth consent grants that have been made in the tenancy
$allconsentgrants = @()
$oauthconsentgrantresource = 'oauth2PermissionGrants'
$uri = "https://graph.windows.net/myorganization/$($oauthconsentgrantresource)?api-version=1.6"
$allconsentgrants = (Invoke-RestMethod -Uri $uri –Headers $authHeader –Method Get).value

# This will retrieve consent grants for each individual, but will end up missing the admin consent grants.
#$consentgrants = @()
#foreach ($user in $users)
#{
#    Write-Output "Getting consent grants for user: " $user.userPrincipalName
#    $oauthconsentgrantresource = 'users/' + $user.userPrincipalName + '/oauth2PermissionGrants'
#    $uri = "https://graph.windows.net/myorganization/$($oauthconsentgrantresource)?api-version=1.6"
#    $consentgrants += (Invoke-RestMethod -Uri $uri –Headers $authHeader –Method Get).value
#}

#For each user, go get a list of all the app permission assignments for that user
$appassignments = @()
foreach ($user in $users)
{
    Write-Output "Getting app assignments for user: " $user.userPrincipalName
    $appassignmentresource = 'users/' + $user.userPrincipalName + '/appRoleAssignments'
    $uri = "https://graph.windows.net/myorganization/$($appassignmentresource)?api-version=1.6"
    $appassignments += (Invoke-RestMethod -Uri $uri –Headers $authHeader –Method Get).value
}

#For each of the Assigned Applications, reduce the list to just the unique ones, then go get details about each of those applications
$assignedAppGUIDS = $appassignments.resourceId | sort -Unique

#For each application with permissions, go get details about that application
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
$allconsentgrants | Export-Csv .\allconsentgrants_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation

#these are all the assigned applications privileges in the directory for your users. Evaluate this to understand when an app got access to your user's data
$appassignments | Export-Csv .\appassignments_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation

#These are details about all the apps that have assigned privileges. Evaluate this for suspicious URLs and names
$appDetails | Export-Csv .\allappdetails_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation

