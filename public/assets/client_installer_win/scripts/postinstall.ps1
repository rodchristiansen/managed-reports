$action = New-ScheduledTaskAction -Execute "C:\ProgramData\ManagedReporting\managedreport-runner.exe"
$trigger = New-ScheduledTaskTrigger -OnEvent `
    -Subscription "<QueryList><Query><Select Path='Security'>*[System/EventID=4656]</Query></Subscription>"
$trigger = New-ScheduledTaskTrigger -AtStartup  # Alternative simpler trigger
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount

Register-ScheduledTask `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -TaskName "ManagedReportingRunner" `
    -Description "Triggered ManagedReporting run by trigger.run file" `
    -Force