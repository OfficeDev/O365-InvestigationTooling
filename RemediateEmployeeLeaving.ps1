###########################################################################
###########################################################################
###  Authors: Office 365 security (O365whitehat@microsoft.com)         ####
###  Remediate an employee leaving your company                        ####
###  Reference: https://support.office.com/en-US/                       ####
###  article/How-to-block-employee-access-to-Office-365-               ####
###  data-44d96212-4d90-4027-9aa9-a95eddb367d1?ui=en-US&rs=en-US&ad=US ####
###########################################################################

#######################################################################
######################### Functions ##################################
######################################################################



#This function reviews the execution policy setting to make sire it meets the requirement to run our script.
#Returns value of 0 if policy is correctly setup, otherwise it returns -1
Function ReviewExecutionPolicy()
{
    #Blocking 1 user access to Office 365 data
    #verifies Execution policies
    $adminExePol = Get-ExecutionPolicy
    #If execution policies are NOT SUPPORTED
    if(($adminExePol -eq "Restricted") -or ($adminExePol -eq "AllSigned"))
    {
        Write-Host "Your Execution policy does not allow to run this script." 
        Write-Host "Please open a new PowerShell window (Run as Administrator) and Set-ExecutionPolicy RemoteSigned."
        return -1
    }
    else 
    {
        return 0
    }
}

#Initiates Session for AAD/Azure, EXO & SPO
Function InitiateSession($domainName)
{
    ##Connect to Exchange
    #Office 365 credentials prompt
    $UserCredential = Get-Credential
    #Start new session to start using Exchange cmdlets
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
    Import-PSSession $Session
    ##connect to Azure
    Connect-MsolService
    ##Connect to SPO
    if($domainName -ne $null)
    {
        Connect-SPOService -Url https://$domainName-admin.sharepoint.com -credential $UserCredential
    }
    return  $UserCredential;
}


 Function BlockUser($upn)
 {
    Set-MsolUser –UserPrincipalName $upn –blockcredential $true
 }

  #Disable connections (OWA, ActiveSync, MAPI, IMAP & POP) of targeted user
 Function DisableUserConnections($upn)
 {
    
    Set-CASMailbox $upn -OWAEnabled $False -ActiveSyncEnabled $False –MAPIEnabled:$false -IMAPEnabled:$false -PopEnabled:$false 

 }




  Function GetUserDevices($upn)
 {
    ###Device Management###
    ##Need to be tested##
    #Get list of user devices
    $userMobileDevice = Get-MobileDevice -Mailbox $upn

   return $userMobileDevice

 }

Function RemoveDevices($usermobileDevice)
{

    if($userMobileDevice -eq $null)
    {
        return 0;
    }
    else 
    {
        $i = 0
        while($i -lt $userMobileDevice.length) 
        {
                Remove-MobileDevice -Identity $userMobileDevice[$i]
                $i++
        }
        return $1

    }
}

#Using c classic arrays, not best performance, should change to better implementation
Function GetUrlsOwned($upn)
{
    $sites = Get-SPOSite
    $urlsOwned = New-Object System.Collections.ArrayList

    for($i = 0; $i -lt $sites.length; $i++) 
    {
        if($sites[$i].Owner -eq $upn)
        {
            $urlsOwned.Add($sites[$i].url) > $null  
        }   

    }
    return $urlsOwned
}





Function AddNewOwnerToSiteCollection($collectionUrl,$newOwner)
{
    
    Set-SPOSite -Identity $collectionUrl -Owner $newOner -NoWait

}



Function RedirectEmail($redirectFrom, $redirectTo)
{ 

$currentDate = (Get-Date)
$rulename = "ForwardingEmail_"+$currentDate.Year+"-"+$currentDate.Month+"-"+$currentDate.Day+"_"+$currentDate.Hour+"-"+$currentDate.Minute+"-"+$currentDate.Second+"-"+$currentDate.Millisecond; 

New-TransportRule -Name $ruleName  -SentTo $redirectFrom -RedirectMessageTo $redirectTo

}


Function RemoveLicences($upn)
{
    $licenseObj = Get-MsolAccountSku 
    $license = $licenseObj.AccountSkuId
    Set-MsolUserLicense -UserPrincipalName $upn -RemoveLicenses $license 
    
 }  


Function RemoveUser($upn)
{
    Remove-MsolUser -UserPrincipalName $upn
}  






############################################################################
################   Main Script   ##########################################
###########################################################################


Write-Host "This PowerShell script was created by the Office 365 security team to help customers remediate the risk of an employee leaving the company." 
Write-Host "To learn more about to perform the same manually please take a look at:"
Write-Host "https://support.office.com/en-US/article/How-to-block-employee-access-to-Office-365-data-44d96212-4d90-4027-9aa9-a95eddb367d1?ui=en-US&rs=en-US&ad=US"
Write-Host " "
Write-Host "Please enter your name of your domain without the Top Level Domain (.com, .org, .net, etc.). "
Write-Host "For example if you work at contoso.com, please enter only Contoso"
$domainName = Read-Host -Prompt 'Domain Name (Without Top Level Domain)'
Write-Host "Enter your Admin Credentials, please note you will be prompted twice (One for O365 Exchange and one for AAD)"
#MyStart -domainName $domainName
ReviewExecutionPolicy
$adminCreds = InitiateSession -domainName $domainName

Write-Host "Please enter the User Principal Name (UPN) or Email of the target user (employee leaving)"
$upn = Read-Host -Prompt 'Target UPN/Email'

######## 1. ("Block employee access to Office 365 data")  ###########################


#Blocking User
Write-Host "Blocking User..."  
BlockUser -upn $upn 
Write-Host "Done"  


#Disabling user connections
Write-Host "Disabling user connections (OWA, ACtiveSync, MAPI, IMAP & POP)..."  
DisableUserConnections -upn $upn
Write-Host "Done"  

#Blocking user's devices (Important: this does not wipe their devices)
Write-Host "Removing User's devices..." 
$userdevices = GetUserDevices -upn $upn
$numberOfDevicesRemoved = RemoveDevices -usermobileDevice $userdevices
Write-Host "$numberOfDevicesRemoved devices found"
Write-Host "Done"  






##########  2. ("Get access to the data of the former employee")  ##############



####### 2.1  (Part 1 – Get access to the former employee’s OneDrive for Business documents) #######

Write-Host "Looking for SharePoint Site Collection owned by target user..."
$collectionUrls = GetUrlsOwned -upn $upn
Write-Host $collectionUrls
Write-Host "Adding your admin account as an owner..."
if($collectionUrls.length -gt 0)
{ 
    for($i=0;$i -lt $collectionUrls.length; $i++)
    {
        AddNewOwnerToSiteCollection -collectionUrl $collectionUrls[$i] -newOwner $adminCreds.username   
    }
}
else
{
    Write-Host "No SharePoint Site Collection found for the user"
    
}
Write-Host "Done"

 
#Note need to review if the previous step also identifies the personal user collection
##Identify personal users collection? my https://<company_name>-my.sharepoint.com/personal/<employee>_<company name>_onmicrosoft_com.


#Steps 2.2 - 2.4 are not available through any of the existing powershell cmdlets.


####   3.  Optional Send the former employee's new email to another employee

Write-Host "Redirecting all future emails to your account..."

RedirectEmail -redirectFrom $upn -redirectTo $adminCreds.username 


Write-Host "Done"
####   4 Remove license from employee
Write-Host "Removing former employee licences ..."
RemoveLicences -upn $upn 
Write-Host "Done"
####   5.    Delete the former employee's user account

Write-Host "Removing/Deleting user..."
RemoveUser -upn $upn
Write-Host "Done"


#####Done

## Provide user summary of actions taken by script
Write-Host "Below is a summary of all the actions provided by this script:"
Write-Host "1. Blocked target user"
Write-Host "2. Disabled user connections to OWA, ActiveSync, MAPI, IMAP and POP"
Write-Host "3. Blocked and removed user's mobile devices"
Write-Host "4. Got access to the former employee’s OneDrive for Business documents"
Write-Host "5. Future emails to former employees will be redirected to your account"
Write-Host "6. Remove Licenses of former employee"
Write-Host "7. Delete/Remove user account"
Write-Host "All Done!"



