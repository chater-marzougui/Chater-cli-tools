param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$functionStartTime = Get-Date

# Help function
function Show-Help {
    param(
        [bool]$isSmall = $false
    )
    Write-Host ""
    Write-Host "Port Scanner and Process Manager" -ForegroundColor Cyan
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Scan ports, identify running processes, and kill applications by port."
    Write-Host "  Perfect for finding and stopping forgotten background applications."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-port scan <port-range>       # Scan port range (e.g., 3000-3010)" -ForegroundColor Green
    Write-Host "  chater-port scan <single-port>      # Scan single port (e.g., 8080)" -ForegroundColor Green
    Write-Host "  chater-port who <port>              # Show what's running on port" -ForegroundColor Green
    Write-Host "  chater-port kill <port>             # Kill process using port" -ForegroundColor Green
    Write-Host "  chater-port listen                  # Show all listening ports" -ForegroundColor Green
    Write-Host "  chater-port busy                    # Show commonly busy dev ports" -ForegroundColor Green
    Write-Host "  chater-port -h                      # Show this help message" -ForegroundColor Green
    Write-Host "  chater-port help                    # Show this help message" -ForegroundColor Green
    Write-Host ""
    if ($isSmall) {
        return
    }
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  chater-port scan 3000-3010         # Scan development port range" -ForegroundColor Green
    Write-Host "  chater-port scan 8080               # Check if port 8080 is free" -ForegroundColor Green
    Write-Host "  chater-port who 3000                # See what's using port 3000" -ForegroundColor Green
    Write-Host "  chater-port kill 8080               # Kill process on port 8080" -ForegroundColor Green
    Write-Host "  chater-port listen                  # List all active connections" -ForegroundColor Green
    Write-Host "  chater-port busy                    # Quick check of common ports" -ForegroundColor Green
    Write-Host ""
}

function Test-PortOpen {
    param(
        [string]$HostLink = "localhost",
        [int]$Port,
        [int]$Timeout = 1000
    )
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($HostLink, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($Timeout, $false)
        
        if ($wait) {
            $tcpClient.EndConnect($connect)
            $tcpClient.Close()
            return $true
        } else {
            $tcpClient.Close()
            return $false
        }
    } catch {
        return $false
    }
}

function Get-ProcessByPort {
    param([int]$Port)
    
    try {
        $netstat = netstat -ano | Where-Object { $_ -match ":$Port\s" }
        
        if ($netstat) {
            foreach ($line in $netstat) {
                if ($line -match '\s+(\d+)\s*$') {
                    $processId = $matches[1]
                    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue

                    if ($process) {
                        return @{
                            PID = $processId
                            ProcessName = $process.ProcessName
                            Path = try { $process.Path } catch { "N/A" };
                            StartTime = try { $process.StartTime } catch { "N/A" }
                        }
                    }
                }
            }
        }
        return $null
    } catch {
        return $null
    }
}

function Scan_PortRange {
    param(
        [int]$StartPort,
        [int]$EndPort
    )
    
    Write-Host ""
    Write-Host "🔍 Scanning ports $StartPort-$EndPort..." -ForegroundColor Cyan
    Write-Host ""
    
    $openPorts = @()
    $totalPorts = $EndPort - $StartPort + 1
    $scanned = 0
    
    for ($port = $StartPort; $port -le $EndPort; $port++) {
        $scanned++
        $progress = [math]::Round(($scanned / $totalPorts) * 100, 1)
        
        # Show progress for larger ranges
        if ($totalPorts -gt 10) {
            Write-Progress -Activity "Scanning Ports" -Status "$progress% Complete" -PercentComplete $progress
        }
        
        if (Test-PortOpen -Port $port) {
            $processInfo = Get-ProcessByPort -Port $port
            $openPorts += @{
                Port = $port
                Process = $processInfo
            }
        }
    }
    
    if ($totalPorts -gt 10) {
        Write-Progress -Activity "Scanning Ports" -Completed
    }
    
    if ($openPorts.Count -eq 0) {
        Write-Host "✅ All ports in range are available" -ForegroundColor Green
    } else {
        Write-Host "📋 Open Ports Found:" -ForegroundColor Yellow
        Write-Host "===================" -ForegroundColor Yellow
        
        foreach ($portInfo in $openPorts) {
            $port = $portInfo.Port
            $process = $portInfo.Process
            
            Write-Host ""
            Write-Host "🔴 Port $port is BUSY" -ForegroundColor Red
            
            if ($process) {
                Write-Host "   Process: $($process.ProcessName) (PID: $($process.PID))" -ForegroundColor White
                if ($process.Path -ne "N/A") {
                    Write-Host "   Path: $($process.Path)" -ForegroundColor Gray
                }
                if ($process.StartTime -ne "N/A") {
                    $runtime = (Get-Date) - $process.StartTime
                    Write-Host "   Running: $($runtime.Hours)h $($runtime.Minutes)m" -ForegroundColor Gray
                }
            } else {
                Write-Host "   Process: Unable to identify" -ForegroundColor Gray
            }
        }
    }
    Write-Host ""
}

function Show-PortProcess {
    param([int]$Port)
    
    Write-Host ""
    Write-Host "🔍 Checking port $Port..." -ForegroundColor Cyan
    
    if (-not (Test-PortOpen -Port $Port)) {
        Write-Host "✅ Port $Port is available" -ForegroundColor Green
        Write-Host ""
        return
    }
    
    Write-Host "🔴 Port $Port is busy" -ForegroundColor Red
    
    $process = Get-ProcessByPort -Port $Port
    if ($process) {
        Write-Host ""
        Write-Host "📋 Process Details:" -ForegroundColor Yellow
        Write-Host "=================" -ForegroundColor Yellow
        Write-Host "Process Name: $($process.ProcessName)" -ForegroundColor White
        Write-Host "PID: $($process.PID)" -ForegroundColor White
        
        if ($process.Path -ne "N/A") {
            Write-Host "Path: $($process.Path)" -ForegroundColor Gray
        }
        
        if ($process.StartTime -ne "N/A") {
            $runtime = (Get-Date) - $process.StartTime
            Write-Host "Running Time: $($runtime.Hours)h $($runtime.Minutes)m" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "💡 To kill this process: chater-port kill $Port" -ForegroundColor Yellow
    } else {
        Write-Host "❌ Unable to identify the process using this port" -ForegroundColor Red
    }
    Write-Host ""
}

function Kill_ProcessByPort {
    param([int]$Port)
    
    Write-Host ""
    Write-Host "🔍 Looking for process on port $Port..." -ForegroundColor Cyan
    
    if (-not (Test-PortOpen -Port $Port)) {
        Write-Host "✅ Port $Port is already free" -ForegroundColor Green
        Write-Host ""
        return
    }
    
    $process = Get-ProcessByPort -Port $Port
    if (-not $process) {
        Write-Host "❌ Unable to find process using port $Port" -ForegroundColor Red
        Write-Host ""
        return
    }
    
    Write-Host "🎯 Found process: $($process.ProcessName) (PID: $($process.PID))" -ForegroundColor Yellow
    
    try {
        Stop-Process -Id $process.PID -Force -ErrorAction Stop
        Start-Sleep -Milliseconds 500
        
        # Verify the port is now free
        if (-not (Test-PortOpen -Port $Port)) {
            Write-Host "✅ Successfully killed process and freed port $Port" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Process terminated but port might still be in use" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ Failed to kill process: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

function Show-ListeningPorts {
    Write-Host ""
    Write-Host "🌐 Active Listening Ports" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    
    try {
        $connections = netstat -an | Where-Object { $_ -match 'LISTENING' -and $_ -match 'TCP' }
        
        if (-not $connections) {
            Write-Host "No listening ports found" -ForegroundColor Yellow
            Write-Host ""
            return
        }
        
        $portList = @()
        
        foreach ($line in $connections) {
            if ($line -match ':(\d+)\s+.*LISTENING') {
                $port = [int]$matches[1]
                $process = Get-ProcessByPort -Port $port
                
                $portList += @{
                    Port = $port
                    Process = if ($process) { "$($process.ProcessName) (PID: $($process.PID))" } else { "Unknown" }
                }
            }
        }
        
        # Sort by port number
        $portList = $portList | Sort-Object { [int]$_.Port }
        
        Write-Host ""
        foreach ($item in $portList) {
            Write-Host "🔵 Port $($item.Port)" -NoNewline -ForegroundColor Blue
            Write-Host " - $($item.Process)" -ForegroundColor White
        }
    } catch {
        Write-Host "❌ Error retrieving listening ports: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

function Show-CommonBusyPorts {
    $commonPorts = @(3000, 3001, 4200, 5000, 5500, 5173, 8000, 8080, 8545, 27017)
    
    Write-Host ""
    Write-Host "🚀 Common Development Ports Status" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($port in $commonPorts) {
        $isOpen = Test-PortOpen -Port $port
        $status = if ($isOpen) { "🔴 BUSY" } else { "✅ FREE" }
        $color = if ($isOpen) { "Red" } else { "Green" }
        
        Write-Host "Port $port" -NoNewline -ForegroundColor White
        Write-Host " - $status" -ForegroundColor $color
        
        if ($isOpen) {
            $process = Get-ProcessByPort -Port $port
            if ($process) {
                Write-Host "         $($process.ProcessName) (PID: $($process.PID))" -ForegroundColor Gray
            }
        }
    }
    Write-Host ""
}

# Check for help

$helpArgs = @("-h", "--h", "help", "-Help")
if ($Arguments.Count -eq 0 -or ($Arguments.Count -le 2 -and ($helpArgs -contains $Arguments[0]))) {
    $isSmall = ($Arguments -contains "--small")
    Show-Help -isSmall $isSmall
    return
}

# Parse command
$command = $Arguments[0].ToLower()

try {
    switch ($command) {
        "scan" {
            if ($Arguments.Count -lt 2) {
                Write-Host "❌ Error: Missing port or port range" -ForegroundColor Red
                Write-Host "Usage: chater-port scan <port> or chater-port scan <start-end>" -ForegroundColor Yellow
                return
            }
            
            $portArg = $Arguments[1]
            if ($portArg -match '^(\d+)-(\d+)$') {
                # Range scan
                $startPort = [int]$matches[1]
                $endPort = [int]$matches[2]
                
                if ($startPort -gt $endPort) {
                    Write-Host "❌ Error: Start port must be less than end port" -ForegroundColor Red
                    return
                }
                
                if ($endPort - $startPort -gt 1000) {
                    Write-Host "❌ Error: Port range too large (max 1000 ports)" -ForegroundColor Red
                    return
                }
                
                Scan_PortRange -StartPort $startPort -EndPort $endPort
            } elseif ($portArg -match '^\d+$') {
                # Single port scan
                $port = [int]$portArg
                Show-PortProcess -Port $port
            } else {
                Write-Host "❌ Error: Invalid port format" -ForegroundColor Red
                Write-Host "Use: chater-port scan 8080 or chater-port scan 3000-3010" -ForegroundColor Yellow
            }
        }
        
        "who" {
            if ($Arguments.Count -lt 2) {
                Write-Host "❌ Error: Missing port number" -ForegroundColor Red
                Write-Host "Usage: chater-port who <port>" -ForegroundColor Yellow
                return
            }
            
            if ($Arguments[1] -match '^\d+$') {
                $port = [int]$Arguments[1]
                Show-PortProcess -Port $port
            } else {
                Write-Host "❌ Error: Invalid port number" -ForegroundColor Red
            }
        }
        
        "kill" {
            if ($Arguments.Count -lt 2) {
                Write-Host "❌ Error: Missing port number" -ForegroundColor Red
                Write-Host "Usage: chater-port kill <port>" -ForegroundColor Yellow
                return
            }
            
            if ($Arguments[1] -match '^\d+$') {
                $port = [int]$Arguments[1]
                Kill_ProcessByPort -Port $port
            } else {
                Write-Host "❌ Error: Invalid port number" -ForegroundColor Red
            }
        }
        
        "listen" {
            Show-ListeningPorts
        }
        
        "busy" {
            Show-CommonBusyPorts
        }
        
        default {
            Write-Host "❌ Error: Unknown command '$command'" -ForegroundColor Red
            Write-Host "Available commands: scan, who, kill, listen, busy" -ForegroundColor Yellow
            Write-Host "Use 'chater-port help' for more information" -ForegroundColor Gray
        }
    }
    
    # Show timing (only for successful operations)
    if ($command -in @("scan", "who", "kill", "listen", "busy")) {
        $totalDuration = (Get-Date) - $functionStartTime
        Write-Host "⚡ Completed in $($totalDuration.TotalMilliseconds) ms" -ForegroundColor DarkGray
    }
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}