#This script will set the auditing to the default Microsoft Set of Auditing
#https://docs.microsoft.com/en-us/office365/securitycompliance/enable-mailbox-auditing
#First, let's get us a cred!
$userCredential = Get-Credential

#This gets us connected to an Exchange remote powershell service
$ExoSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $userCredential -Authentication Basic -AllowRedirection
Import-PSSession $ExoSession -Name Get-Mailbox, Set-Mailbox

#Enable global audit logging
#Get all User, Shared, Room and Discovery mailbox
$mailboxes = Get-Mailbox -ResultSize Unlimited -Filter {RecipientTypeDetails -eq "UserMailbox" -or RecipientTypeDetails -eq "SharedMailbox" -or RecipientTypeDetails -eq "RoomMailbox" -or RecipientTypeDetails -eq "DiscoveryMailbox"}) | Select-Object ExternalDirectoryObjectId
foreach ($mailbox in $mailboxes)
{
    try
    {
        #Use the ExternalDirectoryObjectId to set the mailbox for setting the correct item
        #Set them to the default set
        Set-Mailbox -Identity $mailbox.ExternalDirectoryObjectId -AuditEnabled $true -AuditLogAgeLimit 180 -DefaultAuditSet Admin,Delegate,Owner
    }
    catch
    {
        Write-Warning $_.Exception.Message
    }
}

#Double-Check It!
Get-Mailbox -ResultSize Unlimited | Select Name, AuditEnabled, AuditLogAgeLimit, DefaultAuditSet | Export-Csv -Path mailboxaudit.csv -Delimiter ';'
