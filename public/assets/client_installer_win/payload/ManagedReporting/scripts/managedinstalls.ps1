# managedinstalls.ps1 - Combined Cimian Software Inventory & Logs

Import-Module "$PSScriptRoot\..\lib\reportcommon.psm1"

# Paths
$logPath   = "C:\ProgramData\ManagedInstalls\Logs\install.log"
$outputPath = "$PSScriptRoot\..\cache\managedinstalls.json"

# Collect installed software (managed by Cimian)
$softwareItems = Get-CimInstance -ClassName Win32_Product | Select-Object Name, Version, InstallDate

$managedSoftwareList = @()
foreach ($software in $softwareItems) {
    $managedSoftwareList += @{
        name        = $software.Name
        version     = $software.Version
        installDate = $software.InstallDate
        status      = "installed"  # Replace with real Cimian-managed status
    }
}

# Collect recent Cimian log entries
$recentLogs = @()
if (Test-Path $logPath) {
    $logLines = Get-Content $logPath -Tail 100
    foreach ($line in $logLines) {
        if ($line -match "^\[(.+?)\]\s+(\w+)\s+(.*)$") {
            $recentLogs += @{
                timestamp = $matches[1]
                level     = $matches[2]
                message   = $matches[3]
            }
        }
    }
} else {
    Write-Warning "Cimian log file not found at $logPath"
}

# Final combined output
$report = @{
    softwareInventory = $managedSoftwareList
    recentLogs        = $recentLogs
}

# Write combined JSON for MunkiReport
$report | ConvertTo-Json -Depth 6 | Out-File -FilePath $outputPath -Encoding UTF8
