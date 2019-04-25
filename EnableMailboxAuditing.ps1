#This script will enable non-owner mailbox access auditing on every mailbox in your tenancy
#First, let's get us a cred!
$userCredential = Get-Credential

#This gets us connected to an Exchange remote powershell service
$ExoSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $userCredential -Authentication Basic -AllowRedirection
Import-PSSession $ExoSession -Name Get-Mailbox, Set-Mailbox

#Enable global audit logging
foreach ($mailbox in Get-Mailbox -ResultSize Unlimited -Filter {RecipientTypeDetails -eq "UserMailbox" -or RecipientTypeDetails -eq "SharedMailbox" -or RecipientTypeDetails -eq "RoomMailbox" -or RecipientTypeDetails -eq "DiscoveryMailbox"})
{
    try
    {
        Set-Mailbox -Identity $mailbox.DistinguishedName -AuditEnabled $true -AuditLogAgeLimit 180 -AuditAdmin Update, MoveToDeletedItems, SoftDelete, HardDelete, SendAs, SendOnBehalf, Create, UpdateFolderPermission -AuditDelegate Update, SoftDelete, HardDelete, SendAs, Create, UpdateFolderPermissions, MoveToDeletedItems, SendOnBehalf -AuditOwner UpdateFolderPermission, MailboxLogin, Create, SoftDelete, HardDelete, Update, MoveToDeletedItems
    }
    catch
    {
        Write-Warning $_.Exception.Message
    }
}

#Double-Check It!
Get-Mailbox -ResultSize Unlimited | Select Name, AuditEnabled, AuditLogAgeLimit | Out-Gridview
