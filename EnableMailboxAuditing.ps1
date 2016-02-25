#This script will enable non-owner mailbox access auditing on every mailbox in your tenancy
#First, let's get us a cred!
$userCredential = Get-Credential

#This gets us connected to an Exchange remote powershell service
$ExoSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $userCredential -Authentication Basic -AllowRedirection
Import-PSSession $ExoSession

#Enable global audit logging
Get-Mailbox -ResultSize Unlimited -Filter {RecipientTypeDetails -eq "UserMailbox"} | Set-Mailbox -AuditEnabled $true -AuditLogAgeLimit 365

#Double-Check It!
Get-Mailbox | Select Name, AuditEnabled, AuditLogAgeLimit

