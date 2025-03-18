$action = New-ScheduledTaskAction -Execute "pwsh.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\ProgramData\ManagedReporting\filewatcher.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount

Register-ScheduledTask `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -TaskName "ManagedReportingWatcher" `
    -Description "File watcher for ManagedReporting trigger.run" `
    -Force