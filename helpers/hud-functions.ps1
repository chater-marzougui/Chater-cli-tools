
#endregion

#region Data Collection Functions
function Get-SystemMetrics {
    $metrics = @{}
    
    try {
        # CPU Usage
        $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue
        if ($cpuCounter) {
            $metrics.CPU = [math]::Round($cpuCounter.CounterSamples[0].CookedValue, 1)
        } else {
            # Fallback method
            $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average
            $metrics.CPU = [math]::Round($cpu.Average, 1)
        }
        
        # Memory Usage
        $os = Get-CimInstance Win32_OperatingSystem
        $totalMem = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeMem = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedMem = [math]::Round($totalMem - $freeMem, 2)
        $memPercent = [math]::Round(($usedMem / $totalMem) * 100, 1)
        
        $metrics.Memory = @{
            Percent = $memPercent
            Used = $usedMem
            Total = $totalMem
            Free = $freeMem
        }
        
        # Disk Usage (C: drive)
        $disk = Get-PSDrive C -ErrorAction SilentlyContinue
        if ($disk) {
            $totalDisk = [math]::Round(($disk.Used + $disk.Free) / 1GB, 2)
            $usedDisk = [math]::Round($disk.Used / 1GB, 2)
            $diskPercent = [math]::Round(($usedDisk / $totalDisk) * 100, 1)
            
            $metrics.Disk = @{
                Percent = $diskPercent
                Used = $usedDisk
                Total = $totalDisk
                Free = [math]::Round($disk.Free / 1GB, 2)
            }
        }
        
        # System Temperature (if available)
        try {
            $temp = Get-CimInstance -Namespace "root/wmi" -Class "MSAcpi_ThermalZoneTemperature" -ErrorAction SilentlyContinue
            if ($temp) {
                $celsius = ($temp.CurrentTemperature / 10) - 273.15
                $metrics.Temperature = [math]::Round($celsius, 1)
            }
        } catch {
            $metrics.Temperature = $null
        }
        
        # System Uptime
        $bootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $uptime = (Get-Date) - $bootTime
        $metrics.Uptime = @{
            Days = $uptime.Days
            Hours = $uptime.Hours
            Minutes = $uptime.Minutes
            TotalHours = [math]::Round($uptime.TotalHours, 1)
        }
        
    } catch {
        Write-Log "Error collecting system metrics: $($_.Exception.Message)" 'ERROR'
    }
    
    return $metrics
}

function Get-NetworkMetrics {
    $network = @{
        Interfaces = @()
        InternetConnected = $false
    }
    
    try {
       $adapters = Get-NetAdapter -ErrorAction SilentlyContinue |
               Where-Object {
                   $_.Name -notlike "Loopback*" -and
                   $_.Name -notlike "*Hyper-V*" -and
                   $_.Name -notlike "*Local Area Connection*"
               } |
               Sort-Object InterfaceMetric
        foreach ($adapter in $adapters | Select-Object -First 5) {
            $interfaceInfo = @{
                Name = $adapter.Name
                Status = $adapter.Status
                Speed = $adapter.LinkSpeed
                IP = "N/A"
            }
            
            # Get IP address
            try {
                $ip = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                      Where-Object {$_.PrefixOrigin -ne "WellKnown"} |
                      Select-Object -First 1
                
                if ($ip) {
                    $interfaceInfo.IP = $ip.IPAddress
                }
            } catch {}
            
            # Get speed
            if ($adapter.LinkSpeed -and $adapter.LinkSpeed -gt 0) {
                $interfaceInfo.Speed = $adapter.LinkSpeed
            }
            
            $network.Interfaces += $interfaceInfo
        }
        
        # Test internet connectivity
       try {
            $client = [System.Net.Http.HttpClient]::new()
            # Send a lightweight HEAD request (faster than GET)
            $request = New-Object System.Net.Http.HttpRequestMessage 'HEAD', 'https://www.google.com'
            $response = $client.SendAsync($request).Result
            if ($response.IsSuccessStatusCode) {
                $network.InternetConnected = $true
            }

            $client.Dispose()
        }
        catch {
            $network.InternetConnected = $false
        }
    } catch {
        Write-Log "Error collecting network metrics: $($_.Exception.Message)" 'ERROR'
    }
    
    return $network
}

function Get-ProcessMetrics {
    try {
        # Get all processes and filter out those with no CPU usage and low memory
        $processes = Get-Process | 
                    Where-Object {$_.CPU -gt 0 -or $_.WorkingSet -gt 50MB}
        
        # Group processes by name and accumulate their metrics
        $groupedProcesses = $processes | Group-Object -Property Name | ForEach-Object {
            $totalCPU = ($_.Group | Measure-Object -Property CPU -Sum).Sum
            $totalMemory = ($_.Group | Measure-Object -Property WorkingSet -Sum).Sum
            $processCount = $_.Count
            $pids = $_.Group.Id -join ","
            
            [PSCustomObject]@{
                Name = $_.Name
                CPU = if($totalCPU) { [math]::Round($totalCPU, 1) } else { 0 }
                Memory = [math]::Round($totalMemory / 1MB, 1)
                ProcessCount = $processCount
                PIDs = $pids
            }
        }
        
        # Sort by RAM usage (descending) and take top 5
        $topProcesses = $groupedProcesses | 
                       Sort-Object Memory -Descending | 
                       Select-Object -First 5
        
        # Convert to the original format
        $processInfo = @()
        foreach ($proc in $topProcesses) {
            $processInfo += @{
                Name = if($proc.ProcessCount -gt 1) { "$($proc.Name) ($($proc.ProcessCount))" } else { $proc.Name }
                CPU = $proc.CPU
                Memory = $proc.Memory
                PID = $proc.PIDs
            }
        }
        
        return $processInfo
    } catch {
        Write-Log "Error collecting process metrics: $($_.Exception.Message)" 'ERROR'
        return @()
    }
}

function Get-DevelopmentMetrics {
    $dev = @{
        Git = @{ Status = "Not a Git repository" }
        Docker = @{ Status = "Not installed" }
        Node = @{ Status = "Not installed" }
        Python = @{ Status = "Not installed" }
    }
    
    try {
        # Git information
        if (Test-Path .git) {
            try {
                $branch = git rev-parse --abbrev-ref HEAD 2>$null
                $status = git status --porcelain 2>$null
                $changes = if($status) { ($status | Measure-Object).Count } else { 0 }
                $lastCommit = git log -1 --format="%cr" 2>$null
                
                $dev.Git = @{
                    Status = if($changes -gt 0) { "Modified" } else { "Clean" }
                    Branch = $branch
                    Changes = $changes
                    LastCommit = $lastCommit
                }
            } catch {
                $dev.Git.Status = "Git error"
            }
        }
        
        # Docker status
        try {
            $dockerOutput = docker ps -q 2>$null
            if ($LASTEXITCODE -eq 0) {
                $containerCount = if($dockerOutput) { ($dockerOutput | Measure-Object).Count } else { 0 }
                $dev.Docker = @{
                    Status = "Running"
                    Containers = $containerCount
                }
            }
        } catch {}
        
        # Node.js version
        try {
            $nodeVersion = node --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                $dev.Node = @{
                    Status = "Installed"
                    Version = $nodeVersion.Trim()
                }
            }
        } catch {}
        
        # Python version
        try {
            $pythonVersion = python --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                $dev.Python = @{
                    Status = "Installed"
                    Version = $pythonVersion.Trim()
                }
            }
        } catch {}
        
    } catch {
        Write-Log "Error collecting development metrics: $($_.Exception.Message)" 'WARN'
    }
    
    return $dev
}
#endregion