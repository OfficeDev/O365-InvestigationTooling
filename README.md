---
topic: sample
products:
- office-365
languages:
- powershell
extensions:
  contentType: tools
  createdDate: 2/11/2016 4:22:37 PM
---
# O365-InvestigationTooling

This project is to help faciliate testing and low-volume activity data acquisition from the Office 365 Management
Activity API.

* [Activity API Getting Started Guide][gettingstarted]
* [Management Activity API reference][apireference]
* [Powershell cmdlet for Auditing][psauditing]
* [Activity API Schema Documentation][apischemadocs]


## Prerequisites for the O365 Investigation Data Acquisition Script

Once you have selected the data store that you want to publish your Activity API data to, simply open the
[ConfigForO365Investigations.json](ConfigForO365Investigations.json) file and enable and configure the attributes that
are relevant to your store. Note you will have to register an application in Azure AD, then populate the config with the
AppID (`InvestigationAppID`) and AppSecret (`InvestigationAppSecret`) to enable data flow for the Activity API.


## Prerequisites for the Activity API
Follow the instructions in the [Management Activity API: Getting Started Guide](gettingstarted) to create a new AAD
application and grant it permissions to the tenant's Management Activity API.


## Prerequisites for the MySQL Store Pattern
1. If you don't already have a MySQL database, download the [Windows MySQL
   installer](http://dev.mysql.com/get/Downloads/MySQLInstaller/mysql-installer-community-5.7.8.0-rc.msi).  Make sure to
   include MySQL server, MySQL Workbench, and the ODBC and .Net connectors. (MySQL docs are here:
   https://dev.mysql.com/doc/refman/5.7/en/json.html

1. Using the `mysql` command-line client, run

    ```sql
    CREATE DATABASE O365Investigations;
    ```
    to create the database.
1. Populate [ConfigForO365Investigations.json](ConfigForO365Investigations.json) with your MySQL admin name and
   password, as well as the hostname and database name.

1. Run the [O365InvestigationDataAcquisition.ps1](O365InvestigationDataAcquisition.ps1) script to enable the
   subscriptions and pull the data. Re-run regularly to continue to consume new data.

1. Once you have enough data, open MySQL Workbench, open
   [ActivityAPI-InvestigationQueries.sql](ActivityAPI-InvestigationQueries.sql) and run the approach SQL statements to
   get answers to your questions.


## Prerequisites for the Azure Blob Store Pattern

1. Determine the desired storage account name and update the config file.

1. Determine the desired container name and update the config file.

1. Determine the account name you will use to manage the blob storage and update the config file.

1. Run the PowerShell command
    
    ```ps1
    Read-Host -AsSecureString | ConvertFrom-SecureString
    ```

    and provide the password for the account you will use to manage the Azure blob storage, then use the output as the
    value for `AzureAccountSecureString` in the [ConfigForO365Investigations.json](ConfigForO365Investigations.json)
    file.

## Prerequisites for the SQL Azure Store Pattern 

1. Login to your Azure subscription at https://portal.azure.com

1. Ensure you have a storage account set up

1. Select "+ New" in the upper left, then "Data + Storage", then "SQL Database"

1. Name your new database "O365Investigations"

1. Select an existing SQL server (and make note of the hostname), or create a new server (making note of the admin
   account you used to create the database)

1. Select the source, pricing tier, resource group, and associated subscription, then click "Create".

1. Select SQL Servers from the main navigation, select the server you just created, then click "Show Firewall Settings".
   In the "Firewall Settings" blade, click "Add Client IP" and add the IP address of the host where you will be running
   the investigations tooling from. Save and wait for confirmation that the firewall rules have been updated.

1. Use Visual Studio, or download [SQL Server Management Studio Express 2014](ssms) (for free) and connect to your new
   database.

1. Create a new SQL database named "O365Investigations"

1. Ensure you have a username and password for an account that can connect to the database.


[gettingstarted]: https://msdn.microsoft.com/EN-US/library/office/dn707383.aspx
[apireference]: https://msdn.microsoft.com/EN-US/library/office/mt227394.aspx
[psauditing]: https://technet.microsoft.com/library/mt238501(v=exchg.160).aspx
[apischemadocs]: https://msdn.microsoft.com/EN-US/library/office/mt607130.aspx
[ssms]: https://www.microsoft.com/en-us/download/details.aspx?id=42299


This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information, see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
