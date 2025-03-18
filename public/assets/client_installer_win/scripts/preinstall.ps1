# Preinstall: Create necessary directories and default configuration
New-Item -Path "C:\ProgramData\ManagedReporting\scripts" -ItemType Directory -Force
New-Item -Path "C:\ProgramData\ManagedReporting\cache" -ItemType Directory -Force
New-Item -Path "C:\ProgramData\ManagedReporting\logs" -ItemType Directory -Force
New-Item -Path "C:\ProgramData\ManagedReporting\config" -ItemType Directory -Force
New-Item -Path "C:\ProgramData\ManagedReporting\tools" -ItemType Directory -Force

# Create preferences.json
$config = @{
    BaseURL = "https://munkireport.ecuad.ca/"
    Modules = @("events", "hardware", "software", "applications")
} | ConvertTo-Json -Depth 4

$config | Out-File "C:\ProgramData\ManagedReporting\config\preferences.json" -Encoding UTF8

# Example passphrase.yaml based on device environment (commented out examples)
<#

# Testing environment
@"
Passphrase: '7B085504-8A0F-4A11-82AE-A7998223D818'
"@ | Out-File "C:\ProgramData\ManagedReporting\config\passphrase.yaml" -Encoding UTF8

# Staging environment
@"
Passphrase: '0455C62E-BB77-48FF-88F4-04D9FCA9D43E'
"@ | Out-File "C:\ProgramData\ManagedReporting\config\passphrase.yaml" -Encoding UTF8

# Production environment
@"
Passphrase: '8C6E2862-9C62-4977-85A8-AEC6280F5AA2'
"@ | Out-File "C:\ProgramData\ManagedReporting\config\passphrase.yaml" -Encoding UTF8
#>