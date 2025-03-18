param(
    [string]$Message = "Unspecified client error",
    [string]$Module = "ManagedReporting",
    [string]$Severity = "warning"
)

$configPath = "C:\ProgramData\ManagedReporting\config\preferences.json"
$config = Get-Content -Raw -Path $configPath | ConvertFrom-Json

$serialNumber = (Get-WmiObject Win32_BIOS).SerialNumber
$computerName = $env:COMPUTERNAME

$payload = @{
    msg         = $Message
    module      = $Module
    type        = $Severity
    serial      = $serialNumber
    name        = $env:COMPUTERNAME
    platform    = "windows"
}

$headers = @{
    Authorization = "Bearer $($config.Token)"
}

try {
    Invoke-RestMethod -Uri "$($config.BaseURL)/report/check_in/" `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json" `
        -Body ($payload | ConvertTo-Json -Depth 4)

    Write-Output "Report submitted successfully."
}
catch {
    Write-Error "Error submitting report: $_"
    exit 1
}