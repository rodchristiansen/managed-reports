# managedinstalls.ps1 - Combined Cimian Software Inventory & Logs

# Ensure powershell-yaml module is installed
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Install-Module powershell-yaml -Force -Scope AllUsers
}
Import-Module powershell-yaml

# Existing paths
$yamlLogPath = "C:\ProgramData\ManagedInstalls\Logs\CimianReport.yaml"
$outputPath = "$PSScriptRoot\..\cache\managedinstalls.json"

# Read and convert YAML structured logs
$structuredLogs = @()
if (Test-Path $yamlLogPath) {
    $yamlContent = Get-Content $yamlLogPath -Raw
    $yamlEntries = ConvertFrom-Yaml $yamlContent
    foreach ($entry in $yamlEntries) {
        $structuredLogs += @{
            timestamp = $entry.timestamp
            level     = $entry.level
            message   = $entry.message
        }
    }
} else {
    Write-Warning "CimianReport.yaml not found."
}

# Combine into final report
$report = @{
    softwareInventory = $managedSoftwareList
    recentLogs        = $recentLogs
    structuredLogs    = $structuredLogs
}

# Write combined JSON
$report | ConvertTo-Json -Depth 6 | Out-File -FilePath $outputPath -Encoding UTF8
