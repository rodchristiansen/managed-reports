# hardware.ps1
$hardware = @{
    serial_number = (Get-WmiObject -Class Win32_BIOS).SerialNumber
    hostname = $env:COMPUTERNAME
    cpu = (Get-CimInstance -ClassName Win32_Processor).Name
    ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    os_version = (Get-CimInstance Win32_OperatingSystem).Caption
    disk = Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID,Size,FreeSpace
}
$hardware | ConvertTo-Json | Out-File "C:\ProgramData\ManagedReporting\cache\hardware.json" -Encoding utf8