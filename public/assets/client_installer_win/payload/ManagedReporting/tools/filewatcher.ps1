$triggerFile = "C:\ProgramData\ManagedReporting\trigger.run"
$runnerExe = "C:\ProgramData\ManagedReporting\managedreport-runner.exe"

Write-Host "Watching for $triggerFile..."

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = Split-Path $triggerFile
$watcher.Filter = Split-Path $triggerFile -Leaf
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite'

$action = {
    Write-Host "Trigger detected, running Managed Reporting..."
    & $runnerExe
    Remove-Item $triggerFile -Force -ErrorAction SilentlyContinue
}

Register-ObjectEvent $watcher 'Created' -Action $action
Register-ObjectEvent $watcher 'Changed' -Action $action

while ($true) { Start-Sleep -Seconds 5 }