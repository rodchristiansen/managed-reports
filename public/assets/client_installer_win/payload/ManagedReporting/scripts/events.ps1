# events.ps1
Get-WinEvent -LogName System -EntryType Error, Warning -MaxEvents 100 |
Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message |
ConvertTo-Json | Out-File "$env:ProgramData\ManagedReporting\cache\eventlog.json"