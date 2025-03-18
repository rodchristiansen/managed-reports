# software.ps1
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | 
ConvertTo-Json | Out-File "$env:ProgramData\ManagedReporting\cache\software.json"