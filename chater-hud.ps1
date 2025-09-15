param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$location = Get-Location


$envFilePath = Join-Path $PSScriptRoot ".env"
$scriptDir = (Get-Content $envFilePath | Where-Object { $_ -match "^MAIN_SCRIPTS_PATH=" }) -replace "MAIN_SCRIPTS_PATH=", ""
if (-Not $scriptDir) { $scriptDir = "C:\custom-scripts" } else { $scriptDir = $scriptDir.Trim().Trim('"').Trim("'") }
$helpers = Join-Path $scriptDir "helpers\hud-functions.ps1"
$logFile = Join-Path $scriptDir "logs\system-monitor.log"
. $helpers

# Professional System Monitor Configuration
$Script:Config = @{
    RefreshInterval = 5000  # Milliseconds
    AlertThresholds = @{
        CPU = 85
        Memory = 90
        Disk = 95
        Temperature = 75
    }
    LogFile = $logFile
    MaxLogSize = 10MB
    UpdateOnlyChanged = $true
}

# State tracking for selective updates
$Script:LastState = @{}
$Script:LinePositions = @{}
$Script:IsInitialized = $false

Add-Type -AssemblyName "System.Net.Http"

#region Helper Functions
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    try {
        # Rotate log if it gets too large
        if (Test-Path $Script:Config.LogFile) {
            $logSize = (Get-Item $Script:Config.LogFile).Length
            if ($logSize -gt $Script:Config.MaxLogSize) {
                $backupLog = $Script:Config.LogFile -replace '\.log$', '-backup.log'
                Move-Item $Script:Config.LogFile $backupLog -Force
            }
        }
        
        Add-Content -Path $Script:Config.LogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # Silent fail for logging to avoid disrupting the main display
    }
}

function Get-ProgressBar {
    param(
        [double]$Percentage,
        [int]$Width = 30,
        [ValidateSet('Normal', 'Warning', 'Critical')]
        [string]$Status = 'Normal'
    )
    
    $filled = [math]::Min([math]::Round(($Percentage / 100) * $Width), $Width)
    $empty = $Width - $filled
    
    $bar = switch ($Status) {
        'Critical' { "█" * $filled + "░" * $empty }
        'Warning'  { "▓" * $filled + "░" * $empty }
        default    { "▓" * $filled + "░" * $empty }
    }
    
    $color = switch ($Status) {
        'Critical' { 'Red' }
        'Warning'  { 'Yellow' }
        default    { 'Green' }
    }
    
    return @{
        Bar = $bar
        Color = $color
        Text = "$($Percentage.ToString('00.0'))%"
    }
}

function Update-ConsoleLine {
    param(
        [int]$Line,
        [string]$Content,
        [string]$Color = 'White'
    )
    
    if (-not $Script:IsInitialized) { return }
    
    $currentPos = $Host.UI.RawUI.CursorPosition
    if ($Line -ge $Host.UI.RawUI.WindowSize.Height) {
        Write-Host ""  # This will naturally scroll the console
        # $Line = $Host.UI.RawUI.WindowSize.Height - 1    
    }
    $Host.UI.RawUI.CursorPosition = @{ X = 0; Y = $Line }
    
    # Clear the line
    Write-Host (' ' * $Host.UI.RawUI.WindowSize.Width) -NoNewline
    $Host.UI.RawUI.CursorPosition = @{ X = 0; Y = $Line }
    
    # Write new content
    Write-Host $Content -ForegroundColor $Color -NoNewline
    
    # Restore cursor position
    $Host.UI.RawUI.CursorPosition = $currentPos
}

#region Display Functions
function Show-Header {
    Write-Host ""
    Write-Host "System Monitor" -ForegroundColor Blue
    Write-Host ("=" * 50) -ForegroundColor DarkBlue
    Write-Host ""
    Write-Host ""
}

function Show-SystemStatus {
    param([hashtable]$Metrics, [int]$StartLine)
    
    $line = $StartLine
    $Script:LinePositions['SystemHeader'] = $line
    
    if (-not $Script:IsInitialized -or (Compare-StateChange 'System' $Metrics)) {
        Update-ConsoleLine $line "SYSTEM RESOURCES" 'Cyan'
        $line++
        Update-ConsoleLine $line ("-" * 40) 'DarkCyan'
        $line++
        
        # CPU
        $cpuStatus = if ($Metrics.CPU -gt $Script:Config.AlertThresholds.CPU) { 'Critical' } 
                    elseif ($Metrics.CPU -gt 70) { 'Warning' } 
                    else { 'Normal' }
        
        $cpuBar = Get-ProgressBar -Percentage $Metrics.CPU -Status $cpuStatus
        Update-ConsoleLine $line ("CPU Usage    [{0}] {1}" -f $cpuBar.Bar, $cpuBar.Text) $cpuBar.Color
        $line++
        
        # Memory
        $memStatus = if ($Metrics.Memory.Percent -gt $Script:Config.AlertThresholds.Memory) { 'Critical' }
                    elseif ($Metrics.Memory.Percent -gt 75) { 'Warning' }
                    else { 'Normal' }
        
        $memBar = Get-ProgressBar -Percentage $Metrics.Memory.Percent -Status $memStatus
        $memText = "Memory Usage [{0}] {1} ({2:N1}/{3:N1} GB)" -f $memBar.Bar, $memBar.Text, $Metrics.Memory.Used, $Metrics.Memory.Total
        Update-ConsoleLine $line $memText $memBar.Color
        $line++
        
        # Disk
        if ($Metrics.Disk) {
            $diskStatus = if ($Metrics.Disk.Percent -gt $Script:Config.AlertThresholds.Disk) { 'Critical' }
                         elseif ($Metrics.Disk.Percent -gt 80) { 'Warning' }
                         else { 'Normal' }
            
            $diskBar = Get-ProgressBar -Percentage $Metrics.Disk.Percent -Status $diskStatus
            $diskText = "Disk Usage   [{0}] {1} ({2:N1}/{3:N1} GB)" -f $diskBar.Bar, $diskBar.Text, $Metrics.Disk.Used, $Metrics.Disk.Total
            Update-ConsoleLine $line $diskText $diskBar.Color
            $line++
        }
        
        # Temperature
        if ($Metrics.Temperature) {
            $tempStatus = if ($Metrics.Temperature -gt $Script:Config.AlertThresholds.Temperature) { 'Critical' }
                         elseif ($Metrics.Temperature -gt 60) { 'Warning' }
                         else { 'Normal' }
            
            $tempBar = Get-ProgressBar -Percentage ($Metrics.Temperature * 1.25) -Status $tempStatus -Width 20
            $tempText = "Temperature  [{0}] {1:N1}°C" -f $tempBar.Bar, $Metrics.Temperature
            Update-ConsoleLine $line $tempText $tempBar.Color
            $line++
        }
        
        # Uptime
        $uptimeText = "Uptime: {0}d {1}h {2}m ({3:N1} total hours)" -f $Metrics.Uptime.Days, $Metrics.Uptime.Hours, $Metrics.Uptime.Minutes, $Metrics.Uptime.TotalHours
        Update-ConsoleLine $line $uptimeText 'Gray'
        $line++
        
        Update-ConsoleLine $line "" 'White'
        $line++
    }
    
    return $line
}

function Show-NetworkStatus {
    param([hashtable]$Network, [int]$StartLine)
    
    $line = $StartLine
    
    if (-not $Script:IsInitialized -or (Compare-StateChange 'Network' $Network)) {
        Update-ConsoleLine $line "NETWORK STATUS" 'Cyan'
        $line++
        Update-ConsoleLine $line ("-" * 40) 'DarkCyan'
        $line++
        
        # Internet connectivity
        $internetIcon = if ($Network.InternetConnected) { "✓" } else { "✗" }
        $internetColor = if ($Network.InternetConnected) { "Green" } else { "Red" }
        $internetText = "Internet Connection: {0} {1}" -f $internetIcon, $(if($Network.InternetConnected) {"Connected"} else {"Disconnected"})
        Update-ConsoleLine $line $internetText $internetColor
        $line++
        
        # Active interfaces
        $interfaceText = "Active Interfaces: {0}" -f $Network.Interfaces.Count
        Update-ConsoleLine $line $interfaceText 'White'
        $line++
        
        # Interface details
        foreach ($interface in $Network.Interfaces | Select-Object -First 3) {
            $pro = if ($interface.Status -eq "Up") { "✓" } else { "✗" }
            $pred = if($interface -eq $Network.Interfaces[2]) { "└─" } else { "├─" }
            $interfaceDetail = "  {0} {1}: {2} [{3}] {4}" -f $pred, $interface.Name, $interface.IP, $interface.Speed, $pro
            Update-ConsoleLine $line $interfaceDetail 'Gray'
            $line++
        }
        
        Update-ConsoleLine $line "" 'White'
        $line++
    }
    
    return $line
}

function Show-ProcessStatus {
    param([array]$Processes, [int]$StartLine)
    
    $line = $StartLine
    
    if (-not $Script:IsInitialized -or (Compare-StateChange 'Processes' $Processes)) {
        Update-ConsoleLine $line "TOP PROCESSES" 'Cyan'
        $line++
        Update-ConsoleLine $line ("-" * 40) 'DarkCyan'
        $line++
        
        foreach ($proc in $Processes) {
            $shownPIDs = $proc.PID.Split(",")[0..([math]::Min(2, ($proc.PID.Split(",").Count - 1)))] -join ","
            $procText = "{0,-20} CPU: {1,6:N1}% RAM: {2,6:N1}MB PID: {3}" -f $proc.Name, ($proc.CPU / 10000), $proc.Memory, $shownPIDs
            Update-ConsoleLine $line $procText 'White'
            $line++
        }
        
        Update-ConsoleLine $line "" 'White'
        $line++
    }
    
    return $line
}

function Show-DevelopmentStatus {
    param([hashtable]$Development, [int]$StartLine)
    
    $line = $StartLine
    
    if (-not $Script:IsInitialized -or (Compare-StateChange 'Development' $Development)) {
        Update-ConsoleLine $line "DEVELOPMENT ENVIRONMENT" 'Cyan'
        $line++
        Update-ConsoleLine $line ("-" * 40) 'DarkCyan'
        $line++
        
        # Git status
        if ($Development.Git.Status -ne "Not a Git repository") {
            $gitIcon = if ($Development.Git.Status -eq "Clean") { "✓" } else { "⚡" }
            $gitColor = if ($Development.Git.Status -eq "Clean") { "Green" } else { "Yellow" }
            $gitText = "Git Repository: {0} {1}" -f $gitIcon, $Development.Git.Status
            Update-ConsoleLine $line $gitText $gitColor
            $line++
            
            if ($Development.Git.Branch) {
                $branchText = "  Branch: {0}" -f $Development.Git.Branch
                Update-ConsoleLine $line $branchText 'Gray'
                $line++
            }
            
            if ($Development.Git.Changes -gt 0) {
                $changesText = "  Uncommitted Changes: {0}" -f $Development.Git.Changes
                Update-ConsoleLine $line $changesText 'Yellow'
                $line++
            }
        } else {
            Update-ConsoleLine $line "Git Repository: Not initialized" 'Gray'
            $line++
        }
        
        # Docker status
        if ($Development.Docker.Status -eq "Running") {
            $dockerText = "Docker: Running ({0} containers)" -f $Development.Docker.Containers
            $dockerColor = if ($Development.Docker.Containers -gt 0) { "Green" } else { "Yellow" }
            Update-ConsoleLine $line $dockerText $dockerColor
            $line++
        } else {
            Update-ConsoleLine $line "Docker: Not available" 'Gray'
            $line++
        }
        
        # Runtime environments
        if ($Development.Node.Status -eq "Installed") {
            $nodeText = "Node.js: {0}" -f $Development.Node.Version
            Update-ConsoleLine $line $nodeText 'Green'
            $line++
        }
        
        if ($Development.Python.Status -eq "Installed") {
            $pythonText = "Python: {0}" -f $Development.Python.Version
            Update-ConsoleLine $line $pythonText 'Green'
            $line++
        }
        
        Update-ConsoleLine $line "" 'White'
        $line++
    }
    
    return $line
}

function Show-Footer {
    param([int]$StartLine, [bool]$isFirst)
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $footerText = "Time: {0} | Refresh: {1}ms | Press Ctrl+C to exit" -f $timestamp, $Script:Config.RefreshInterval

    if($isFirst) {
        Update-ConsoleLine $StartLine ("-" * 60) 'DarkGray'
    }
    Update-ConsoleLine ($StartLine + 1) $footerText 'DarkGray'
}

function Compare-StateChange {
    param([string]$Section, $CurrentData)
    
    if (-not $Script:Config.UpdateOnlyChanged) {
        return $true
    }
    
    $currentJson = $CurrentData | ConvertTo-Json -Compress -Depth 10
    $lastJson = $Script:LastState[$Section]
    
    if ($currentJson -ne $lastJson) {
        $Script:LastState[$Section] = $currentJson
        return $true
    }
    
    return $false
}
#endregion

#region Help and Main Functions
function Show-Help {
    param([bool]$Small = $false)
    
    Write-Host ""
    Write-Host "System Monitor - Professional Edition" -ForegroundColor Blue
    Write-Host "====================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "  Professional real-time system monitoring tool with selective updates."
    Write-Host "  Monitors system resources, network, security, and development environment."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  chater-hud                       # Start system monitor" -ForegroundColor Green
    Write-Host "  chater-hud help                  # Show this help message" -ForegroundColor Green
    Write-Host "  chater-hud -h                    # Show this help message" -ForegroundColor Green
    Write-Host ""
    
    if ($Small) { return }
    
    Write-Host "FEATURES:" -ForegroundColor Yellow
    Write-Host "  • Real-time system metrics (CPU, Memory, Disk)"
    Write-Host "  • Network interface monitoring"
    Write-Host "  • Security status (Windows Defender, Firewall)"
    Write-Host "  • Development environment detection"
    Write-Host "  • Top process monitoring"
    Write-Host "  • Selective line updates (no full screen refresh)"
    Write-Host "  • Professional logging system"
    Write-Host ""
    Write-Host "CONTROLS:" -ForegroundColor Yellow
    Write-Host "  Ctrl+C                           # Exit monitor"
    Write-Host ""
    Write-Host "LOG FILE:" -ForegroundColor Yellow
    Write-Host "  Location: $($Script:Config.LogFile)"
    Write-Host "  Max Size: $($Script:Config.MaxLogSize / 1MB)MB (auto-rotated)"
    Write-Host ""
}

function Start-SystemMonitor {
    Write-Log "System Monitor started" 'INFO'
    Clear-Host
    Show-Header
    
    $Script:IsInitialized = $true
    $lastNetworkLines = 0
    $tempNetworkLines = 0
    $lastDevLines = 0
    $tempDevLines = 0
    $isFirst = $true
    $spinner = @('|','/','-','\')
    $lineNumber = 4
    $footerLine = -1

    try {
        while ($true) {
            $currentLine = 6
            # Collect all metrics# Start a background job to gather metrics
            $job = Start-Job -ScriptBlock {
                param($scriptPath)
                . $scriptPath

                $systemMetrics = Get-SystemMetrics
                $networkMetrics = Get-NetworkMetrics
                $processMetrics = Get-ProcessMetrics
                $devMetrics = Get-DevelopmentMetrics -InvokedLocation $using:location

                # Return all results as a single object
                [PSCustomObject]@{
                    System = $systemMetrics
                    Network = $networkMetrics
                    Process = $processMetrics
                    Dev = $devMetrics
                }
            } -ArgumentList $helpers

            # Spinner loop while job is running
            $i = 0
            while ($job.State -eq 'Running') {
                $char = $spinner[$i % $spinner.Length]
                Update-ConsoleLine $lineNumber $char "Yellow"
                if (-not $isFirst) {
                    Show-Footer $footerLine $isFirst
                }
                Start-Sleep -Milliseconds 100
                $i++
            }

            # Get the job results and remove the job
            $result = Receive-Job -Job $job
            Remove-Job -Job $job

            # Show final message
            Update-ConsoleLine $lineNumber "✔" "Green"

            # Now you can use the metrics
            $systemMetrics = $result.System
            $networkMetrics = $result.Network
            $processMetrics = $result.Process
            $devMetrics = $result.Dev
            # Update System Status
            $currentLine = Show-SystemStatus $systemMetrics $currentLine

            # Update Network Status
            $tempNetworkLines = Show-NetworkStatus $networkMetrics $currentLine
            if ($tempNetworkLines -ne $currentLine) {
                $lastNetworkLines = $tempNetworkLines - $currentLine
            }
            $currentLine += $lastNetworkLines

            # Update Process Status
            $currentLine = Show-ProcessStatus $processMetrics $currentLine

            # Update Development Status
            $tempDevLines = Show-DevelopmentStatus $devMetrics $currentLine
            if ($tempDevLines -ne $currentLine) {
                $lastDevLines = $tempDevLines - $currentLine
            }
            $currentLine += $lastDevLines

            # Check for alerts
            if ($systemMetrics.CPU -gt $Script:Config.AlertThresholds.CPU) {
                Write-Log "HIGH CPU USAGE: $($systemMetrics.CPU)%" 'WARN'
            }
            
            if ($systemMetrics.Memory.Percent -gt $Script:Config.AlertThresholds.Memory) {
                Write-Log "HIGH MEMORY USAGE: $($systemMetrics.Memory.Percent)%" 'WARN'
            }
            
            for ($i = 0; $i -lt $Script:Config.RefreshInterval / 500; $i++) {
                Show-Footer $currentLine $isFirst
                $footerLine = $currentLine
                Start-Sleep -Milliseconds 500
                $isFirst = $false
            }
        }
        
    } catch [System.OperationCanceledException] {
        Write-Host "`n`nSystem Monitor stopped by user." -ForegroundColor Yellow
        Write-Log "Monitor stopped by user" 'INFO'
    } catch {
        Write-Host "`n`nCritical Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Critical error: $($_.Exception.Message)" 'ERROR'
    } finally {
        Write-Host "Shutting down system monitor..." -ForegroundColor Gray
        Write-Log "System monitor shutdown complete" 'INFO'
    }
}
#endregion

#region Main Execution
# Parse arguments
$helpArgs = @("-h", "--h", "help", "-Help")

if ($Arguments.Count -eq 0) {
    Start-SystemMonitor
    return
}

if ($helpArgs -contains $Arguments[0]) {
    $isSmall = $Arguments -contains "--small"
    Show-Help -Small $isSmall
    return
}

# Handle unknown commands
$command = $Arguments[0].ToLower()
switch ($command) {
    "start" {
        Start-SystemMonitor
    }
    "config" {
        Write-Host "Current Configuration:" -ForegroundColor Yellow
        Write-Host "Refresh Interval: $($Script:Config.RefreshInterval) Ms"
        Write-Host "Log File: $($Script:Config.LogFile)"
        Write-Host "Alert Thresholds:"
        Write-Host "  CPU: $($Script:Config.AlertThresholds.CPU)%"
        Write-Host "  Memory: $($Script:Config.AlertThresholds.Memory)%"
        Write-Host "  Disk: $($Script:Config.AlertThresholds.Disk)%"
        Write-Host "  Temperature: $($Script:Config.AlertThresholds.Temperature)°C"
    }
    "test" {
        Write-Host "Testing system metric collection..." -ForegroundColor Yellow
        
        Write-Host "`nSystem Metrics:" -ForegroundColor Cyan
        $system = Get-SystemMetrics
        $system | ConvertTo-Json -Depth 3 | Write-Host
        
        Write-Host "`nNetwork Metrics:" -ForegroundColor Cyan
        $network = Get-NetworkMetrics
        $network | ConvertTo-Json -Depth 3 | Write-Host
        
        Write-Host "`nProcess Metrics:" -ForegroundColor Cyan
        $processes = Get-ProcessMetrics
        $processes | ConvertTo-Json -Depth 3 | Write-Host
        
        Write-Host "`nDevelopment Metrics:" -ForegroundColor Cyan
        $dev = Get-DevelopmentMetrics -InvokedLocation $location
        $dev | ConvertTo-Json -Depth 3 | Write-Host
    }
    default {
        Write-Host "❌ Error: Unknown command '$command'" -ForegroundColor Red
        Write-Host "Available commands: start, config, test, help" -ForegroundColor Yellow
        Write-Host "Use 'chater-hud help' for more information" -ForegroundColor Gray
    }
}
#endregion