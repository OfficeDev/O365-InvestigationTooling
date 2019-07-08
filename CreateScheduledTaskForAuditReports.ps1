#Documentation on Register-ScheduledTask : https://docs.microsoft.com/en-us/powershell/module/scheduledtasks/register-scheduledtask?view=win10-ps

# Specify the trigger settings
$trigger= New-ScheduledTaskTrigger -At "05:07pm" -Daily
# Specify what program to run and with its parameter
$action= New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "C:\Scripts\O365InvestigationDataAcquisition.ps1"
# Specify the name of the task
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Collect Audit Reports"