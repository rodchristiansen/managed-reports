# Preinstall: Create necessary directories and default config
New-Item -Path "C:\ProgramData\ManagedReporting\scripts" -ItemType Directory -Force
New-Item -Path "C:\ProgramData\ManagedReporting\cache" -ItemType Directory -Force
New-Item -Path "C:\ProgramData\ManagedReporting\logs" -ItemType Directory -Force
New-Item -Path "C:\ProgramData\ManagedReporting\config" -ItemType Directory -Force

$config = @{
    BaseURL = "https://munkireport.ecuad.ca/"
    Token   = "<Your-Server-Token-Here>"
    Modules = @("hardware", "software", "applications")
} | ConvertTo-Json -Depth 4

$config | Out-File "C:\ProgramData\ManagedReporting\config\preferences.json" -Encoding UTF8