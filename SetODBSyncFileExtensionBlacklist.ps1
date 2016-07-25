#This script will configure your SharePoint Online tenancy to block the syncing of files that are known ransomware.

$transcriptpath = ".\" + "SetODBFileSyncBlacklistTranscript" + (Get-Date).ToString('yyyy-MM-dd') + ".txt"
Start-Transcript -Path $transcriptpath

$AdminCredential = Get-Credential

#This gets us connected to a SPOnline remote powershell service
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking

    Try
    {
        #First, let's construct the SPOAdmin URL from the user's admin email address
        $SPOAdminURLBase = $AdminCredential.UserName.Split("@")[1] | Select-String -Pattern "([^.]+)" | Select-Object -Expand matches | Select-Object -Expand Value
        $SPOAdminURL = "https://" + $SPOAdminURLBase + "-admin.sharepoint.com"

        #Then, let's connect to the service!
        Connect-SPOService -Url $SPOAdminURL -Credential $AdminCredential
    }
    Catch
    {
        Write-Log "  No SharePoint Online service set up for this account"
        $ServiceInfo.Set_Item("SPO", "False")        

    }

Write-Output "You current Sync Client configuration is set to: "
Get-SPOTenantSyncClientRestriction

Set-SPOTenantSyncClientRestriction  -ExcludedFileExtensions "ecc;ezz;exx;zzz;xyz;aaa;abc;ccc;vvv;xxx;ttt;micro;encrypted;locked;crypto;crinf;r5a;XRNT;XTBL;crypt;R16M01D05;pzdc;good;RDM;RRK;encryptedRSA;crjoker;EnCiPhErEd;LeChiffre;0x0;bleep;1999;vault;HA3;toxcrypt;magic;SUPERCRYPT;CTBL;CTB2;locky;cryp1;zepto"

Write-Output "Excellent! You have configured your tenancy to not sync files with at least some known ransomware file extensions. Periodically update the list and your blacklist."

Stop-Transcript