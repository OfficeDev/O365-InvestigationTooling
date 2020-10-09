<#
.SYNOPSIS
  Use this script to look up the users who have not logged in for the last 90 days.
.PARAMETER UPN
  Specify an admin account to connect to Azure AD and Exchange Online
.PARAMETER Days
  Specify a duration to search - defaults to the last 90 days
#>
#This script requires the AzureAD and ExchangeOnlineManagement modules
#install them like this:
# Install-Module -Name AzureAD
# Install-Module -Name ExchangeOnlineManagement -RequiredVersion 1.0.1
param(
#Set admin UPN
  [string]$UPN = (Read-Host "Enter admin UPN (e.g. user@contoso.com)"),
  [int]$Days = 90
);
#Import AzureAD Module
Import-Module AzureAD
#Import Exchange Online Module
Import-Module ExchangeOnlineManagement

#This connects to Azure Active Directory & Exchange Online
Connect-AzureAD -AccountID $UPN;
$EXOSession = Connect-ExchangeOnline -UserPrincipalName $UPN;

$allUsers = @();
$allUsers = Get-AzureADUser -All $true -Filter "AccountEnabled eq true" | Select UserPrincipalName;

$batchSize = 5000;
$startDaysAgo = $Days;
$untilDaysAgo = 0;
$percentComplete = 0;

$count = 1;
$bc = 1;

$endDate = [datetime]::Now.Date.AddDays(-$untilDaysAgo);
$startDate = [datetime]::Now.Date.AddDays(-$startDaysAgo);

$loggedOnUsers = @();

  # Search the audit log for UserLoggedIn and PasswordLogonInitialAuthUsingPassword 
  #  events up to 5000 results, then page backwards through the dates until there
  #  are no more results
do {
  # Progress bar
  Write-Progress -Activity "Retreiving Data" -Status "Getting batch #$bc from $($startDate.ToString("yyyy-MM-dd")) to $($endDate.ToString("yyyy-MM-dd")) ($count of $startDaysAgo days)" -PercentComplete $percentComplete;

  # Search the audit log in batches of 5000 for logon events
  $data = Search-UnifiedAuditLog -StartDate $startDate -EndDate $endDate -Operations UserLoggedIn, PasswordLogonInitialAuthUsingPassword -ResultSize $batchSize;
	
  if ($data) { 
    $loggedOnUsers += $data; 
    $count = [int]($loggedOnUsers[0].CreationDate - $loggedOnUsers[$loggedOnUsers.Length - 1].CreationDate).TotalDays 
    $percentComplete = 100 * $count / $startDaysAgo;
    # If we have at least one full batchworth of users
    if ($loggedOnUsers.Length -ge $maxItems) {
      $bc++;
      # Set the new end date to our oldest record less a second
      $endDate = $loggedOnUsers[$loggedOnUsers.Length - 1].CreationDate.AddSeconds(-1);
    } 
  }

} while ($startDate -lt $endDate -and $data); # repeat whilst we keep getting results back
Write-Progress -Activity "Retreiving Data" -Completed;

$inactiveInLastThreeMonthsUsers = @();
# build a list of all users wihtout a login event in the specified date range
$inactiveInLastThreeMonthsUsers = $allUsers.UserPrincipalName | where { $loggedOnUsers.UserIds -NotContains $_ };

Write-Output "The following users have not logged in for the last $startDaysAgo days:"
Write-Output $inactiveInLastThreeMonthsUsers;

#Disconnect from Azure AD
Disconnect-AzureAD -Confirm:$false;
#Disconnect from EXO
Disconnect-ExchangeOnline -Confirm:$false;