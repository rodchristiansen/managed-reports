$triggerFile = "C:\ProgramData\ManagedReporting\trigger.run"

# Remove existing trigger file if it exists
if (Test-Path $triggerFile) {
    Remove-Item $triggerFile -Force
}

# Create a fresh trigger file
New-Item $triggerFile -ItemType File -Force