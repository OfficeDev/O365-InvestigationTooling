# O365-InvestigationTooling
This project is to help faciliate testing and low-volume activity data acquisition from the Office 365 Management Activity API: 
Activity API Getting Started Guide: https://msdn.microsoft.com/EN-US/library/office/dn707383.aspx
Management Activity API reference: https://msdn.microsoft.com/EN-US/library/office/mt227394.aspx
Powershell cmdlet for Auditing: https://technet.microsoft.com/library/mt238501(v=exchg.160).aspx
Activity API Schema Documentation: https://msdn.microsoft.com/EN-US/library/office/mt607130.aspx

#########################################################################
Pre-Reqs for the O365 Investigation Data Acquisition Script
Once you have selected the data store that you want to publish your Activity API data to, simply open the ConfigForO365Investigations.json file and enable and configure the attributes that are relevant to your store. Note you will have to register an application in Azure AD, then populate the config with the AppID and AppSecret to enable data flow for the Activity API.

#########################################################################
Pre-reqs for the Activity API
Enabling the Activity API Interaction
	1. Follow the instructions to create a new AAD application and grant it permissions to the tenant's Management Activity API: Getting Started Guide: https://msdn.microsoft.com/EN-US/library/office/dn707383.aspx

#########################################################################
Pre-reqs for the MySQL Store Pattern
	1. First, you'll need a MySQL database
		a. http://dev.mysql.com/get/Downloads/MySQLInstaller/mysql-installer-community-5.7.8.0-rc.msi
		b. From this install experience include MySql server, MySQL Workbench, and the ODBC and .Net connectors.
		c. MySQL docs are here: https://dev.mysql.com/doc/refman/5.7/en/json.html
	2. Logon through the cmd line and 'create database O365Investigations;'
	3. Populate the script with your MySql Admin name and password, as well as the hostname and db name
	4. Run the O365InvestigationDataAcquisition.ps1 script to enable the subscriptions and pull the data. Re-run regularly to continue to consume new data.
	5. Once you have enough data, open MySQL Workbench, open ActivityAPI-InvestigationQueries and run the approach SQL statements to get answers to your questions.


#########################################################################
Pre-reqs for the Azure Blob Store Pattern
	1. Determine the desired storage account name and update the config file.
	2. Determine the desired container name and update the config file.
	3. Determine the account name you will  use to manage the blob storage and update the config file.
	4. Run the powershell command "read-host -AsSecureString | ConvertFrom-SecureString" and provide the password for the account you will use to manage the azure blob storage, then paste the output in the ConfigForO365Investigations.json --> AzureAccountSecureString.

#########################################################################
Pre-Reqs for the SQL Azure Store Pattern 
	1. Login to your Azure subscription at https://portal.azure.com
	2. Ensure you have a storage account setup
	3. Select + New in the upper left, then Data + Storage, then SQL Database
	4. Name your new database 'o365investigations'
	5. Select a existing SQL server (and make note of the hostname), or create a new server (making note of the admin account you used to create the DB)
	6. Select the source, pricing tier, resource group, and associated subscription, then click create.
	7. Select SQL Servers from the main navigation, select the Server you just created, then click 'Show Firewall Settings'. In the Firewall Settings blade, click 'add client ip' for the host that you will be running the investigations tooling from. Save and wait for confirmation that the firewall rules have been updated.
	8. Use Visual Studio, or download SQL Server Management Studio Express 2014 (for free) and connect to your new database.
	• Create a new SQL database named "o365investigations'
	• Ensure you have a username and password for an account that can connect to the DB.


