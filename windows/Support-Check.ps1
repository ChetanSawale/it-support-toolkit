# Support-Check.ps1 — first-line diagnostics for a Windows workstation.
#
# A support-engineer triage script: it REPORTS only, it changes nothing.
# Collects system info, resource usage, top processes, network connectivity
# (gateway, DNS server, name resolution), service status and recent errors,
# then saves a timestamped plain-text report that can be attached to a
# ticket or handed to L2.
#
# Run from PowerShell 5.1 (Windows 10/11):
#   powershell -ExecutionPolicy Bypass -File .\Support-Check.ps1
#
# The report is written to reports\Support-Check-<computer>-<timestamp>.txt
# Companion to the Linux script in ../linux/support-check.sh.
# Some checks (recent event-log errors) may need an elevated prompt; the
# script says so instead of failing when it cannot read something.

$ErrorActionPreference = 'Stop'

$ReportDir = Join-Path $PSScriptRoot 'reports'
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Computer = $env:COMPUTERNAME
$Report = Join-Path $ReportDir "Support-Check-$Computer-$Timestamp.txt"

function Add-Line($Text) {
    Add-Content -Path $Report -Value $Text
}
function Add-Section($Title) {
    Add-Line ''
    Add-Line "== $Title =="
}

# ---------- gather ----------
$OS = Get-CimInstance Win32_OperatingSystem
$BootTime = $OS.LastBootUpTime
$Uptime = (Get-Date) - $BootTime
$UptimeText = '{0}d {1}h {2}m' -f $Uptime.Days, $Uptime.Hours, $Uptime.Minutes

$Cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average
$CpuUsed = [math]::Round($Cpu.Average, 1)

$MemTotalMB = [math]::Round($OS.TotalVisibleMemorySize / 1KB, 0)
$MemFreeMB = [math]::Round($OS.FreePhysicalMemory / 1KB, 0)
$MemUsed = [math]::Round(100 * (1 - $OS.FreePhysicalMemory / $OS.TotalVisibleMemorySize), 1)

# ---------- report ----------
Add-Line "Support Check — $Computer"
Add-Line "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Line "OS: $($OS.Caption) $($OS.Version) | Uptime: $UptimeText"

Add-Section 'RESOURCE SUMMARY'
Add-Line "CPU:    $CpuUsed%"
Add-Line "Memory: $MemUsed% ($($MemTotalMB - $MemFreeMB)MB / ${MemTotalMB}MB)"

Add-Section 'DISKS (fixed drives)'
$Disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3'
foreach ($Disk in $Disks) {
    $UsedPct = [math]::Round(100 * (1 - $Disk.FreeSpace / $Disk.Size), 1)
    $FreeGB = [math]::Round($Disk.FreeSpace / 1GB, 1)
    $SizeGB = [math]::Round($Disk.Size / 1GB, 1)
    Add-Line "$($Disk.DeviceID) ${UsedPct}% used, ${FreeGB}GB free of ${SizeGB}GB"
}

Add-Section 'TOP PROCESSES'
Add-Line '-- by CPU --'
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 |
    ForEach-Object { Add-Line ("  {0,8:N1}  {1,6}  {2}" -f $_.CPU, $_.Id, $_.ProcessName) }
Add-Line '-- by memory --'
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5 |
    ForEach-Object { Add-Line ("  {0,8:N0} MB  {1,6}  {2}" -f ($_.WorkingSet / 1MB), $_.Id, $_.ProcessName) }

Add-Section 'NETWORK'
try {
    $Config = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
    if ($Config) {
        Add-Line "IPv4 address: $($Config.IPv4Address.IPAddress)"
        $Gateway = $Config.IPv4DefaultGateway.NextHop
        if (Test-Connection -ComputerName $Gateway -Count 2 -Quiet -ErrorAction SilentlyContinue) {
            Add-Line "Gateway ${Gateway}: reachable"
        } else {
            Add-Line "Gateway ${Gateway}: NOT REACHABLE"
        }
    } else {
        Add-Line 'Gateway: not found (no default route)'
    }
} catch {
    Add-Line 'Network configuration: could not read (try an elevated prompt)'
}
if (Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet -ErrorAction SilentlyContinue) {
    Add-Line 'Internet (8.8.8.8): reachable'
} else {
    Add-Line 'Internet (8.8.8.8): NOT REACHABLE'
}
try {
    $Dns = Resolve-DnsName example.com -ErrorAction Stop
    Add-Line "DNS resolution (example.com): OK ($($Dns[0].IPAddress))"
} catch {
    Add-Line 'DNS resolution (example.com): FAILED'
}

Add-Section 'SERVICE STATUS'
$Services = @('Spooler', 'wuauserv', 'Winmgmt', 'Dhcp', 'Dnscache', 'LanmanWorkstation')
foreach ($Name in $Services) {
    $Svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($Svc) {
        Add-Line "$($Svc.DisplayName): $($Svc.Status)"
    } else {
        Add-Line "${Name}: not found on this machine"
    }
}

Add-Section 'RECENT SYSTEM ERRORS (last 24h)'
try {
    $Since = (Get-Date).AddHours(-24)
    $Events = Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 2; StartTime = $Since } -MaxEvents 5 -ErrorAction Stop
    if ($Events) {
        foreach ($Ev in $Events) {
            Add-Line ("  {0}  [{1}]  {2}" -f $Ev.TimeCreated, $Ev.Id, $Ev.Message.Split("`n")[0])
        }
    } else {
        Add-Line 'No System errors in the last 24h.'
    }
} catch {
    Add-Line 'System event log not readable (try an elevated prompt).'
}

# ---------- console summary ----------
Write-Host ''
Write-Host "Support summary for ${Computer}:"
Write-Host "  CPU:    $CpuUsed%"
Write-Host "  Memory: $MemUsed%"
Write-Host ''
Write-Host "Full report saved to: $Report"
