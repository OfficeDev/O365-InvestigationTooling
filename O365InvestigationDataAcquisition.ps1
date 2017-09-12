
function Check-AzureSetup 
{
    $setupBlocked = $false
    #Check Azure
    if(-not(Get-Module -ListAvailable | Where-Object {$_.Name -eq "Azure"}))
    {
        Write-Output "You don't appear to have Azure Powershell Modules installed on this computer. Here are the instructions and download to install. Install, then re-run the investigations tooling." 
        start "https://azure.microsoft.com/en-us/documentation/articles/powershell-install-configure/"
        #start "http://go.microsoft.com/fwlink/p/?linkid=320376&clcid=0x409"
        start "http://go.microsoft.com/?linkid=9811175&clcid=0x409"
        $setupBlocked = $true
    }
    else
    {
        try 
        {
        	$azurePSRoot="C:\Program Files (x86)\Microsoft SDKs\Azure\Powershell"
            $azureServiceManagementModule= $azurePSRoot + "\ServiceManagement\Azure\Azure.psd1"
            Write-Output "Checking Azure Service Management module: $azureServiceManagementModule"
            Write-Output "Looking good!"
            Import-Module $azureServiceManagementModule

        }
        catch
        {
            $setupBlocked = $true
        }
    }

    if ($setupBlocked -eq $true)
    {
        Write-Output "Something with your configuration is amiss, and your Secure Score collection will likely fail. Please review the logs above and correct any issues with your local client configuration."
        break;
    }
    else
    {

        Write-Output "Connecting to Azure"
        $AdminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $globalConfig.AzureAccountName, ($globalConfig.AzureAccountSecureString | ConvertTo-SecureString)
        #Get-Credential -Message "Provide Admin Creds to Connect to Azure Services."
        Add-AzureAccount -Credential $AdminCredential

        Write-Output "Setting the correct environment settings, creating a new storage account, and a new storage container for our blobs."
        Select-AzureSubscription -SubscriptionName $globalConfig.AzureBlobSubscription

        $AzureStorageAccountName = Get-AzureStorageAccount
        if ($AzureStorageAccountName -ne $globalConfig.AzureBlobStorageAccountName) { New-AzureStorageAccount -StorageAccountName $globalconfig.AzureBlobStorageAccountName -Location "West US"; }

        #$AzureSubscription = Get-AzureSubscription
        Set-AzureSubscription -CurrentStorageAccountName $globalConfig.AzureBlobStorageAccountName -SubscriptionName $globalConfig.AzureBlobSubscription
        
        $AzureStorageContainers = Get-AzureStorageContainer
        if ($AzureStorageContainers -ne $globalConfig.AzureBlobContainerName) { New-AzureStorageContainer -Name $globalConfig.AzureBlobContainerName -Permission Off; }
        Write-Output "Everything looks good to go with your azure setup. You've got a storage account and a blob container ready to go."
    }
}


Function Get-GlobalConfig( $configFile)
{
    Write-Output "Loading Global Config File"
    
    $config = Get-Content $globalConfigFile -Raw | ConvertFrom-Json
    
    return $config;
}

$globalConfigFile=".\ConfigForO365Investigations.json";
$globalConfig = Get-GlobalConfig $globalConfigFile

#Pre-reqs for REST API calls
$ClientID = $globalConfig.InvestigationAppId
$ClientSecret = $globalConfig.InvestigationAppSecret
$loginURL = $globalConfig.LoginURL
$tenantdomain = $globalConfig.InvestigationTenantDomain
$TenantGUID = $globalConfig.InvestigationTenantGUID
$resource = $globalConfig.ResourceAPI

# Get an Oauth 2 access token based on client id, secret and tenant domain
$body = @{grant_type="client_credentials";resource=$resource;client_id=$ClientID;client_secret=$ClientSecret}
$oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body

#Let's put the oauth token in the header, where it belongs
$headerParams  = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"}

#Instantiate our enumerators
$apiFilters = @()
$rawData = @()
$dayofData = @()
$dateRange = @()
$days = @()

if ($globalConfig.DateToPull){
    $days = $globalConfig.DateToPull
}
else
{
    for ($i = [int]$globalConfig.NumberOfDaysToPull; $i -gt 0; $i--)
    {
        $days += (Get-Date).AddDays(-$i).ToString('yyyy-MM-dd')        
    }
    $days += (Get-Date).ToString('yyyy-MM-dd')

}

$hours = @("00:00Z", "01:00Z", "02:00Z", "03:00Z", "04:00Z", "05:00Z", "06:00Z", "07:00Z", "08:00Z", "09:00Z", "10:00Z", "11:00Z", "12:00Z", "13:00Z", "14:00Z", "15:00Z", "16:00Z", "17:00Z", "18:00Z", "19:00Z", "20:00Z", "21:00Z", "22:00Z", "23:00Z", "23:59:59Z")
foreach ($day in $days) { foreach ($hour in $hours) { $dateRange += $day + "T" + $hour; }}

$workLoads = @("Audit.AzureActiveDirectory", "Audit.Exchange", "Audit.SharePoint", "Audit.General", "DLP.All")
$subs = @()
$global:blobs = @()
$wlCount = @()
$dayCount = @()
$thisBlobdata = @()
$altFormat = @()
$SPOmegaBlob = @()
$EXOmegaBlob = @()
$AADmegaBlob = @()
$Query = @()
$rawRef = @()


#Let's make sure we have the Activity API subscriptions turned on
$subs = Invoke-WebRequest -Headers $headerParams -Uri "https://manage.office.com/api/v1.0/$tenantGUID/activity/feed/subscriptions/list" | Select Content

if (!$subs -or $subs.Content -eq "[]")
{
    Write-Host "Looks like we need to turn on your subscriptions now."
    Write-Host "#####################################################"
                
    #Let's make sure the subscriptions are started
    foreach ($wl in $workLoads)
        {
            Invoke-RestMethod -Method Post -Headers $headerParams -Uri "https://manage.office.com/api/v1.0/$tenantGUID/activity/feed/subscriptions/start?contentType=$wl"
        }
        
    Write-Host "#####################################################"

}

#Let's go get some datums! First, let's construct some query parameters
foreach ($wl in $workLoads)
{
    for ($i = 0; $i -lt $dateRange.Length -1; $i++)
    {
        $apiFilters += "?contentType=$wl&startTime=" + $dateRange[$i] + "&endTime=" + $dateRange[$i+1]
    }
}

#foreach ($wl in $workLoads)
#{
#    for ($i = 0; $i -lt $days.Length -1; $i++)
#    {
#        $apiFilters += "?contentType=$wl&startTime=" + $days[$i] + "&endTime=" + $days[$i+1]
#    }
#}


#Then execute the content enumeration method per workload, per day
foreach ($pull in $apiFilters)
{
    $rawRef = Invoke-WebRequest -Headers $headerParams -Uri "https://manage.office.com/api/v1.0/$tenantGUID/activity/feed/subscriptions/content$pull"
    if ($rawRef.Headers.NextPageUri) 
    {
        $pageTracker = $true
        $thatRabbit = $rawRef
        while ($pageTracker -ne $false)
        {
        	$thisRabbit = Invoke-WebRequest -Headers $headerParams -Uri $thatRabbit.Headers.NextPageUri
            Write-Output "We just called a rabbit: " $thatRabbit.Headers.NextPageUri
			$rawData += $thisRabbit

			If ($thisRabbit.Headers.NextPageUri)
			{
				$pageTrack = $True
			}
			Else
            {
			    $pageTracker = $False
			}
            $thatRabbit = $thisRabbit
        }
    }

    $rawData += $rawRef
    Write-Output "We just called $pull"
    Write-Output "---"
}


#Then convert each day's package into discrete blob calls
foreach ($dayofData in $rawData)
{
    $blobs += $dayofData.Content | ConvertFrom-Json
}

Write-Host "#####################################################"
Write-Host "You have this many total blobs in your Activity API: " -NoNewline; Write-Host $blobs.Count -ForegroundColor Green

foreach ($day in $days)
{
    $dayCount = @($blobs | Where-Object {($_.contentCreated -match $day)})
    Write-Host "Count of blobs on " -NoNewline; Write-Host $day -NoNewLine; Write-Host " : " -NoNewLine; Write-Host $dayCount.Count -ForegroundColor Green
}

foreach ($wl in $workLoads)
{
    $wlCount = @($blobs | Where-Object {($_.contentType -eq $wl)})
    Write-Host "Count of blobs for " -NoNewline; Write-Host $wl -NoNewLine; Write-Host " : " -NoNewLine; Write-Host $wlCount.Count -ForegroundColor Green

}

#This will write the files from the API to the local data store.
function Export-LocalFiles ($blobs) {
    #Let's make some output directories
    if (! (Test-Path ".\JSON"))
        {
            New-Item -Path .\JSON -ItemType Directory
        }

    if (! (Test-Path ".\CSV"))
        {
            New-Item -Path .\CSV -ItemType Directory
        }

    #Let's build a variable full of the files already in the local store
    $localfiles = @()
    $localFiles = Get-ChildItem $globalConfig.LocalFileStore -Recurse | Select-Object -Property Name
    

    $body = @{grant_type="client_credentials";resource=$resource;client_id=$ClientID;client_secret=$ClientSecret}
    $oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body
    $oauthExpiration = [datetime]::Now.AddSeconds($oauth.expires_in)

    #Let's put the oauth token in the header, where it belongs
    $headerParams  = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"}

    
    #Go Get the Content!
    for ($i = 0; $i -le $blobs.Length -1; $i++) 
    { 
        $timeleft = $oauthExpiration - [datetime]::Now
        if ($timeLeft.TotalSeconds -lt 100) 
        {
            Write-Host "Nearing token expiration, acquiring a new one."; 
            $oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body; 
            $headerParams  = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"}; 
            $oauthExpiration = [datetime]::Now.AddSeconds($oauth.expires_in); 
            Write-Host "New token lifespan is $oauthExpiration"; 
        }
            
        if ($localFiles -like "*" + $blobs[$i].contentId + "*") 
        { 
            Write-Output "Looks like we already have this blob locally."; 
        }
        else
        {
            #Get the datums
            $thisBlobdata = Invoke-WebRequest -Headers $headerParams -Uri $blobs[$i].contentUri
        
            #Write it to JSON
            $thisBlobdata.Content | Out-File (".\JSON\" + $blobs[$i].contentType + $blobs[$i].contentCreated.Substring(0,10) + "--" + $blobs[$i].contentID + ".json")
        
            #Write it to CSV
            $altFormat = $thisBlobdata.Content | ConvertFrom-Json
            $altFormat | Export-Csv -Path (".\CSV\" + $blobs[$i].contentType + $blobs[$i].contentCreated.Substring(0,10) + "--" + $blobs[$i].contentID + ".csv") -NoTypeInformation

            Write-Host "Writing file #: " -NoNewLine; Write-Host ($i + 1) -ForegroundColor Green -NoNewline; Write-Host " out of " -NoNewline; Write-Host $blobs.Length -ForegroundColor Yellow -NoNewline; Write-Host ". You have " -NoNewline; Write-Host ($timeleft.TotalSeconds) -NoNewline; Write-Host " seconds left on your oauth token lifespan.";  

        }

    }

}


function Invoke-MySQL {
    Param(
      [Parameter(
      Mandatory = $true,
      ParameterSetName = '',
      ValueFromPipeline = $true)]
      [string]$Query
      )

    $MySQLAdminUserName = $globalConfig.MySqlUserName
    $MySQLAdminPassword = $globalConfig.MySqlPass
    $MySQLDatabase = $globalConfig.MySqlDb
    $MySQLHost = $globalConfig.MySqlHostname

    $ConnectionString = "server=" + $MySQLHost + "; port=3306; uid=" + $MySQLAdminUserName + "; pwd=" + $MySQLAdminPassword + "; database="+$MySQLDatabase

    Try {
      [void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
      $Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
      $Connection.ConnectionString = $ConnectionString
      $Connection.Open()
  
      $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
      $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
      $DataSet = New-Object System.Data.DataSet
      $RecordCount = $dataAdapter.Fill($dataSet, "data")
      $DataSet.Tables[0]
      }

    Catch {
      throw "ERROR : Unable to run query : $query `n$Error[0]"
     }

    Finally {
      $Connection.Close()
      }
 }

 function Invoke-AzureSql {
     Param(
      [Parameter(
      Mandatory = $true,
      ParameterSetName = '',
      ValueFromPipeline = $true)]
      [string]$Query
      )

    $AzureSqlAdminUserName = $globalConfig.AzureSqlUsername
    $AzureSqlAdminPassword = $globalConfig.AzureSqlPass
    $AzureSqlDatabase = $globalConfig.AzureSqlDb
    $AzureSqlHost = $globalConfig.AzureSqlHostname
 
    $ConnectionString = "server=" + $AzureSqlHost + ",1433; uid=" + $AzureSqlAdminUserName + "; pwd=" + $AzureSqlAdminPassword + "; database="+$AzureSqlDatabase
 
    Try {
      
      $Connection = New-Object System.Data.SqlClient.SqlConnection
      $Connection.ConnectionString = $ConnectionString
      $Connection.Open()
  
      $Command = New-Object System.Data.SqlClient.SqlCommand($Query, $Connection)
      $DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($Command)

      $DataSet = New-Object System.Data.DataSet
      $RecordCount = $dataAdapter.Fill($dataSet, "data")
      $DataSet.Tables[0]
      }

    Catch {
      throw "ERROR : Unable to run query : $query `n$Error[0]"
     }

    Finally {
      $Connection.Close()
      }
 }


function Export-MySQL ($blobs) {

    #Need to create the o365investigations database before we make sure there are tables in there

    #Make sure we've got tables
    Invoke-MySQL -Query "CREATE TABLE IF NOT EXISTS auditsharepoint (CreationTime DATETIME, Id CHAR(36) NOT NULL, Operation TEXT, OrganizationId TEXT, RecordType INT, UserKey TEXT, UserType INT, Workload TEXT, ClientIP TEXT, ObjectId TEXT, UserId TEXT, EventSource TEXT, ItemType TEXT, Site TEXT, UserAgent TEXT, SourceFileExtension TEXT, SiteUrl TEXT, SourceFileName TEXT, SourceRelativeUrl TEXT, PRIMARY KEY (Id))"
    Invoke-MySQL -Query "CREATE TABLE IF NOT EXISTS auditexchange (CreationTime DATETIME, Id CHAR(36) NOT NULL, Operation TEXT, OrganizationId TEXT, RecordType INT, ResultStatus TEXT, UserKey TEXT, UserType INT, Workload TEXT, ObjectId TEXT, UserId TEXT, ExternalAccess TEXT, OrganizationName TEXT, OriginatingServer TEXT, Parameters TEXT, PRIMARY KEY (Id))"
    Invoke-MySQL -Query "CREATE TABLE IF NOT EXISTS auditaad (CreationTime DATETIME, Id CHAR(36) NOT NULL, Operation TEXT, OrganizationId TEXT, RecordType INT, ResultStatus TEXT, UserKey TEXT, UserType INT, Workload TEXT, ClientIP TEXT, ObjectId TEXT, UserId TEXT, AzureActiveDirectoryEventType TEXT, Client TEXT, LoginStatus TEXT, UserDomain TEXT, PRIMARY KEY (Id))"

    $body = @{grant_type="client_credentials";resource=$resource;client_id=$ClientID;client_secret=$ClientSecret}
    $oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body
    $oauthExpiration = [datetime]::Now.AddSeconds($oauth.expires_in)

    #Let's put the oauth token in the header, where it belongs
    $headerParams  = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"}

    #Go Get the Content!
    for ($i = 0; $i -le $blobs.Length -1; $i++) 
    { 
        $timeleft = $oauthExpiration - [datetime]::Now
        if ($timeLeft.TotalSeconds -lt 100) 
        {
            Write-Host "Nearing token expiration, acquiring a new one."; 
            $oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body; 
            $headerParams  = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"}; 
            $oauthExpiration = [datetime]::Now.AddSeconds($oauth.expires_in); 
            Write-Host "New token lifespan is $oauthExpiration"; 
        }
        #Get the datums
        $thisBlobdata = Invoke-WebRequest -Headers $headerParams -Uri $blobs[$i].contentUri
        
        #Get it into a more work-able format
        $altFormat = $thisBlobdata.Content | ConvertFrom-Json

        if ($blobs[$i].ContentType -eq "Audit.SharePoint") { $SPOmegaBlob += $altFormat; }
        if ($blobs[$i].ContentType -eq "Audit.Exchange") { $EXOmegaBlob += $altFormat; }
        if ($blobs[$i].ContentType -eq "Audit.AzureActiveDirectory") { $AADmegaBlob += $altFormat; }

    }
    #Stick all the records in this megablob into a SQL database
    foreach ($record in $SPOmegaBlob)
    {
        #Construct the query to a valid string, then execute that sucker
        #Need to handle the parameters object by converting to a string.
        $thisQuery = "INSERT IGNORE INTO auditsharepoint (CreationTime, Id, Operation, OrganizationId, RecordType, UserKey, UserType, Workload, ClientIP, ObjectId, UserId, EventSource, ItemType, Site, UserAgent, SourceFileExtension, SiteUrl, SourceFileName, SourceRelativeUrl) VALUES ('" + $record.CreationTime + "', '" + $record.Id + "', '" + $record.Operation + "', '" + $record.OrganizationId + "', '" + $record.RecordType + "', '" + $record.UserKey + "', '" + $record.UserType + "', '" + $record.Workload + "', '" + $record.ClientIP + "', '" + $record.ObjectId + "', '" + $record.UserId + "', '" + $record.EventSource + "', '" + $record.ItemType + "', '" + $record.Site + "', '" + $record.UserAgent + "', '" + $record.SourceFileExtension + "', '" + $record.SiteUrl + "', '" + $record.SourceFileName + "', '" + $record.SourceRelativeUrl + "')"
        Invoke-MySQL "$thisQuery"
        Write-Output "Inserted" $record.Id
    }

    Write-Host "#####################################################"
    Write-Host "Successfully updated sharepoint records in MySQL."


    #Stick all the records in this megablob into a SQL database
    foreach ($record in $EXOmegaBlob)
    {
        #Construct the query to a valid string, then execute that sucker
        #Need to handle the parameters object by converting to a string.
        $thisQuery = "INSERT IGNORE INTO auditexchange (CreationTime, Id, Operation, OrganizationId, RecordType, ResultStatus, UserKey, UserType, Workload, ObjectId, UserId, ExternalAccess, OrganizationName, OriginatingServer, Parameters) VALUES ('" + $record.CreationTime + "', '" + $record.Id + "', '" + $record.Operation + "', '" + $record.OrganizationId + "', '" + $record.RecordType + "', '" + $record.ResultStatus + "', '" + $record.UserKey + "', '" + $record.UserType + "', '" + $record.Workload + "', '" + $record.ObjectId + "', '" + $record.UserId + "', '" + $record.ExternalAccess + "', '" + $record.OrganizationName + "', '" + $record.OriginatingServer + "', '" + $record.Parameters + "')"
        Invoke-MySQL "$thisQuery"
        Write-Output "Inserted" $record.Id
    }
    Write-Host "#####################################################"
    Write-Host "Successfully updated exchange records in MySQL."


    #Stick all the records in this megablob into a SQL database
    foreach ($record in $AADmegaBlob)
    {
        #Construct the query to a valid string, then execute that sucker
        #Need to handle the parameters object by converting to a string.
        $thisQuery = "INSERT IGNORE INTO auditaad (CreationTime, Id, Operation, OrganizationId, RecordType, ResultStatus, UserKey, UserType, Workload, ClientIP, ObjectId, UserId, AzureActiveDirectoryEventType, Client, LoginStatus, UserDomain) VALUES ('" + $record.CreationTime + "', '" + $record.Id + "', '" + $record.Operation + "', '" + $record.OrganizationId + "', '" + $record.RecordType + "', '" + $record.ResultStatus + "', '" + $record.UserKey + "', '" + $record.UserType + "', '" + $record.Workload + "', '" + $record.ClientIP + "', '" + $record.ObjectId + "', '" + $record.UserId + "', '" + $record.AzureActiveDirectoryEventType + "', '" + $record.Client + "', '" + $record.LoginStatus + "', '" + $record.UserDomain + "')"
        Invoke-MySQL "$thisQuery"
        Write-Output "Inserted" $record.Id
    }
    Write-Host "#####################################################"
    Write-Host "Successfully updated aad records in MySQL."
}


function Export-AzureSQL ($blobs) {

    #Make sure we've got tables
    Invoke-AzureSql -Query "if not exists (select * from sysobjects where name ='auditsharepoint' and xtype='U') CREATE TABLE auditsharepoint (CreationTime DATETIME, Id CHAR(36) NOT NULL, Operation TEXT, OrganizationId TEXT, RecordType INT, UserKey TEXT, UserType INT, Workload TEXT, ClientIP TEXT, ObjectId TEXT, UserId TEXT, EventSource TEXT, ItemType TEXT, Site TEXT, UserAgent TEXT, SourceFileExtension TEXT, SiteUrl TEXT, SourceFileName TEXT, SourceRelativeUrl TEXT, PRIMARY KEY (Id))"
    Invoke-AzureSql -Query "if not exists (select * from sysobjects where name='auditexchange' and xtype='U') CREATE TABLE auditexchange (CreationTime DATETIME, Id CHAR(36) NOT NULL, Operation TEXT, OrganizationId TEXT, RecordType INT, ResultStatus TEXT, UserKey TEXT, UserType INT, Workload TEXT, ObjectId TEXT, UserId TEXT, ExternalAccess TEXT, OrganizationName TEXT, OriginatingServer TEXT, Parameters TEXT, PRIMARY KEY (Id))"
    Invoke-AzureSql -Query "if not exists (select * from sysobjects where name='auditaad' and xtype='U') CREATE TABLE auditaad (CreationTime DATETIME, Id CHAR(36) NOT NULL, Operation TEXT, OrganizationId TEXT, RecordType INT, ResultStatus TEXT, UserKey TEXT, UserType INT, Workload TEXT, ClientIP TEXT, ObjectId TEXT, UserId TEXT, AzureActiveDirectoryEventType TEXT, Client TEXT, LoginStatus TEXT, UserDomain TEXT, PRIMARY KEY (Id))"

    $body = @{grant_type="client_credentials";resource=$resource;client_id=$ClientID;client_secret=$ClientSecret}
    $oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body
    $oauthExpiration = [datetime]::Now.AddSeconds($oauth.expires_in)

    #Let's put the oauth token in the header, where it belongs
    $headerParams  = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"}

    #Go Get the Content!
    for ($i = 0; $i -le $blobs.Length -1; $i++) 
    { 
        $timeleft = $oauthExpiration - [datetime]::Now
        if ($timeLeft.TotalSeconds -lt 100) 
        {
            Write-Host "Nearing token expiration, acquiring a new one."; 
            $oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body; 
            $headerParams  = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"}; 
            $oauthExpiration = [datetime]::Now.AddSeconds($oauth.expires_in); 
            Write-Host "New token lifespan is $oauthExpiration"; 
        }
        #Get the datums
        $thisBlobdata = Invoke-WebRequest -Headers $headerParams -Uri $blobs[$i].contentUri
        
        #Get it into a more work-able format
        $altFormat = $thisBlobdata.Content | ConvertFrom-Json

        if ($blobs[$i].ContentType -eq "Audit.SharePoint") { $SPOmegaBlob += $altFormat; }
        if ($blobs[$i].ContentType -eq "Audit.Exchange") { $EXOmegaBlob += $altFormat; }
        if ($blobs[$i].ContentType -eq "Audit.AzureActiveDirectory") { $AADmegaBlob += $altFormat; }
    }

    #Stick all the records in this megablob into a SQL database
    foreach ($record in $SPOmegaBlob)
    {
        #Construct the query to a valid string, then execute that sucker
        #Need to handle the parameters object by converting to a string.
        $thisQuery = "if not exists (select Id from auditsharepoint where Id='" + $record.Id + "') BEGIN INSERT INTO auditsharepoint (CreationTime, Id, Operation, OrganizationId, RecordType, UserKey, UserType, Workload, ClientIP, ObjectId, UserId, EventSource, ItemType, Site, UserAgent, SourceFileExtension, SiteUrl, SourceFileName, SourceRelativeUrl) VALUES ('" + $record.CreationTime + "', '" + $record.Id + "', '" + $record.Operation + "', '" + $record.OrganizationId + "', '" + $record.RecordType + "', '" + $record.UserKey + "', '" + $record.UserType + "', '" + $record.Workload + "', '" + $record.ClientIP + "', '" + $record.ObjectId + "', '" + $record.UserId + "', '" + $record.EventSource + "', '" + $record.ItemType + "', '" + $record.Site + "', '" + $record.UserAgent + "', '" + $record.SourceFileExtension + "', '" + $record.SiteUrl + "', '" + $record.SourceFileName + "', '" + $record.SourceRelativeUrl + "') END"
        Invoke-AzureSql "$thisQuery"
    }

    Write-Host "#####################################################"
    Write-Host "Successfully updated sharepoint records in SQL."


    #Stick all the records in this megablob into a SQL database
    foreach ($record in $EXOmegaBlob)
    {
        #Construct the query to a valid string, then execute that sucker
        #Need to handle the parameters object by converting to a string.
        $thisQuery = "if not exists (select Id from auditexchange where Id='" + $record.Id + "') BEGIN INSERT INTO auditexchange (CreationTime, Id, Operation, OrganizationId, RecordType, ResultStatus, UserKey, UserType, Workload, ObjectId, UserId, ExternalAccess, OrganizationName, OriginatingServer, Parameters) VALUES ('" + $record.CreationTime + "', '" + $record.Id + "', '" + $record.Operation + "', '" + $record.OrganizationId + "', '" + $record.RecordType + "', '" + $record.ResultStatus + "', '" + $record.UserKey + "', '" + $record.UserType + "', '" + $record.Workload + "', '" + $record.ObjectId + "', '" + $record.UserId + "', '" + $record.ExternalAccess + "', '" + $record.OrganizationName + "', '" + $record.OriginatingServer + "', '" + $record.Parameters + "') END"
        Invoke-AzureSql "$thisQuery"
    }
    Write-Host "#####################################################"
    Write-Host "Successfully updated exchange records in SQL."


    #Stick all the records in this megablob into a SQL database
    foreach ($record in $AADmegaBlob)
    {
        #Construct the query to a valid string, then execute that sucker
        #Need to handle the parameters object by converting to a string.
        $thisQuery = "if not exists (select Id from auditaad where Id='" + $record.Id + "') BEGIN INSERT INTO auditaad (CreationTime, Id, Operation, OrganizationId, RecordType, ResultStatus, UserKey, UserType, Workload, ClientIP, ObjectId, UserId, AzureActiveDirectoryEventType, Client, LoginStatus, UserDomain) VALUES ('" + $record.CreationTime + "', '" + $record.Id + "', '" + $record.Operation + "', '" + $record.OrganizationId + "', '" + $record.RecordType + "', '" + $record.ResultStatus + "', '" + $record.UserKey + "', '" + $record.UserType + "', '" + $record.Workload + "', '" + $record.ClientIP + "', '" + $record.ObjectId + "', '" + $record.UserId + "', '" + $record.AzureActiveDirectoryEventType + "', '" + $record.Client + "', '" + $record.LoginStatus + "', '" + $record.UserDomain + "') END"
        Invoke-AzureSql "$thisQuery"
    }
    Write-Host "#####################################################"
    Write-Host "Successfully updated aad records in SQL."

}

function Export-AzureBlob ($blobs) {

    $body = @{grant_type="client_credentials";resource=$resource;client_id=$ClientID;client_secret=$ClientSecret}
    $oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body
    $oauthExpiration = [datetime]::Now.AddSeconds($oauth.expires_in)

    #Let's put the oauth token in the header, where it belongs
    $headerParams  = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"}

    #Go Get the Content!
    for ($i = 0; $i -le $blobs.Length -1; $i++) 
    { 
        #Get the datums
        $timeleft = $oauthExpiration - [datetime]::Now
        if ($timeLeft.TotalSeconds -lt 100) 
        {
            Write-Host "Nearing token expiration, acquiring a new one."; 
            $oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body; 
            $headerParams  = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"}; 
            $oauthExpiration = [datetime]::Now.AddSeconds($oauth.expires_in); 
            Write-Host "New token lifespan is $oauthExpiration"; 
        }
        $thisBlobdata = Invoke-WebRequest -Headers $headerParams -Uri $blobs[$i].contentUri
        
        $thisBlobName = ($blobs[$i].contentType + $blobs[$i].contentCreated.Substring(0,10) + "--" + $blobs[$i].contentID + ".json")
        #Write it to JSON
        $thisBlobdata.Content | ConvertTo-Json | Out-File ("c:\temp\" + $thisBlobName)

        Get-ChildItem "c:\temp\$thisBlobName" | Set-AzureStorageBlobContent -Container $globalConfig.AzureBlobContainerName -Force
        Remove-Item "c:\temp\$thisBlobName"
    }

    
}

function ExportLocal-MySql {

   #Make sure we've got tables
    Invoke-MySQL -Query "CREATE TABLE IF NOT EXISTS auditsharepoint (CreationTime DATETIME, Id CHAR(36) NOT NULL, Operation TEXT, OrganizationId TEXT, RecordType INT, UserKey TEXT, UserType INT, Workload TEXT, ClientIP TEXT, ObjectId TEXT, UserId TEXT, EventSource TEXT, ItemType TEXT, Site TEXT, UserAgent TEXT, SourceFileExtension TEXT, SiteUrl TEXT, SourceFileName TEXT, SourceRelativeUrl TEXT, PRIMARY KEY (Id))"
    Invoke-MySQL -Query "CREATE TABLE IF NOT EXISTS auditexchange (CreationTime DATETIME, Id CHAR(36) NOT NULL, Operation TEXT, OrganizationId TEXT, RecordType INT, ResultStatus TEXT, UserKey TEXT, UserType INT, Workload TEXT, ObjectId TEXT, UserId TEXT, ExternalAccess TEXT, OrganizationName TEXT, OriginatingServer TEXT, Parameters TEXT, PRIMARY KEY (Id))"
    Invoke-MySQL -Query "CREATE TABLE IF NOT EXISTS auditaad (CreationTime DATETIME, Id CHAR(36) NOT NULL, Operation TEXT, OrganizationId TEXT, RecordType INT, ResultStatus TEXT, UserKey TEXT, UserType INT, Workload TEXT, ClientIP TEXT, ObjectId TEXT, UserId TEXT, AzureActiveDirectoryEventType TEXT, Client TEXT, LoginStatus TEXT, UserDomain TEXT, PRIMARY KEY (Id))"


    Write-Host "Looks like we need to leverage local files. Sweet.";
    #Let's build a variable full of the files already in the local store
    $localfiles = @()
    $localFiles = Get-ChildItem $globalConfig.LocalFileStore -Recurse | Select-Object -Property Name
    $thisFile = @()
    $thisBlob = @()
        
    for ($i = 0; $i -lt $localfiles.Length -1; $i++)
    {
        $thisfile = $globalConfig.LocalFileStore + "\" + $localfiles[$i].Name
        $thisBlob = Get-Content $thisfile | ConvertFrom-Json

        if ($localFiles[$i] -like "*Audit.SharePoint*")
        {
            $records = $thisBlob | ConvertFrom-Json
            foreach ($record in $records)
            {
                #Construct the query to a valid string, then execute that sucker
                #Need to handle the parameters object by converting to a string.
                $thisQuery = "INSERT IGNORE INTO auditsharepoint (CreationTime, Id, Operation, OrganizationId, RecordType, UserKey, UserType, Workload, ClientIP, ObjectId, UserId, EventSource, ItemType, Site, UserAgent, SourceFileExtension, SiteUrl, SourceFileName, SourceRelativeUrl) VALUES ('" + $record.CreationTime + "', '" + $record.Id + "', '" + $record.Operation + "', '" + $record.OrganizationId + "', '" + $record.RecordType + "', '" + $record.UserKey + "', '" + $record.UserType + "', '" + $record.Workload + "', '" + $record.ClientIP + "', '" + $record.ObjectId + "', '" + $record.UserId + "', '" + $record.EventSource + "', '" + $record.ItemType + "', '" + $record.Site + "', '" + $record.UserAgent + "', '" + $record.SourceFileExtension + "', '" + $record.SiteUrl + "', '" + $record.SourceFileName + "', '" + $record.SourceRelativeUrl + "')"
                Invoke-MySQL "$thisQuery"
                Write-Output "Inserted" $record.Id
            }

        }
        if ($localFiles[$i] -like "*Audit.Exchange*")
        {
            $records = $thisBlob | ConvertFrom-Json
            foreach ($record in $records)
            {
                #Construct the query to a valid string, then execute that sucker
                #Need to handle the parameters object by converting to a string.
                $thisQuery = "INSERT IGNORE INTO auditexchange (CreationTime, Id, Operation, OrganizationId, RecordType, ResultStatus, UserKey, UserType, Workload, ObjectId, UserId, ExternalAccess, OrganizationName, OriginatingServer, Parameters) VALUES ('" + $record.CreationTime + "', '" + $record.Id + "', '" + $record.Operation + "', '" + $record.OrganizationId + "', '" + $record.RecordType + "', '" + $record.ResultStatus + "', '" + $record.UserKey + "', '" + $record.UserType + "', '" + $record.Workload + "', '" + $record.ObjectId + "', '" + $record.UserId + "', '" + $record.ExternalAccess + "', '" + $record.OrganizationName + "', '" + $record.OriginatingServer + "', '" + $record.Parameters + "')"
                Invoke-MySQL "$thisQuery"
                Write-Output "Inserted" $record.Id
            }
        }

        if ($localFiles[$i] -like "*Audit.AzureActiveDirectory*")
        {
            $records = $thisBlob | ConvertFrom-Json
            foreach ($record in $AADmegaBlob)
            {
                #Construct the query to a valid string, then execute that sucker
                #Need to handle the parameters object by converting to a string.
                $thisQuery = "INSERT IGNORE INTO auditaad (CreationTime, Id, Operation, OrganizationId, RecordType, ResultStatus, UserKey, UserType, Workload, ClientIP, ObjectId, UserId, AzureActiveDirectoryEventType, Client, LoginStatus, UserDomain) VALUES ('" + $record.CreationTime + "', '" + $record.Id + "', '" + $record.Operation + "', '" + $record.OrganizationId + "', '" + $record.RecordType + "', '" + $record.ResultStatus + "', '" + $record.UserKey + "', '" + $record.UserType + "', '" + $record.Workload + "', '" + $record.ClientIP + "', '" + $record.ObjectId + "', '" + $record.UserId + "', '" + $record.AzureActiveDirectoryEventType + "', '" + $record.Client + "', '" + $record.LoginStatus + "', '" + $record.UserDomain + "')"
                Invoke-MySQL "$thisQuery"
                Write-Output "Inserted" $record.Id
            }
        }

    }


    Write-Host "#####################################################"
    Write-Host "Successfully updated sharepoint records in MySQL."


    Write-Host "#####################################################"
    Write-Host "Successfully updated exchange records in MySQL."


    Write-Host "#####################################################"
    Write-Host "Successfully updated aad records in MySQL."

}


function Export-AzureDocDB {
    #comingsoon
}



#This will export the data in the API to a local directory
if ($globalConfig.StoreFilesLocally -eq "True") { Export-LocalFiles $blobs; }

#This will export the data in the API to a MySQL instance
if ($globalConfig.StoreDataInMySQl -eq "True") { Export-MySql $blobs; }

#This will export local data to a MySQL instance
if ($globalConfig.IngestLocalFiles -eq "True") { ExportLocal-MySql; }


#This will export the data in the API to an Azure SQL instance
if ($globalConfig.StoreDataInAzureSql -eq "True") { Export-AzureSql $blobs; }

#This will export the data in the API to an Azure blob storage account
if ($globalConfig.StoreDataInAzureBlob -eq "True") { Check-AzureSetup; }
if ($globalConfig.StoreDataInAzureBlob -eq "True") { Export-AzureBlob $blobs; }

#This will export eh data in the API to a Azure DocDB store
if ($globalConfig.StoreDataInAzureDocDb -eq "True") { Export-AzureDocDb $blobs; }