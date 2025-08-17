param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments,

    [switch]$Help
)


# Cyber-themed banner
function Show-CyberBanner {
    $banner = @"
    ╔══════════════════════════════════════════════════════════════════════════════════════════════╗
    ║  ▄▄▄▄▄▄▄▄▄▄▄  ▄         ▄             ▄        ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄   ║
    ║ ▐░░░░░░░░░░░▌▐░▌       ▐░▌          █░░░█      █░░░░░░░░░░░░░░░█ ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌  ║
    ║ ▐░█▀▀▀▀▀▀▀▀▀ ▐░▌       ▐░▌         █░░█░░█     ▀▀▀▀▀▀█░░█▀▀▀▀▀▀▀ ▐░█▀▀▀▀▀▀▀▀▀ ▐░█▀▀▀▀▀▀▀█░▌  ║
    ║ ▐░▌          ▐░▌       ▐░▌        █░░   ░░█          █░░█        ▐░▌          ▐░▌       ▐░▌  ║
    ║ ▐░▌          ▐░█▄▄▄▄▄▄▄█░▌       █░░     ░░█         █░░█        ▐░█▄▄▄▄▄▄▄▄▄ ▐░█▄▄▄▄▄▄▄█░▌  ║
    ║ ▐░▌          ▐░░░░░░░░░░░▌      █░░       ░░█        █░░█        ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌  ║
    ║ ▐░▌          ▐░█▀▀▀▀▀▀▀█░▌     █░░░████████░░█       █░░█        ▐░█▀▀▀▀▀▀▀▀▀ ▐░█▀▀▀▀█░█▀▀   ║
    ║ ▐░▌          ▐░▌       ▐░▌    █░░           ░░█      █░░█        ▐░▌          ▐░▌     ▐░▌    ║
    ║ ▐░█▄▄▄▄▄▄▄▄▄ ▐░▌       ▐░▌   █░░             ░░█     █░░█        ▐░█▄▄▄▄▄▄▄▄▄ ▐░▌      ▐░▌   ║
    ║ ▐░░░░░░░░░░░▌▐░▌       ▐░▌  █░░               ░░█    █░░█        ▐░░░░░░░░░░░▌▐░▌       ▐░▌  ║
    ║  ▀▀▀▀▀▀▀▀▀▀▀  ▀         ▀   ▀▀▀               ▀▀▀    ▀▀▀▀         ▀▀▀▀▀▀▀▀▀▀▀  ▀         ▀   ║
    ║                                       SYSTEM MONITOR v2.0                                    ║
    ╚══════════════════════════════════════════════════════════════════════════════════════════════╝
"@
    Write-Host $banner -ForegroundColor Cyan
}

function Show-Help {
    Show-CyberBanner
    Write-Host ""
    Write-Host "CYBER HUD - Advanced System Monitoring Tool" -ForegroundColor Green
    Write-Host "===========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Real-time system monitoring dashboard with cyberpunk aesthetics."
    Write-Host "  Monitors CPU, memory, disk usage, network status, security, and development tools."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\chater-hud.ps1                    # Start monitoring with default settings"
    Write-Host "  .\chater-hud.ps1 -Help              # Show this help message"
    Write-Host "  .\chater-hud.ps1 h                  # Show this help message"
    Write-Host ""
    Write-Host "FEATURES:" -ForegroundColor Yellow
    Write-Host "  📊 SYSTEM VITALS"
    Write-Host "     • CPU usage alerts"
    Write-Host "     • Memory consumption"
    Write-Host "     • Disk space"
    Write-Host "     • System temperature"
    Write-Host ""
    Write-Host "  🌐 NETWORK STATUS"
    Write-Host ""
    Write-Host "  🛡️ SECURITY MONITORING"
    Write-Host ""
    Write-Host "  🔧 DEVELOPMENT TOOLS"
    Write-Host "     • Git repo status, Docker container"
    Write-Host ""
    Write-Host "  ⚙️ PROCESS MONITORING"
}

if ($Help -or $Command -eq "h" -or $Command -eq "-h") {
    Show-Help
    return
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null 
$RefreshRate = 10 # seconds
$LogFile = "system_monitor.log"
$AlertThreshold = @{
    CPU = 80
    Memory = 85
    Disk = 90
    Temperature = 70
}


# Enhanced progress bar
function Show-ProgressBar {
    param([double]$Percentage, [string]$Label, [int]$Width = 40, [string]$Color = "Green")
    
    $filled = [math]::Round(($Percentage / 100) * $Width)
    $empty = $Width - $filled

    $bar = "█" * $filled + "░" +  " " * $empty

    $colorCode = "White"
    if ($Color -eq "Red") { $colorCode = "Red" }
    elseif ($Color -eq "Yellow") { $colorCode = "Yellow" }
    elseif ($Color -eq "Green") { $colorCode = "Green" }
    elseif ($Color -eq "Cyan") { $colorCode = "Cyan" }
    elseif ($Color -eq "Magenta") { $colorCode = "Magenta" }
    
    Write-Host "  [$bar] $($Percentage.ToString("00.0"))% $Label" -ForegroundColor $colorCode
}

# System temperature (if available)
function Get-SystemTemperature {
    try {
        $temp = Get-CimInstance -Namespace "root/wmi" -Class "MSAcpi_ThermalZoneTemperature" -ErrorAction SilentlyContinue
        if ($temp) {
            $celsius = ($temp.CurrentTemperature / 10) - 273.15
            return [math]::Round($celsius, 1)
        }
    } catch {}
    return $null
}

# Process monitoring
function Get-TopProcesses {
    return Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU, WorkingSet
}


# Security checks

# Security checks
function Get-SecurityStatus {
    $results = @{}
    
    # Windows Defender status
    try {
        $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
        $results.AntivirusEnabled = $defender.AntivirusEnabled
        $results.LastScan = $defender.AntivirusSignatureLastUpdated
    } catch {
        $results.AntivirusEnabled = "Unknown"
        $results.LastScan = "Unknown"
    }
    
    # Firewall status
    try {
        $firewall = Get-NetFirewallProfile | Where-Object {$_.Enabled -eq $true}
        $results.FirewallEnabled = ($firewall.Count -gt 0)
    } catch {
        $results.FirewallEnabled = "Unknown"
    }
    
    # Failed login attempts (last 24 hours)
    try {
        $since = (Get-Date).AddDays(-1)
        $failedLogins = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=$since} -ErrorAction SilentlyContinue -MaxEvents 10
        if ($failedLogins) {
            $results.FailedLogins = $failedLogins.Count
        } else {
            $results.FailedLogins = 0
        }
    } catch {
        $results.FailedLogins = 0
    }
    
    return $results
}


# Git repository analysis
function Get-GitInfo {
    if (Test-Path .git) {
        try {
            $branch = git rev-parse --abbrev-ref HEAD 2>$null
            $commits = git rev-list --count HEAD 2>$null
            $lastCommit = git log -1 --format="%cr" 2>$null
            $status = git status --porcelain 2>$null
            if ($status) {
                $changes = ($status | Measure-Object).Count
            } else {
                $changes = 0
            }
            
            return @{
                Branch = $branch
                Commits = $commits
                LastCommit = $lastCommit
                UncommittedChanges = $changes
                Status = if($changes -gt 0) { "Modified" } else { "Clean" }
            }
        } catch {
            return @{ Status = "Git Error" }
        }
    }
    return @{ Status = "Not a Git repo" }
}

function Get-NetworkInfo {
    $networkInfo = @{
        ActiveInterfaces = 0
        Interfaces = @()
        InternetConnected = $false
        Status = "OK"
    }
    
    try {
        # Get active network adapters with more lenient filtering
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
            $_.Status -eq "Up" -and 
            $_.InterfaceDescription -notlike "*Loopback*" -and
            $_.InterfaceDescription -notlike "*Teredo*" -and
            $_.Name -notlike "*Loopback*"
        }
        
        if (-not $adapters) {
            # Fallback: try to get any "Up" adapter
            $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Up"}
        }
        
        $networkInfo.ActiveInterfaces = if ($adapters) { $adapters.Count } else { 0 }
        
        # Process each adapter
        if ($adapters) {
            foreach ($adapter in $adapters | Select-Object -First 3) {
                $interfaceInfo = @{
                    Name = $adapter.Name
                    IP = "N/A"
                    Speed = "Unknown"
                    BytesSent = 0
                    BytesReceived = 0
                }
                
                # Get IP address - try multiple methods
                try {
                    $ip = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
                          Where-Object {$_.PrefixOrigin -ne "WellKnown"} | 
                          Select-Object -First 1
                    
                    if ($ip -and $ip.IPAddress) {
                        $interfaceInfo.IP = $ip.IPAddress
                    }
                } catch {
                    # Ignore IP retrieval errors for individual adapters
                }
                
                # Get link speed
                try {
                    if ($adapter.LinkSpeed -and $adapter.LinkSpeed -gt 0) {
                        $speedMbps = [math]::Round($adapter.LinkSpeed / 1000000, 0)
                        $interfaceInfo.Speed = "$speedMbps Mbps"
                    }
                } catch {
                    # Ignore speed errors
                }
                
                # Get statistics
                try {
                    $stats = Get-NetAdapterStatistics -Name $adapter.Name -ErrorAction SilentlyContinue
                    if ($stats) {
                        $interfaceInfo.BytesSent = [math]::Round($stats.BytesSent / 1MB, 2)
                        $interfaceInfo.BytesReceived = [math]::Round($stats.BytesReceived / 1MB, 2)
                    }
                } catch {
                    # Ignore stats errors
                }
                
                $networkInfo.Interfaces += $interfaceInfo
            }
        }
        
        # Test connectivity - try multiple methods
        $connectivity = $false
        
        # Method 1: Test-Connection to Google DNS
        try {
            $connectivity = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -TimeoutSeconds 3 -ErrorAction SilentlyContinue
        } catch {
            $connectivity = $false
        }
        
        # Method 2: If first test fails, try Cloudflare DNS
        if (-not $connectivity) {
            try {
                $connectivity = Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet -TimeoutSeconds 3 -ErrorAction SilentlyContinue
            } catch {
                $connectivity = $false
            }
        }
        
        $networkInfo.InternetConnected = $connectivity
        
        return $networkInfo
        
    } catch {
        # Only return error status if we can't get basic network info
        Write-Warning "Network function error: $($_.Exception.Message)"
        return @{ 
            Status = "Network Error: $($_.Exception.Message)"
            ActiveInterfaces = 0
            Interfaces = @()
            InternetConnected = $false
        }
    }
}


# Main HUD display
function Show-CyberHUD {
    Clear-Host
    Show-CyberBanner
    
    Write-Host "`n┌─ SYSTEM VITALS " -NoNewline -ForegroundColor Cyan
    Write-Host ("-" * 61 + "|") -ForegroundColor DarkCyan
    
    # CPU Usage
    $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
    $cpuColor = "Green"
    if ($cpu -gt $AlertThreshold.CPU) {
        $cpuColor = "Red"
    } elseif ($cpu -gt 50) {
        $cpuColor = "Yellow"
    }
    Show-ProgressBar -Percentage $cpu -Label "CPU USAGE" -Color $cpuColor
    
    # Memory Usage
    $mem = Get-CimInstance Win32_OperatingSystem
    $totalMem = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 2)
    $freeMem = [math]::Round($mem.FreePhysicalMemory / 1MB, 2)
    $usedMem = [math]::Round($totalMem - $freeMem, 2)
    $memPercent = [math]::Round(($usedMem / $totalMem) * 100, 1)
    $memColor = "Green"
    if ($memPercent -gt $AlertThreshold.Memory) {
        $memColor = "Red"
    } elseif ($memPercent -gt 60) {
        $memColor = "Yellow"
    }
    Show-ProgressBar -Percentage $memPercent -Label "MEMORY ($usedMem/$totalMem GB)" -Color $memColor
    
    # Disk Usage
    $disk = Get-PSDrive C
    $totalDisk = [math]::Round(($disk.Used + $disk.Free) / 1GB, 2)
    $usedDisk = [math]::Round($disk.Used / 1GB, 2)
    $diskPercent = [math]::Round(($usedDisk / $totalDisk) * 100, 1)
    $diskColor = "Cyan"
    if ($diskPercent -gt $AlertThreshold.Disk) {
        $diskColor = "Red"
    } elseif ($diskPercent -gt 75) {
        $diskColor = "Yellow"
    }
    Show-ProgressBar -Percentage $diskPercent -Label "DISK C: ($usedDisk/$totalDisk GB)" -Color $diskColor
    
    # Temperature (if available)
    $temp = Get-SystemTemperature
    if ($temp) {
        $tempColor = "Green"
        if ($temp -gt $AlertThreshold.Temperature) {
            $tempColor = "Red"
        } elseif ($temp -gt 50) {
            $tempColor = "Yellow"
        }
        Show-ProgressBar -Percentage ($temp * 1.25) -Label "TEMP ($temp°C)" -Color $tempColor -Width 30
    }
    
    Write-Host "`n|- NETWORK STATUS " -NoNewline -ForegroundColor Cyan
    Write-Host ("-" * 60 + "|") -ForegroundColor DarkCyan
    
    $netInfo = Get-NetworkInfo
    if ($netInfo.Status) {
        $connectionStatus = "❌"
        $connectionColor = "Red"
        if ($netInfo.InternetConnected) {
            $connectionStatus = "🌐"
            $connectionColor = "Green"
        }
        
        Write-Host "  Internet: " -NoNewline
        Write-Host $connectionStatus -ForegroundColor $connectionColor
        
        Write-Host "   Active Interfaces: $($netInfo.ActiveInterfaces)" -ForegroundColor Cyan
        
        foreach ($interface in $netInfo.Interfaces | Select-Object -First 2) {
            Write-Host "    └- $($interface.Name): $($interface.IP) [$($interface.Speed)]" -ForegroundColor Gray
            Write-Host "        Sent: $($interface.BytesSent)MB  Recv: $($interface.BytesReceived)MB" -ForegroundColor DarkGray
        }
    } else {
        Write-Host " ⚠️   $($netInfo.Status)" -ForegroundColor Red
        
    }
    
    Write-Host "`n|- SECURITY STATUS " -NoNewline -ForegroundColor Cyan
    Write-Host ("-" * 59 + "|") -ForegroundColor DarkCyan
    
    $security = Get-SecurityStatus
    
    $avIcon = if($security.AntivirusEnabled -eq $true) {"🛡️"} else {"⚠️"}
    $avColor = if($security.AntivirusEnabled -eq $true) {"Green"} else {"Red"}
    Write-Host "  $avIcon Antivirus: " -NoNewline
    Write-Host $security.AntivirusEnabled -ForegroundColor $avColor

    $fwIcon = if($security.FirewallEnabled -eq $true) {"🛡️"} else {"❌"}
    $fwColor = if($security.FirewallEnabled -eq $true) {"Green"} else {"Red"}
    Write-Host "  $fwIcon Firewall: " -NoNewline
    Write-Host $security.FirewallEnabled -ForegroundColor $fwColor
    
    $failColor = "Green"
    if ($security.FailedLogins -gt 5) {
        $failColor = "Red"
    } elseif ($security.FailedLogins -gt 0) {
        $failColor = "Yellow"
    }
    Write-Host "  Failed Logins (24h): " -NoNewline
    Write-Host $security.FailedLogins -ForegroundColor $failColor
    
    Write-Host "`n|- DEVELOPMENT STATUS " -NoNewline -ForegroundColor Cyan
    Write-Host ("-" * 56 + "|") -ForegroundColor DarkCyan
    
    # Git Information
    $git = Get-GitInfo
    if ($git.Status -eq "Not a Git repo" -or $git.Status -eq "Git Error") {
        Write-Host "  🌿 $($git.Status)" -ForegroundColor DarkGray
    } else {
        $statusColor = "Green"
        if ($git.Status -ne "Clean") {
            $statusColor = "Yellow"
        }
        $statusIcon = if($git.Status -eq "Clean") {"✅"} else {"⚡"}

        Write-Host " 🌿 [GIT] Branch: $($git.Branch) | Status: " -NoNewline -ForegroundColor Blue
        Write-Host "$($git.Status)" -ForegroundColor $statusColor
        Write-Host "       |- Commits: $($git.Commits) | Last: $($git.LastCommit)" -ForegroundColor Gray
        if ($git.UncommittedChanges -gt 0) {
            Write-Host "       |- Uncommitted changes: $($git.UncommittedChanges)" -ForegroundColor Yellow
        }
    }
    
    # Docker Status
    Write-Host "  🐳 Docker: " -NoNewline
    try {
        $dockerOutput = docker ps -q 2>$null
        if ($LASTEXITCODE -eq 0 -and $dockerOutput) {
            $dockerCount = ($dockerOutput | Measure-Object).Count
            Write-Host "$dockerCount container(s) running" -ForegroundColor Green
        } elseif ($LASTEXITCODE -eq 0) {
            Write-Host "Running, no containers" -ForegroundColor Yellow
        } else {
            Write-Host "Not running" -ForegroundColor Red
        }
    } catch {
        Write-Host "Not installed" -ForegroundColor DarkGray
    }
    
    Write-Host "`n|- TOP PROCESSES " -NoNewline -ForegroundColor Cyan
    Write-Host ("-" * 61 + "|") -ForegroundColor DarkCyan
    
    $processes = Get-TopProcesses
    foreach ($proc in $processes) {
        if ($proc.CPU) {
            $cpu = [math]::Round($proc.CPU, 1)
        } else {
            $cpu = 0
        }
        $memory = [math]::Round($proc.WorkingSet / 1MB, 1)
        Write-Host " ⚙️  $($proc.Name.PadRight(20)) CPU: $($cpu.ToString().PadLeft(6))% | RAM: $($memory.ToString().PadLeft(6))MB" -ForegroundColor Gray
    }
    
    # System uptime
    $uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $uptimeSpan = (Get-Date) - $uptime
    $uptimeStr = "{0:dd}d {0:hh}h {0:mm}m" -f $uptimeSpan
    
    Write-Host "`n|- SYSTEM INFO " -NoNewline -ForegroundColor Cyan
    Write-Host ("-" * 63 + "|") -ForegroundColor DarkCyan
    Write-Host " ⏱️    Uptime: $uptimeStr" -ForegroundColor Magenta
    Write-Host " 💻    Host: $env:COMPUTERNAME" -ForegroundColor Blue
    Write-Host " 👤    User: $env:USERNAME" -ForegroundColor Blue

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "`n|=============================================================================|" -ForegroundColor DarkCyan
    Write-Host "| SCAN COMPLETE | $timestamp | Refresh: ${RefreshRate}s | Ctrl+C to exit    |" -ForegroundColor DarkCyan
    Write-Host "|=============================================================================|" -ForegroundColor DarkCyan
}

# Logging function
function Write-SystemLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logEntry
}

# Alert system
function Check-SystemAlerts {
    $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
    
    if ($cpu -gt $AlertThreshold.CPU) {
        Write-SystemLog "HIGH CPU USAGE: $cpu%" "ALERT"
        Write-Host "`n ALERT: High CPU usage detected ($cpu%)" -ForegroundColor Red -BackgroundColor Black
    }
    
    # Add more alert conditions as needed
}

# Main execution
Write-Host "Initializing CYBER SYSTEM MONITOR..." -ForegroundColor Green
Write-SystemLog "System monitor started"

try {
    while ($true) {
        Show-CyberHUD
        Check-SystemAlerts
        Start-Sleep -Seconds $RefreshRate
    }
} catch [System.OperationCanceledException] {
    Write-Host "`n🛑 MONITOR TERMINATED BY USER" -ForegroundColor Yellow
    Write-SystemLog "Monitor stopped by user"
} catch {
    Write-Host "`n💥 CRITICAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-SystemLog "Error: $($_.Exception.Message)" "ERROR"
} finally {
    Write-Host "Shutting down systems..." -ForegroundColor Gray
    Write-SystemLog "Monitor shutdown"
}